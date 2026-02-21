import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

void main() async {
  late ZiweiRuleset defaultRuleset;

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
}
