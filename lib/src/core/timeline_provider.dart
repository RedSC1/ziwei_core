import 'package:bazi_core/bazi_core.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/models/timeline_node.dart';

/// **历法时间轴生成器 (Timeline Provider)**
///
/// 专为前端 UI 层和跨平台序列化设计的“数据骨架装配车间”。
/// 当初始化绑定了一个确定的 [ZiWeiPlate] 命盘后，它会严格遵守该盘自带的
/// 五虎遁流派、闰月规则、节气界标（如 `flowLimit_boundary` 配置）等命理 DNA，
/// 从而保证生成出来的大限/流年/流月/流日表，在任何时间刻度下其历法都是**统一且严谨**的，
/// 不会出现“流月查了节气，却拿阴历套流日”的历法撕裂缺陷。
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
          solarStart: '$startYear-02-04',
          solarEnd: '$endYear-12-31',
        ),
      );
    }

    return decades;
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

    for (int m = 1; m <= 12; m++) {
      // 内部通过 ZiweiDate 的历法和五虎遁，结合流年斗君，确保算出的干支绝对正确
      var fm = FlowMonth.create(m, targetYear, plate);

      // 计算该农历月的物理起始与终结时间，用作给其他流派引擎（如八字）的发号令
      String solarStart = "";
      String solarEnd = "";
      int daysInMonth = 30; // 兜底

      try {
        if (isSolarBoundary) {
          // ==============================
          // 节气(太阳)流月模式 (类似八字库运势)
          // ==============================
          final startAstro = yearJies[m - 1];
          final endAstroExclusive = yearJies[m];

          // 掰到正午再相减，消除时分秒造成的 ±1 天偏移（兼容公元前）
          final startNoon = AstroDateTime(
            startAstro.year,
            startAstro.month,
            startAstro.day,
            12,
            0,
            0,
          ).toJ2000();
          final endNoon = AstroDateTime(
            endAstroExclusive.year,
            endAstroExclusive.month,
            endAstroExclusive.day,
            12,
            0,
            0,
          ).toJ2000();
          daysInMonth = (endNoon - startNoon).round();

          solarStart =
              "${startAstro.year}-${startAstro.month.toString().padLeft(2, '0')}-${startAstro.day.toString().padLeft(2, '0')} ${startAstro.hour.toString().padLeft(2, '0')}:${startAstro.minute.toString().padLeft(2, '0')}:${startAstro.second.toString().padLeft(2, '0')}";

          // 八字的结束也是交节时刻！不是当天的0点！严格来说结束时刻就是 endAstroExclusive!
          solarEnd =
              "${endAstroExclusive.year}-${endAstroExclusive.month.toString().padLeft(2, '0')}-${endAstroExclusive.day.toString().padLeft(2, '0')} ${endAstroExclusive.hour.toString().padLeft(2, '0')}:${endAstroExclusive.minute.toString().padLeft(2, '0')}:${endAstroExclusive.second.toString().padLeft(2, '0')}";
        } else {
          // ==============================
          // 阴历(太阴)流月模式 (传统紫微纯阴历)
          // ==============================
          const cnMonths = [
            "",
            "正",
            "二",
            "三",
            "四",
            "五",
            "六",
            "七",
            "八",
            "九",
            "十",
            "冬",
            "腊",
            "十三",
          ];
          String queryStr = (m >= 1 && m <= 13) ? cnMonths[m] : m.toString();

          final ln0 = LunarDate.fromString(targetYear, queryStr, 1);
          final startAstro = ln0.toSolar;
          solarStart =
              "${startAstro.year}-${startAstro.month.toString().padLeft(2, '0')}-${startAstro.day.toString().padLeft(2, '0')}";

          // 直接由于没有提供 LunarDate API 的天数求法，但根据常识: 农历第二个月是小月29天，可以用 LunarDate(查询本月天数计算)
          // 但由于我们没有办法拿到当月天数，所以只能根据下一个月的初一减去本月初一获得!
          String nextMonthStr = (m + 1 >= 1 && m + 1 <= 12)
              ? cnMonths[m + 1]
              : "正";
          int nextYear = m == 12 ? targetYear + 1 : targetYear;
          try {
            final ln1 = LunarDate.fromString(nextYear, nextMonthStr, 1);
            final endAstroExclusive = ln1.toSolar;
            daysInMonth =
                endAstroExclusive.toJ2000().toInt() -
                startAstro.toJ2000().toInt();

            final endAstro = AstroDateTime.fromJ2000(
              startAstro.toJ2000() + daysInMonth - 1,
            );
            solarEnd =
                "${endAstro.year}-${endAstro.month.toString().padLeft(2, '0')}-${endAstro.day.toString().padLeft(2, '0')}";
          } catch (e) {
            final endAstro = AstroDateTime.fromJ2000(
              startAstro.toJ2000() + daysInMonth - 1,
            ); // fallback to 30
            solarEnd =
                "${endAstro.year}-${endAstro.month.toString().padLeft(2, '0')}-${endAstro.day.toString().padLeft(2, '0')}";
          }
        }
      } catch (e) {
        // Fallback
      }

      months.add(
        MonthNode(
          month: m,
          stem: fm.ganzhi.gan.name,
          branch: fm.ganzhi.zhi.name,
          solarStart: solarStart.isNotEmpty ? solarStart : null,
          solarEnd: solarEnd.isNotEmpty ? solarEnd : null,
        ),
      );
    }
    return months;
  }

  /// 4. 获取指定月份的流日表
  ///
  /// 返回该月每一天的阳历日期与日干支，供前端画日历格子。
  /// 4. 获取指定流年、流月的流日表
  ///
  /// - [year]: 对应的年份
  /// - [month]: 1-12 对应的流月序号
  List<DayNode> getDays(int targetYear, int month) {
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
        // 农历模式
        const cnMonths = [
          "",
          "正",
          "二",
          "三",
          "四",
          "五",
          "六",
          "七",
          "八",
          "九",
          "十",
          "冬",
          "腊",
          "十三",
        ];
        String queryStr = (month >= 1 && month <= 13)
            ? cnMonths[month]
            : month.toString();
        final ln0 = LunarDate.fromString(targetYear, queryStr, 1);
        startDate = ln0.toSolar;

        // 用下月初一减本月初一算天数
        String nextMonthStr = (month + 1 >= 1 && month + 1 <= 12)
            ? cnMonths[month + 1]
            : "正";
        int nextYear = month == 12 ? targetYear + 1 : targetYear;
        final ln1 = LunarDate.fromString(nextYear, nextMonthStr, 1);
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
      }
    } catch (_) {
      // fallback
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
  /// 根据 `splitRatHour` 配置返回 12 或 13 个时辰条目。
  /// 13 个条目时：早子(0) + 丑(1)~亥(11) + 晚子(12)
  ///
  /// - [dayGanZhi]: 该日的日柱干支（用于五鼠遁推算时辰天干）
  List<HourNode> getHours(GanZhi dayGanZhi) {
    final splitRat = plate.ruleset.calendarOptions.splitRatHour;
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

  /// 6. 生成某年度流运概览清单
  ///
  /// 这是给 UI 渲染层提供的轻量化年度通行证
  TimelineManifest generateManifest(int currentYear) {
    final months = getMonths(currentYear);
    final bool isFused = months.isEmpty && plate.date.options.enableHistorical;

    return TimelineManifest(
      decades: getDecades(),
      currentYearMonths: months,
      status: ManifestStatus(
        isHistoricalRedZone: isFused,
        note: isFused
            ? "当前年份处于历史历法特殊更迭期（非建寅为正），流运数据已停用。如需强行排盘，请在配置中关闭“启用历史历法”选项。"
            : "正常",
      ),
    );
  }
  // 注意：getYears 我们这里不全体输出，因为 120 个年份容易撑大 Payload。
  // 前端渲染"当前大限内部的10年"时，可以通过大限的 start_year 去纯手工 +1 计算即可，
  // 因为流年的干支规律极度线性（十年一旬）。如果有需要也可以随时追加输出。
  // getDays / getHours 也设计为按需调用，不在 manifest 里全量铺开。

  // === 内部工具 ===

  /// 由阳历日期推算日干支 (60甲子日循环)
  ///
  /// 基于 J2000 纪元：2000-01-01 12:00 = 庚辰日 (庚=6, 辰=4)
  GanZhi _dayGanZhi(AstroDateTime date) {
    final j = AstroDateTime(
      date.year,
      date.month,
      date.day,
      12,
      0,
      0,
    ).toJ2000().round();
    final stemIndex = ((j % 10) + 10 + 6) % 10;
    final branchIndex = ((j % 12) + 12 + 4) % 12;
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
}
