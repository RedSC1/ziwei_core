import 'package:bazi_core/bazi_core.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';

/// **历法时间轴生成器 (Timeline Provider)**
///
/// 专为前端 UI 层和跨平台序列化设计的“数据骨架装配车间”。
/// 当初始化绑定了一个确定的 [ZiWeiPlate] 命盘后，它会严格遵守该盘自带的
/// 五虎遁流派、闰月规则、节气界标（如 `flowLimit_boundary` 配置）等命理 DNA，
/// 从而保证生成出来的大限/流年/流月/流日表，在任何时间刻度下其历法都是**统一且严谨**的，
/// 不会出现“流月查了节气，却拿阴历套流日”的历法撕裂缺陷。
class TimelineProvider {
  final ZiWeiPlate plate;

  TimelineProvider(this.plate);

  /// 1. 获取完整的 12 个大限周期间隔表
  ///
  /// 返回格式：
  /// ```json
  /// [
  ///   {
  ///     "index": 1,
  ///     "start_age": 2, "end_age": 11,
  ///     "start_year": 2004, "end_year": 2013,
  ///     "stem": "xin", "branch": "you"
  ///   }
  /// ]
  /// ```
  List<Map<String, dynamic>> getDecades() {
    List<Map<String, dynamic>> decades = [];
    int startDecadeYear = Decade.getStartDecadeYear(plate);

    for (int i = 1; i <= 12; i++) {
      var d = Decade.fromIndex(i, plate);
      int startYear = startDecadeYear + (i - 1) * 10;
      int endYear = startDecadeYear + i * 10 - 1;
      decades.add({
        'index': i,
        'start_age': d.startTime,
        'end_age': d.endTime,
        'start_year': startYear,
        'end_year': endYear,
        'stem': d.ganzhi.gan.name,
        'branch': d.ganzhi.zhi.name,
        // 返回大限第一天大概的公历戳 (方便跨历法引擎联动定点)
        'solar_start': '$startYear-02-04',
        'solar_end': '$endYear-12-31',
      });
    }

    return decades;
  }

  /// 2. 获取指定大限内的 10 个流年表
  ///
  /// - [decadeIndex]: 1~12 的大限索引
  List<Map<String, dynamic>> getYears(int decadeIndex) {
    List<Map<String, dynamic>> years = [];
    int startDecadeYear = Decade.getStartDecadeYear(plate);

    // 计算该大限内的起点公历年份
    int startYear = startDecadeYear + (decadeIndex - 1) * 10;

    for (int i = 0; i < 10; i++) {
      int currentYear = startYear + i;
      var fy = FlowYear.createByYear(currentYear, plate);
      years.add({
        'year': currentYear, // 物理年份，前端显示用 + 后端寻址用
        'stem': fy.ganzhi.gan.name, // 混合天干
        'branch': fy.ganzhi.zhi.name, // 流年命宫所在的地支
      });
    }
    return years;
  }

  /// 3. 获取指定流年内的 12个流月表 (严格遵从小限/太岁/流月配置)
  ///
  /// 返回包含了 `month` 数字和混合干支的列表。
  List<Map<String, dynamic>> getMonths(int targetYear) {
    List<Map<String, dynamic>> months = [];

    // 预先读取节气或历法配置
    final bool isSolarBoundary =
        plate.ruleset.calendarOptions.flowLimitBasedOn == Boundary.solar;

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
          // 八字的流月，完全由【节】（Jie）决定，不考虑【气】（Qi），且与农历初一毫无瓜葛。
          // 寅月(m=1) = 立春到惊蛰。因为我们需要取当年的立春时刻作为基准。
          // 所以简单办法：我们粗略找当年该阳历月的15号作为一个锚点时间 (因为节一般在月初4-8号)，
          // 然后向前后查找相近的节令。
          // 由于 m=1 代表寅月，物理落在阳历 2月。
          int anchorMonth = m + 1;
          int anchorYear = targetYear;
          if (anchorMonth > 12) {
            anchorMonth -= 12;
            anchorYear += 1;
          }
          final anchorTime = AstroDateTime(
            anchorYear,
            anchorMonth,
            15,
            12,
            0,
            0,
          );

          final startJie = getPrevJie(anchorTime);
          final endJie = getNextJie(anchorTime);

          final startAstro = startJie!.dateTime;
          // 注意：八字的换月是精确到秒的(交节时间)，为了前端渲染天数，算到前一天的 23:59 或只保留日期即可。
          final endAstroExclusive = endJie!.dateTime;

          daysInMonth =
              endAstroExclusive.toJ2000().toInt() -
              startAstro.toJ2000().toInt();

          final endAstro = AstroDateTime.fromJ2000(
            startAstro.toJ2000() + daysInMonth - 1,
          );

          solarStart =
              "${startAstro.year}-${startAstro.month.toString().padLeft(2, '0')}-${startAstro.day.toString().padLeft(2, '0')}";
          solarEnd =
              "${endAstro.year}-${endAstro.month.toString().padLeft(2, '0')}-${endAstro.day.toString().padLeft(2, '0')}";
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

      months.add({
        'month': m, // 农历或节令相对位置 1-12
        'stem': fm.ganzhi.gan.name,
        'branch': fm.ganzhi.zhi.name,
        'days_count': daysInMonth,
        'solar_start': solarStart, // e.g. "2026-02-17" 或是立春日 "2026-02-04"
        'solar_end': solarEnd,
      });
    }
    return months;
  }

  /// 4. 生成所有层级的超级时间轴数据字典快照 (Manifest)
  ///
  /// 通常在用户刚进入排盘界面时，连同 `plate` 一次性发送给前端，
  /// 用来做底部的年份/月份双向轮播滚动条。
  ///
  /// - [currentYear]: 需要预先展开的当下年份（用来渲染今年的12个月份列表）
  Map<String, dynamic> generateManifest(int currentYear) {
    return {
      'decades': getDecades(),
      'current_year_months': getMonths(currentYear),
      // 注意：getYears 我们这里不全体输出，因为 120 个年份容易撑大 Payload。
      // 前端渲染“当前大限内部的10年”时，可以通过大限的 start_year 去纯手工 +1 计算即可，
      // 因为流年的干支规律极度线性（十年一旬）。如果有需要也可以随时追加输出。
    };
  }
}
