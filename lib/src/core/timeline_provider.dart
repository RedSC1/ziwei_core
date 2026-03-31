import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/models/timeline_node.dart';

/// 农历月条目内部结构 (record 类型)
typedef _MonthEntry = ({
  int month,
  int sequence,
  String monthName,
  bool isLeap,
  int dx,
});

/// **历法时间轴生成器 (Timeline Provider)**
///
/// 专为前端 UI 层和跨平台序列化设计的”数据骨架装配车间”。
/// 当初始化绑定了一个确定的 [ZiWeiPlate] 命盘后，它会严格遵守该盘自带的
/// 五虎遁流派、闰月规则、节气界标（如 `flowLimit_boundary` 配置）等命理 DNA，
/// 从而保证生成出来的大限/流年/流月/流日表，在任何时间刻度下其历法都是**统一且严谨**的，
/// 不会出现”流月查了节气，却拿阴历套流日”的历法撕裂缺陷。
class TimelineProvider {
  final ZiWeiPlate plate;

  // --- 历史历法红区 JD 常数 (基于寿星万年历) ---
  static const int _jdPreHanStart = 1457698; // 公元前 721 年 (周平王元年，三正混乱起点)
  static const int _jdPreHanEnd = 1683010; // 汉太初历前 (公元前 104 年)
  static const int _jdWangMangStart = 1724360; // 王莽新朝
  static const int _jdWangMangEnd = 1729794;
  static const int _jdWeiMingStart = 1807724; // 曹魏景初
  static const int _jdWeiMingEnd = 1808699;
  static const int _jdWuZeTianStart = 1973067; // 武则天周历
  static const int _jdWuZeTianEnd = 1977052;

  TimelineProvider(this.plate);

  /// 1. 获取完整的 12 个大限周期间隔表
  List<DecadeNode> getDecades() {
    List<DecadeNode> decades = [];
    int startDecadeYear = Decade.getStartDecadeYear(plate);

    for (int i = 1; i <= 12; i++) {
      var d = Decade.fromIndex(i, plate);
      int startYear = startDecadeYear + (i - 1) * 10;
      int endYear = startDecadeYear + i * 10 - 1;
      decades.add(
        DecadeNode(
          index: i,
          startAge: d.startTime,
          endAge: d.endTime,
          startYear: startYear,
          endYear: endYear,
          stem: d.ganzhi.gan.name,
          branch: d.ganzhi.zhi.name,
        ),
      );
    }

    return decades;
  }

  /// 1.5 获取起运前的童限表 (1岁 ~ 起运前一年)
  ///
  /// 注意：如果刚好是1岁起运，该列表为空。
  List<ChildhoodNode> getChildhood() {
    List<ChildhoodNode> childhoods = [];
    int startDecadeAge = plate.elementBureau.number;
    int birthYear = Decade.getEffectiveBirthYear(plate);
    int childhoodYearsCount = startDecadeAge - 1;

    for (int i = 0; i < childhoodYearsCount; i++) {
      int currentYear = birthYear + i;
      int age = i + 1;

      // 直接调用底层已有的童限引擎，它已内置"一命二财三疾厄"跳宫口诀
      var childhood = Decade.createChildhood(currentYear, plate);

      childhoods.add(
        ChildhoodNode(
          age: age,
          year: currentYear,
          stem: childhood.ganzhi.gan.name,
          branch: childhood.ganzhi.zhi.name,
        ),
      );
    }

    return childhoods;
  }

  /// 2. 获取指定大限内的 10 个流年表
  ///
  /// - [decadeIndex]: 1~12 的大限索引
  List<YearNode> getYears(int decadeIndex) {
    List<YearNode> years = [];
    int startDecadeYear = Decade.getStartDecadeYear(plate);

    // 计算该大限内的起点公历年份
    int startYear = startDecadeYear + (decadeIndex - 1) * 10;

    for (int i = 0; i < 10; i++) {
      int currentYear = startYear + i;
      var fy = FlowYear.createByYear(currentYear, plate);
      years.add(
        YearNode(
          year: currentYear,
          stem: fy.ganzhi.gan.name,
          branch: fy.ganzhi.zhi.name,
        ),
      );
    }
    return years;
  }

  /// 3. 获取指定流年内的 12个流月表 (严格遵从小限/太岁/流月配置)
  ///
  /// 返回包含了 `month` 数字和混合干支的列表。
  List<MonthNode> getMonths(int targetYear) {
    // 检查是否处于历史红区且开启了历史模式
    final bool enableHist = plate.date.options.enableHistorical;
    if (enableHist) {
      // 用该年正中（6月）做采样判定
      final sampleDate = AstroDateTime(targetYear, 6, 15, 12, 0, 0);
      if (_isRedZone(sampleDate)) {
        return []; // 熔断：历史模式下不输出混乱时期的流月
      }
    }

    List<MonthNode> months = [];

    // 预先读取节气或历法配置
    final bool isSolarBoundary =
        plate.ruleset.calendarOptions.flowLimitBasedOn == Boundary.solar;

    // --- 极稳健的“节令流水线”采集 (规避历法大平移问题) ---
    // 如果是太阳历模式，预先按序采集这一年所有的 12 个“节”，以及第 13 个（即次年立春）用来做 12 月的结尾
    List<AstroDateTime> yearJies = [];
    if (isSolarBoundary) {
      // 倒退回上一年的 11 月 1 号（公历）寻找立春，以确保兼容远古儒略历（此时立春甚至可能在 1 月初）
      AstroDateTime anchor = AstroDateTime(targetYear - 1, 11, 1, 12, 0, 0);
      var curr = getNextJie(anchor);

      int safeguard = 0;
      while (curr != null && safeguard < 40) {
        if (curr.name == '立春') {
          yearJies.add(curr.dateTime);
          break;
        }
        // 精确跨越当前节，寻找下一个“节”（加2天JD安全跨越浮点精度）
        curr = getNextJie(
          AstroDateTime.fromJ2000(curr.dateTime.toJ2000() + 2.0),
        );
        safeguard++;
      }

      // 接着抓取后面的 12 个节（总计拿到 13 个：正月首...到十二月末尾的次年立春）
      for (int i = 0; i < 12; i++) {
        curr = getNextJie(
          AstroDateTime.fromJ2000(yearJies.last.toJ2000() + 2.0),
        );
        yearJies.add(curr!.dateTime);
      }
    }

    if (isSolarBoundary) {
      // ==============================
      // 节气(太阳)流月模式：固定 12 个月，无闰月概念
      // ==============================
      for (int m = 1; m <= 12; m++) {
        var fm = FlowMonth.create(m, targetYear, plate);
        final startAstro = yearJies[m - 1];
        final endAstroExclusive = yearJies[m];

        final solarStart =
            "${startAstro.year}-${startAstro.month.toString().padLeft(2, '0')}-${startAstro.day.toString().padLeft(2, '0')} ${startAstro.hour.toString().padLeft(2, '0')}:${startAstro.minute.toString().padLeft(2, '0')}:${startAstro.second.toString().padLeft(2, '0')}";
        final solarEnd =
            "${endAstroExclusive.year}-${endAstroExclusive.month.toString().padLeft(2, '0')}-${endAstroExclusive.day.toString().padLeft(2, '0')} ${endAstroExclusive.hour.toString().padLeft(2, '0')}:${endAstroExclusive.minute.toString().padLeft(2, '0')}:${endAstroExclusive.second.toString().padLeft(2, '0')}";

        final cnName = _logicalMonthToCn(m);
        months.add(
          MonthNode(
            month: m,
            sequence: m,
            monthName: cnName,
            displayLabel: '$cnName月',
            isLeap: false,
            stem: fm.ganzhi.gan.name,
            branch: fm.ganzhi.zhi.name,
            solarStart: solarStart,
            solarEnd: solarEnd,
          ),
        );
      }
    } else {
      // ==============================
      // 阴历(太阴)流月模式：用 SSQ 获取真实月份列表（含闰月，可达 13-14 个月）
      // ==============================
      final yearMonths = _resolveLunarYearMonths(targetYear);
      for (final entry in yearMonths) {
        final fm = FlowMonth.create(
          entry.month,
          targetYear,
          plate,
          sequence: entry.sequence,
          isLeap: entry.isLeap,
        );

        String solarStart = "";
        String solarEnd = "";
        try {
          final ln0 = LunarDate.fromString(targetYear, entry.monthName, 1);
          final startAstro = ln0.toSolar;
          solarStart =
              "${startAstro.year}-${startAstro.month.toString().padLeft(2, '0')}-${startAstro.day.toString().padLeft(2, '0')}";

          final daysInMonth = entry.dx;
          final endAstro = AstroDateTime.fromJ2000(
            startAstro.toJ2000() + daysInMonth - 1,
          );
          solarEnd =
              "${endAstro.year}-${endAstro.month.toString().padLeft(2, '0')}-${endAstro.day.toString().padLeft(2, '0')}";
        } catch (_) {
          // Fallback: leave solarStart/solarEnd empty
        }

        months.add(
          MonthNode(
            month: entry.month,
            sequence: entry.sequence,
            monthName: entry.monthName,
            displayLabel: _buildMonthDisplayLabel(entry.monthName),
            isLeap: entry.isLeap,
            stem: fm.ganzhi.gan.name,
            branch: fm.ganzhi.zhi.name,
            solarStart: solarStart.isNotEmpty ? solarStart : null,
            solarEnd: solarEnd.isNotEmpty ? solarEnd : null,
          ),
        );
      }
    }
    return months;
  }

  /// 4. 获取指定月份的流日表
  ///
  /// 返回该月每一天的阳历日期与日干支，供前端画日历格子。
  ///
  /// - [targetYear]: 对应的年份
  /// - [month]: 1-12 对应的流月序号
  /// - [isLeap]: 是否闰月（用于区分六月和闰六月）
  List<DayNode> getDays(int targetYear, int month, {bool isLeap = false}) {
    int dayCount = 30; // 默认30天检查是否处于历史红区且开启了历史模式
    final bool enableHist = plate.date.options.enableHistorical;
    if (enableHist) {
      final sampleDate = AstroDateTime(targetYear, month, 15, 12, 0, 0);
      if (_isRedZone(sampleDate)) {
        return []; // 熔断
      }
    }

    final isSolarBoundary =
        plate.ruleset.calendarOptions.flowLimitBasedOn == Boundary.solar;

    AstroDateTime startDate = AstroDateTime(targetYear, 1, 1, 12, 0, 0);
    // int dayCount = 30; // 兜底

    try {
      if (isSolarBoundary) {
        // 节气模式：用 Jie 边界
        // --- 同样的“节令流水线”采集，找齐目标月（month）的起止节 ---
        AstroDateTime anchor = AstroDateTime(targetYear - 1, 11, 1, 12, 0, 0);
        var curr = getNextJie(anchor);

        int safeguard = 0;
        while (curr != null && safeguard < 40) {
          if (curr.name == '立春') {
            break;
          }
          curr = getNextJie(
            AstroDateTime.fromJ2000(curr.dateTime.toJ2000() + 2.0),
          );
          safeguard++;
        }

        // 找到了流年的首个节（立春，month=1的起点）
        // 往后跳 (month - 1) 个节就是当前月的起点
        for (int i = 0; i < month - 1; i++) {
          curr = getNextJie(
            AstroDateTime.fromJ2000(curr!.dateTime.toJ2000() + 2.0),
          );
        }
        final startJie = curr!;

        // 再往后跳 1 个节就是当前月的终点
        final endJie = getNextJie(
          AstroDateTime.fromJ2000(startJie.dateTime.toJ2000() + 2.0),
        )!;

        startDate = startJie.dateTime;

        final startNoon = AstroDateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          12,
          0,
          0,
        ).toJ2000();
        final endNoon = AstroDateTime(
          endJie.dateTime.year,
          endJie.dateTime.month,
          endJie.dateTime.day,
          12,
          0,
          0,
        ).toJ2000();
        dayCount = (endNoon - startNoon).round();
      } else {
        // 农历模式：用 SSQ 获取真实月份序列（正确处理闰月）
        final yearMonths = _resolveLunarYearMonths(targetYear);
        final targetIndex = yearMonths.indexWhere(
          (entry) => entry.month == month && entry.isLeap == isLeap,
        );
        if (targetIndex < 0) {
          return [];
        }

        final targetMonth = yearMonths[targetIndex];
        final nextMonth = targetIndex + 1 < yearMonths.length
            ? yearMonths[targetIndex + 1]
            : null;

        final ln0 = LunarDate.fromString(targetYear, targetMonth.monthName, 1);
        startDate = ln0.toSolar;

        // 计算下月起始日期来确定本月天数
        if (nextMonth != null) {
          final ln1 = LunarDate.fromString(targetYear, nextMonth.monthName, 1);
          final endAstro = ln1.toSolar;
          final startNoon = AstroDateTime(
            startDate.year,
            startDate.month,
            startDate.day,
            12,
            0,
            0,
          ).toJ2000();
          final endNoon = AstroDateTime(
            endAstro.year,
            endAstro.month,
            endAstro.day,
            12,
            0,
            0,
          ).toJ2000();
          dayCount = (endNoon - startNoon).round();
        } else {
          // 没有下月信息，使用月大小
          dayCount = targetMonth.dx;
        }
      }
    } catch (_) {
      return [];
    }

    List<DayNode> days = [];
    final startNoonJ = AstroDateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      12,
      0,
      0,
    ).toJ2000();

    for (int d = 1; d <= dayCount; d++) {
      final dayDate = AstroDateTime.fromJ2000(startNoonJ + (d - 1));
      final gz = _dayGanZhi(dayDate);
      days.add(
        DayNode(
          day: d,
          stem: gz.gan.name,
          branch: gz.zhi.name,
          solarDate:
              "${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}",
        ),
      );
    }
    return days;
  }

  /// 5. 获取指定日干支的流时表
  ///
  /// 根据 `ratHourMode` 配置返回 12 或 13 个时辰条目。
  /// 13 个条目时：早子(0) + 丑(1)~亥(11) + 晚子(12)
  ///
  /// - [dayGanZhi]: 该日的日柱干支（用于五鼠遁推算时辰天干）
  List<HourNode> getHours(GanZhi dayGanZhi) {
    final ratHourMode = plate.ruleset.calendarOptions.ratHourMode;
    final splitRat = ratHourMode != RatHourMode.noSplit;
    List<HourNode> hours = [];

    int startRatStemIndex = (dayGanZhi.gan.index % 5) * 2;

    if (splitRat) {
      // 早子时 (00:00-01:00)
      hours.add(
        HourNode(
          hourIndex: 0,
          label: '早子',
          stem: TianGan.values[startRatStemIndex % 10].name,
          branch: DiZhi.values[0].name,
          isEarlyRat: true,
        ),
      );
    }

    // 不拆子时从0开始，拆子时从1开始（早子已添加）
    int startIdx = splitRat ? 1 : 0;
    for (int h = startIdx; h < 12; h++) {
      int stemIdx = (startRatStemIndex + h) % 10;
      hours.add(
        HourNode(
          hourIndex: h,
          label: DiZhi.values[h].name,
          stem: TianGan.values[stemIdx].name,
          branch: DiZhi.values[h].name,
        ),
      );
    }

    if (splitRat) {
      // 晚子时 (23:00-00:00)
      hours.add(
        HourNode(
          hourIndex: 12,
          label: '晚子',
          stem: TianGan.values[(startRatStemIndex + 12) % 10].name,
          branch: DiZhi.values[0].name,
          isLateRat: true,
        ),
      );
    }

    return hours;
  }

  /// 6. 统一流运快照生成器
  ///
  /// 按深度级联返回数据：大限/童限始终包含，其余层级按传参决定。
  /// - [year]: 传了 → 挂载该年 12 个流月，并自动推断大限挂载流年
  /// - [decadeIndex]: 传了 → 覆盖自动推断，用指定大限挂载流年
  /// - [month]: 传了 → 挂载该月的流日 (需要 year)
  /// - [isLeap]: 是否闰月（用于区分六月和闰六月）
  /// - [day]: 传了 → 挂载该日的流时 (需要 month)
  TimelineManifest getManifest({
    int? year,
    int? decadeIndex,
    int? month,
    bool? isLeap,
    int? day,
  }) {
    // === 始终返回：大限 + 童限 ===
    final childhoods = getChildhood();
    final decades = getDecades();

    // === 熔断检查 ===
    bool isFused = false;
    if (year != null) {
      final bool enableHist = plate.date.options.enableHistorical;
      if (enableHist) {
        final sampleDate = AstroDateTime(year, 6, 15, 12, 0, 0);
        isFused = _isRedZone(sampleDate);
      }
    }

    // === 流年 (大限内的 10 个流年) ===
    List<YearNode>? decadeYears;
    int? resolvedDecadeIndex = decadeIndex;

    if (year != null && resolvedDecadeIndex == null) {
      // 自动推断：year 落在哪个大限
      final decade = Decade.createByYear(year, plate);
      resolvedDecadeIndex = decade.decadeIndex;
    }

    if (resolvedDecadeIndex != null) {
      if (resolvedDecadeIndex == 0) {
        // 童限：构建当年的单元素兜底
        int targetYear = year ?? Decade.getEffectiveBirthYear(plate);
        var fy = FlowYear.createByYear(targetYear, plate);
        decadeYears = [
          YearNode(
            year: targetYear,
            stem: fy.ganzhi.gan.name,
            branch: fy.ganzhi.zhi.name,
          ),
        ];
      } else {
        decadeYears = getYears(resolvedDecadeIndex);
      }
    }

    // === 流月 ===
    List<MonthNode>? months;
    if (year != null && !isFused) {
      months = getMonths(year);
    }

    // === 流日 ===
    List<DayNode>? days;
    if (year != null && month != null && !isFused) {
      days = getDays(year, month, isLeap: isLeap ?? false);
    }

    // === 流时 ===
    List<HourNode>? hours;
    if (days != null && day != null && day >= 1 && day <= days.length) {
      final targetDay = days[day - 1];
      final dayGZ = GanZhi(
        TianGan.fromName(targetDay.stem),
        DiZhi.fromName(targetDay.branch),
      );
      hours = getHours(dayGZ);
    }

    return TimelineManifest(
      childhoods: childhoods,
      decades: decades,
      currentDecadeYears: decadeYears,
      currentYearMonths: months,
      currentMonthDays: days,
      currentDayHours: hours,
      status: ManifestStatus(
        isHistoricalRedZone: isFused,
        note: isFused ? "当前年份处于历史历法特殊更迭期，流运数据已停用。" : "正常",
      ),
    );
  }

  /// 由阳历日期推算日干支 (60甲子日循环)
  ///
  /// 基于 J2000 纪元：2000-01-01 12:00 = 戊午日 (戊=4, 午=6)
  GanZhi _dayGanZhi(AstroDateTime date) {
    final j = AstroDateTime(
      date.year,
      date.month,
      date.day,
      12,
      0,
      0,
    ).toJ2000().round();
    final stemIndex = ((j % 10) + 10 + 4) % 10;
    final branchIndex = ((j % 12) + 12 + 6) % 12;
    return GanZhi(TianGan.values[stemIndex], DiZhi.values[branchIndex]);
  }

  /// 判定当前时间是否处于历法“不可推演流月”的红区
  bool _isRedZone(AstroDateTime dt) {
    final jd = dt.toJ2000().round() + 2451545; // 转回绝对 JDN
    if (jd >= _jdPreHanStart && jd <= _jdPreHanEnd) return true;
    if (jd >= _jdWangMangStart && jd <= _jdWangMangEnd) return true;
    if (jd >= _jdWeiMingStart && jd <= _jdWeiMingEnd) return true;
    if (jd >= _jdWuZeTianStart && jd <= _jdWuZeTianEnd) return true;
    return false;
  }

  // --- 辅助方法 (用于处理闰月) ---

  List<_MonthEntry> _resolveLunarYearMonths(int targetYear) {
    final ssqResult1 = SSQ().calcY(AstroDateTime(targetYear, 6, 1).toJ2000());
    final ssqResult2 = SSQ().calcY(
      AstroDateTime(targetYear + 1, 6, 1).toJ2000(),
    );

    final List<String> combinedYm = [];
    final List<int> combinedDx = [];
    final List<bool> combinedLeap = [];

    for (int i = 0; i < ssqResult1.ym.length; i++) {
      combinedYm.add(ssqResult1.ym[i]);
      combinedDx.add(ssqResult1.dx[i]);
      combinedLeap.add(ssqResult1.leap > 0 && i == ssqResult1.leap);
    }

    String? lastMonth1;
    for (int i = ssqResult1.ym.length - 1; i >= 0; i--) {
      final isLeap = ssqResult1.leap > 0 && i == ssqResult1.leap;
      if (!isLeap) {
        lastMonth1 = ssqResult1.ym[i];
        break;
      }
    }

    bool foundOverlap = false;
    for (int i = 0; i < ssqResult2.ym.length; i++) {
      final rawName = ssqResult2.ym[i];
      final isLeap = ssqResult2.leap > 0 && i == ssqResult2.leap;

      if (!foundOverlap) {
        if (rawName == lastMonth1 && !isLeap) {
          foundOverlap = true;
        }
        continue;
      }

      combinedYm.add(rawName);
      combinedDx.add(ssqResult2.dx[i]);
      combinedLeap.add(isLeap);
    }

    final List<_MonthEntry> yearMonths = [];
    bool seenZhengYue = false;
    int currentLogicalMonth = 0;

    for (int i = 0; i < combinedYm.length; i++) {
      final rawName = combinedYm[i];
      final normalized = _normalizeLunarMonth(rawName, combinedLeap[i]);

      if (!seenZhengYue && normalized.month == 1 && !normalized.isLeap) {
        seenZhengYue = true;
      }
      if (!seenZhengYue) continue;

      if (normalized.month == 1 &&
          !normalized.isLeap &&
          yearMonths.isNotEmpty) {
        break;
      }

      if (!normalized.isLeap) {
        currentLogicalMonth++;
      }

      yearMonths.add((
        month: currentLogicalMonth,
        sequence: yearMonths.length + 1,
        monthName: normalized.monthName,
        isLeap: normalized.isLeap,
        dx: combinedDx[i],
      ));
    }

    return yearMonths;
  }

  ({int month, String monthName, bool isLeap}) _normalizeLunarMonth(
    String rawName,
    bool isLeap,
  ) {
    if (rawName == '十三') {
      return (month: 12, monthName: '十三', isLeap: true);
    }
    if (rawName == '后九') {
      return (month: 9, monthName: '后九', isLeap: true);
    }
    if (rawName == '拾贰') {
      return (month: 12, monthName: '拾贰', isLeap: true);
    }

    return (
      month: _cnToLogicalMonth(rawName),
      monthName: isLeap ? '闰$rawName' : rawName,
      isLeap: isLeap,
    );
  }

  /// 将农历月名转换为逻辑月号 (1-13)
  int _cnToLogicalMonth(String name) {
    const map = {
      // 正月（防御性：一、一月都映射到1）
      '正': 1, '一': 1, '一月': 1,
      '二': 2, '二月': 2,
      '三': 3, '三月': 3,
      '四': 4, '四月': 4,
      '五': 5, '五月': 5,
      '六': 6, '六月': 6,
      '七': 7, '七月': 7,
      '八': 8, '八月': 8,
      '九': 9, '九月': 9,
      '十': 10, '十月': 10,
      // 冬月/十一月（防御性：多种写法）
      '冬': 11, '十一': 11, '冬月': 11, '十一月': 11,
      // 腊月/十二月（防御性：多种写法）
      '腊': 12, '十二': 12, '腊月': 12, '十二月': 12,
      // 历史特殊月
      '十三': 13, '十三月': 13,
      '后九': 9,
      '拾贰': 12,
    };
    return map[name] ?? 1;
  }

  /// 将逻辑月号转换为中文月名 (用于节气模式)
  String _logicalMonthToCn(int m) {
    const names = ['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '冬', '腊'];
    if (m >= 1 && m <= 12) return names[m - 1];
    return '正';
  }

  String _buildMonthDisplayLabel(String monthName) {
    return monthName.endsWith('月') ? monthName : '$monthName月';
  }
}
