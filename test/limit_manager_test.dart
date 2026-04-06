import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

void main() async {
  late ZiweiRuleset defaultRuleset;

  ZiweiRuleset withRatHourMode(RatHourMode mode) {
    final base = defaultRuleset.calendarOptions;
    return ZiweiRuleset(
      stars: defaultRuleset.stars,
      flowDefinitions: defaultRuleset.flowDefinitions,
      brightnessLabels: defaultRuleset.brightnessLabels,
      siHuaRules: defaultRuleset.siHuaRules,
      mingZhuRule: defaultRuleset.mingZhuRule,
      shenZhuRule: defaultRuleset.shenZhuRule,
      calendarOptions: CalendarOptions(
        ratHourMode: mode,
        leapRule: base.leapRule,
        wuHuDunBasedOn: base.wuHuDunBasedOn,
        siHuaBasedOn: base.siHuaBasedOn,
        childhoodRule: base.childhoodRule,
        flowLimitBasedOn: base.flowLimitBasedOn,
        enableHistorical: base.enableHistorical,
      ),
    );
  }

  setUpAll(() async {
    // 假设你有 ConfigLoader.getDefault()
    defaultRuleset = ConfigLoader.getDefault();
  });

  test('ZiweiLimitManager test basic setMonth & setYear resets', () {
    final date = ZiweiDate.fromSolar(DateTime(2023, 1, 15, 12, 0));
    final plate = ZiweiEngine.calculate(date, defaultRuleset);

    final manager = ZiweiLimitManager(plate);

    // 初始化时，应当没有任何流运
    expect(manager.limitContext.hasYear, false);

    // 注入流年
    manager.setYear(2025);
    expect(manager.limitContext.hasYear, true);
    expect(manager.limitContext.year!.year, 2025);

    // 注入流月
    manager.setMonth(5);
    expect(manager.limitContext.hasMonth, true);
    expect(manager.limitContext.month!.month, 5);

    // 断言有月的时候能计算出动态盘
    final dynamic1 = manager.dynamicPlate;
    expect(dynamic1.monthMingIndex, isNotNull);

    // 注入新年，应当清空旧月
    manager.setYear(2026);
    expect(manager.limitContext.hasYear, true);
    expect(manager.limitContext.hasMonth, false);
  });

  test('LimitContext remove actually clears nested scopes', () {
    final date = ZiweiDate.fromSolar(DateTime(2023, 1, 15, 12, 0));
    final plate = ZiweiEngine.calculate(date, defaultRuleset);
    final manager = ZiweiLimitManager(plate);

    manager.setYear(2025);
    manager.setMonth(5);

    expect(manager.limitContext.hasYear, true);
    expect(manager.limitContext.hasMonth, true);

    manager.clearYear();

    expect(manager.limitContext.hasYear, false);
    expect(manager.limitContext.hasMonth, false);
    expect(manager.limitContext.hasDay, false);
    expect(manager.limitContext.hasHour, false);
  });

  test('TimeMachine.travelByMacro uses targetYear for childhood routing', () {
    final date = ZiweiDate.fromSolar(DateTime(2023, 1, 15, 12, 0));
    final plate = ZiweiEngine.calculate(date, defaultRuleset);
    final birthYear = Decade.getEffectiveBirthYear(plate);

    final context = TimeMachine.travelByMacro(
      plate,
      0,
      targetYear: birthYear + 1,
    );
    final expected = Decade.createChildhood(birthYear + 1, plate);

    expect(context.decade, isNotNull);
    expect(context.decade!.startTime, expected.startTime);
    expect(context.decade!.endTime, expected.endTime);
    expect(context.decade!.ganzhi.toString(), expected.ganzhi.toString());
  });

  test('TimelineProvider resolves leap month days consistently', () {
    final date = ZiweiDate.fromSolar(DateTime(2023, 1, 15, 12, 0));
    final plate = ZiweiEngine.calculate(date, defaultRuleset);
    final provider = TimelineProvider(plate);

    MonthNode? leapNode;
    int? leapYear;
    for (int year = 2000; year <= 2035; year++) {
      final months = provider.getMonths(year);
      for (final node in months) {
        if (node.isLeap) {
          leapNode = node;
          leapYear = year;
          break;
        }
      }
      if (leapNode != null) break;
    }

    expect(leapNode, isNotNull);
    expect(leapYear, isNotNull);

    final days = provider.getDays(
      leapYear!,
      leapNode!.month,
      isLeap: leapNode.isLeap,
    );

    expect(leapNode.sequence, greaterThan(leapNode.month));
    expect(days, isNotEmpty);
    expect(days.first.solarDate, leapNode.solarStart!.substring(0, 10));

    final leapFlow = FlowMonth.create(
      leapNode.month,
      leapYear,
      plate,
      sequence: leapNode.sequence,
      isLeap: true,
    );
    final normalFlow = FlowMonth.create(leapNode.month, leapYear, plate);

    expect(leapFlow.isLeap, true);
    expect(leapFlow.sequence, leapNode.sequence);
    expect(leapFlow.ganzhi.toString() == normalFlow.ganzhi.toString(), false);
  });

  test('TimelineProvider resolves BCE lunar month days for all months', () {
    final date = ZiweiDate.fromSolar(
      AstroDateTime(-100, 1, 1, 12, 0),
      gender: Gender.male,
      options: defaultRuleset.calendarOptions,
    );
    final plate = ZiweiEngine.calculate(date, defaultRuleset);
    final provider = TimelineProvider(plate);

    final months = provider.getMonths(-100);

    expect(months, hasLength(12));

    for (final month in months) {
      final days = provider.getDays(-100, month.month, isLeap: month.isLeap);
      expect(
        days,
        isNotEmpty,
        reason: 'BCE flow year -100 month ${month.monthName} should expose flow days',
      );
      expect(
        month.solarStart,
        isNotNull,
        reason: 'BCE flow year -100 month ${month.monthName} should expose solarStart',
      );
      expect(days.first.solarDate, month.solarStart);
    }
  });

  test(
    'ZiweiLimitManager absolute time stepping handles Rat Hour securely',
    () {
      // 设定初始时间：晚上 22:30 (亥时尾巴)
      final date = ZiweiDate.fromSolar(DateTime(2024, 5, 20, 22, 30));
      final plate = ZiweiEngine.calculate(date, defaultRuleset);

      final manager = ZiweiLimitManager(plate);

      // 将状态机锚定这一个“物理时刻”
      manager.setPhysicalDate(DateTime(2024, 5, 20, 22, 30));

      final ctx1 = manager.limitContext;
      expect(ctx1.hasHour, true);

      // 我们断言此刻的日柱天干 (假设是某干支)
      final baseDayStem = ctx1.day!.ganzhi.gan;
      final baseHourStem = ctx1.hour!.ganzhi.gan;

      // === 我们跨越到下一个时辰: 24:30 (也就是 5 月 21 日凌晨 00:30, 已经过了 0 点) ===
      manager.nextHour();
      final ctx2 = manager.limitContext;

      // 天文时间推移，早子时已过 0 点，底层引擎应该切换到新的一天了！
      final nextDayStem = ctx2.day!.ganzhi.gan;
      final nextHourStem = ctx2.hour!.ganzhi.gan;

      // 它们必定不等于旧干支
      expect(baseDayStem != nextDayStem, true);
      expect(baseHourStem != nextHourStem, true);

      // 我们甚至可以直接验证动态盘能不能生成
      final dp = manager.dynamicPlate;
      expect(dp.yearMingIndex, isNotNull);
      expect(dp.hourMingIndex, isNotNull);
    },
  );

  test('TimelineProvider split rat hour keeps late Zi stem consistent by mode', () {
    final todayRuleset = withRatHourMode(RatHourMode.todayGan);
    final tomorrowRuleset = withRatHourMode(RatHourMode.tomorrowGan);

    final todayDate = ZiweiDate.fromSolar(
      DateTime(2024, 1, 1, 12, 0),
      options: todayRuleset.calendarOptions,
    );
    final tomorrowDate = ZiweiDate.fromSolar(
      DateTime(2024, 1, 1, 12, 0),
      options: tomorrowRuleset.calendarOptions,
    );

    final todayPlate = ZiweiEngine.calculate(todayDate, todayRuleset);
    final tomorrowPlate = ZiweiEngine.calculate(tomorrowDate, tomorrowRuleset);

    final todayProvider = TimelineProvider(todayPlate);
    final tomorrowProvider = TimelineProvider(tomorrowPlate);

    final jiaZiDay = GanZhi(TianGan.jia, DiZhi.zi);
    final todayHours = todayProvider.getHours(jiaZiDay);
    final tomorrowHours = tomorrowProvider.getHours(jiaZiDay);

    expect(todayHours, hasLength(13));
    expect(tomorrowHours, hasLength(13));
    expect(todayHours.first.isEarlyRat, isTrue);
    expect(todayHours.last.isLateRat, isTrue);
    expect(todayHours.last.label, '晚子');
    expect(todayHours.last.stem, TianGan.jia.name);
    expect(tomorrowHours.last.stem, TianGan.bing.name);
  });
}
