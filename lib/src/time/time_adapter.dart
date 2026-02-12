import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/sxwnl/gan_zhi_calc.dart';
import 'package:ziwei_core/src/sxwnl/ssq.dart';
import 'package:ziwei_core/src/sxwnl/true_solar_time.dart';
import 'package:ziwei_core/src/time/astro_date_time.dart';
import 'package:ziwei_core/src/time/location.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

class TimeAdapter {
  static final _ssq = SSQ();

  static ZiweiDate fromSolar(
    AstroDateTime solarDate,
    Gender gender, {
    CalendarOptions? options,
    Location? location,
  }) {
    final opt = options ?? const CalendarOptions();
    final loc = location ?? Location.beijing;

    // 1. 处理早晚子时 (如果需要)
    // 我们的 AstroDateTime 已经包含了精确时间。
    // 如果不区分早晚子时，且时间在 23:00-24:00，是否需要算作第二天？
    // 传统排盘习惯：23点后算第二天 (晚子时=第二天早子时)。
    // splitRatHour = false (不分) -> 23:00 后算第二天。
    // splitRatHour = true (分) -> 23:00 后仍算当天 (晚子时)，但日干支可能不同？
    // 通常如果不分早晚子，就是把 23:00+ 当作次日 0:00+ 处理。
    // 我们这里直接调整输入时间。

    AstroDateTime calcDate = solarDate;
    if (!opt.splitRatHour && solarDate.hour >= 23) {
      // 23点后算作第二天 (加1小时或直接改日期)
      // 简单做法：加到第二天 0 点
      // 但为了保留原始分钟，只加天数？
      // 不，加 1 小时最自然：23:30 -> 0:30 (次日)
      calcDate = solarDate.add(const Duration(hours: 1));
      // 注意：这会改变 calcDate 的值，后续计算八字/农历都基于这个新时间。
      // 这符合“不分早晚子”的逻辑（都是次日子时）。
    }

    // 2. 计算真太阳时
    final solarRes = calcTrueSolarTime(calcDate, loc);
    final trueSolar = solarRes.trueSolarTime;
    final trueSolarJD = trueSolar.toJulianDay();
    final currentJD = calcDate.toJulianDay(); // 使用调整后的时间（如果23点换日）计算农历

    // 3. 计算农历 (SSQ)
    // 使用 J2000 相对 JD (TT)
    // 农历是基于北京时间的？
    // ssq.calcY 输入的是 JD (TT)。内部会转为北京时间 (UTC+8) 来判断日期。
    // 但我们的输入 calcDate 已经是用户输入的钟表时间 (比如北京时间)。
    // 如果我们把这个钟表时间当作 TT 传进去，会有 8 小时偏差？
    // ssq.dart: calcY(jd) -> calc(w, '气')
    // calc 函数: jd += 2451545.
    // 关键是 ssq 内部的 calc 函数返回的是什么？
    // 它返回的是“定气/定朔时刻的 JD”。
    // ssq.calcY 逻辑：
    // 计算出这一年的所有朔日时刻 (JD)。
    // 然后看 currentJD 落在哪个朔日区间内。

    // 我们需要传入 currentJD (J2000相对)。
    // 但 AstroDateTime.toJulianDay() 返回的是绝对 JD。
    // AstroDateTime.toJ2000() 返回相对值。

    // 关键问题：SSQ 计算出的朔日是 TT 还是 UTC+8？
    // ssq.dart 注释: "时间系统全部使用北京时"
    // 这意味着 hs[i] 存储的是 UTC+8 时间的 JD。
    // 所以我们的 currentJD 也应该是 UTC+8 时间的 JD。
    // 如果 calcDate 是北京时间 2023-01-22 12:00
    // toJ2000() 得到的是这个时刻的 JD。
    // 这正是我们需要的。
    // (只要 ssq 内部和外部对时间的定义一致即可)

    final ssqRes = _ssq.calcY(calcDate.toJ2000());

    // 确定农历月和日
    // 关键修正：hs 表里存的是初一当天的 12:00 (整数 JD)。
    // 如果用户输入的是初一早上 (如 2:58)，直接比 JD 会比 hs 小，导致算成上个月。
    // 计算日数时也会出现负数。
    // 所以，必须用“当天 12:00”来定月和定日。
    final checkDate = AstroDateTime(
      calcDate.year,
      calcDate.month,
      calcDate.day,
      12,
      0,
      0,
    );
    final checkJD = checkDate.toJ2000();

    // 确定月份
    int monthIndex = 0;
    for (int i = 0; i < 14; i++) {
      // 找到下一个初一比当前(12:00)晚的
      // 如果 hs[i+1] > checkJD，说明 checkJD 还没到下个月，所以是第 i 个月
      // 注意：如果是同一天 12:00，hs[i] == checkJD。
      // hs[i+1] 肯定是几十天后，大于 checkJD。
      if (ssqRes.hs[i + 1] > checkJD + 0.0001) {
        // 加一点 epsilon 防止浮点误差
        monthIndex = i;
        break;
      }
    }

    // 计算农历日
    // checkJD (12:00) - hs (12:00) = 整数天
    int lunarDay = (checkJD - ssqRes.hs[monthIndex]).round() + 1;

    // 如果算出来是 0 或负数？（说明在 hs[0] 之前）
    // calcY 保证 hs[0] 是冬至附近的朔，通常在上一年 11 月。
    // 所以一般不会出现这种情况，除非日期极度偏离。

    // 解析农历月名
    String monthName = ssqRes.ym[monthIndex];
    bool isLeap = false;
    int lunarMonth = 0;

    // 解析 "正", "二", "闰二", "十一" 等
    // 月名转换逻辑：
    // monthNames = [十一, 十二, 正, 二 ...]
    // 我们需要把字符串转回数字。
    // ssq.dart 里没有给闰月加标记，只是重用了名字。
    // 比如 "二", "二"。
    // 我们需要根据 leap 索引判断。

    if (ssqRes.leap > 0 && monthIndex == ssqRes.leap) {
      isLeap = true;
      // 闰月的名字跟前一个月一样。
      // 比如闰二月，名字也是 "二"。
    }

    // 名字转数字
    lunarMonth = _monthNameToInt(monthName);

    // 4. 计算八字 (干支)
    // calcGanZhi(utJD, trueSolarJD)
    // currentJD 是北京时间绝对 JD
    // utJD (J2000相对) = currentJD - 8/24 - 2451545
    final utJD = currentJD - 8.0 / 24.0 - 2451545.0;
    final baziRes = calcGanZhi(utJD, trueSolarJD - 2451545.0);

    final bazi = BaZi(
      year: _parseGanZhi(baziRes.yearGanZhi),
      month: _parseGanZhi(baziRes.monthGanZhi),
      day: _parseGanZhi(baziRes.dayGanZhi),
      time: _parseGanZhi(baziRes.timeGanZhi),
    );

    // 5. 构造 LunarDate
    // 寻找 "正" 月的索引以确定农历年
    int zhengIdx = -1;
    for (int i = 0; i < ssqRes.ym.length; i++) {
      if (ssqRes.ym[i] == "正") {
        zhengIdx = i;
        break;
      }
    }

    int lunarYear = calcDate.year;
    if (zhengIdx != -1) {
      if (monthIndex < zhengIdx) {
        lunarYear--; // 在正月之前，算上一年
      }
    }

    final lunarDate = LunarDate(
      year: lunarYear,
      month: lunarMonth,
      day: lunarDay,
      timeIndex: baziRes.timeZhiIndex,
      isLeap: isLeap,
    );

    // 计算 solarDay (上个节令后第几天)
    // zq[1]=小寒, zq[3]=立春... 奇数索引是节令。
    // 找到 currentJD 之前的最近一个节令。
    double prevJieJD = 0;
    // zq 是从冬至(0)开始。冬至是中气。
    // 节令是 1, 3, 5...
    // 还需要考虑冬至前的一个节令（大雪）。
    // ssq.zq[0] 是冬至。我们还需要计算前一个节令（大雪）。
    // ssq.calcY 里有 A.pe1 (前一个气) 和 A.pe2。
    // 但 SSQResult 里只有 List<double> zq (25个)。
    // 我们可以倒推一个：zq[0] - 15.2 天左右。
    // 或者直接在 ssq.dart 里暴露 pe1, pe2？
    // 既然 zq[0] 是冬至，那么 zq[0] - 15 左右就是大雪。
    // 简单起见，我们在 calcGanZhi 里已经算过节令索引了。
    // 这里再找一次。

    for (int k = 1; k < 25; k += 2) {
      if (ssqRes.zq[k] > currentJD) {
        // 这个节令在未来，所以上一个是 k-2
        // 如果 k=1 (小寒) 在未来，那上一个就是 k-2? (-1?)
        // 冬至(0) -> 大雪(-1).
        // 如果 currentJD < 小寒(1)，上一个节令可能是冬至(非节令)前的大雪。
        // 我们需要计算大雪的 JD。
        // ssq.calc(zq[0] - 15.2, 1)
        break;
      }
      prevJieJD = ssqRes.zq[k];
    }
    if (prevJieJD == 0) {
      // 说明比 zq[1] 还早，或者遍历完都没找到（不可能）
      // 也就是在 [冬至, 小寒) 之间，或者 [大雪, 冬至)。
      // 上一个节令是大雪。
      // 临时算一下大雪：
      prevJieJD = _ssq.calc(ssqRes.zq[0] - 15.2, 1);
    }

    int solarDay = (currentJD - prevJieJD).floor();

    return ZiweiDate(
      solar: solarDate,
      trueSolarTime: trueSolar,
      location: loc,
      lunar: lunarDate,
      bazi: bazi,
      options: opt,
      solarDay: solarDay,
      gender: gender,
    );
  }

  static ZiweiDate fromLunar(
    int year,
    int month,
    int day,
    int hourIndex,
    bool isLeap,
    Gender gender, {
    CalendarOptions? options,
    Location? location,
  }) {
    // 1. 估算公历年份对应的 JD
    // 农历 2023 年 ≈ 公历 2023 年
    // 估算冬至 JD
    double estimatedJD = (year - 2000) * 365.2422;

    // 2. 获取该年农历信息
    final ssqRes = _ssq.calcY(estimatedJD);

    // 3. 查找目标月份的索引
    // 转换输入的 month 为中文名
    String targetName = monthNames[(month + 1) % 12];
    // monthNames: 0=十一, 1=十二, 2=正(1月)
    // input 1 -> idx 2 -> 正. 正确。

    int monthIndex = -1;
    // 遍历 ym 寻找匹配
    // 如果 isLeap=true，我们要找第二个匹配项，且该项应该是闰月
    // ssq.leap 指示了闰月的位置。

    // 收集所有匹配名称的索引
    List<int> matches = [];
    for (int i = 0; i < ssqRes.ym.length; i++) {
      if (ssqRes.ym[i] == targetName) {
        matches.add(i);
      }
    }

    if (matches.isEmpty) {
      throw ArgumentError("Invalid lunar month: $month in year $year");
    }

    if (isLeap) {
      // 用户说是闰月
      // 必须有 2 个匹配项，且第二个匹配项的索引等于 ssqRes.leap
      // 或者：ssqRes.leap > 0 且 ym[ssqRes.leap] == targetName
      if (ssqRes.leap > 0 && ssqRes.ym[ssqRes.leap] == targetName) {
        monthIndex = ssqRes.leap;
      } else {
        throw ArgumentError("Year $year does not have leap month $month");
      }
    } else {
      // 用户说是平月
      // 通常取第一个匹配项
      // 但如果第一个匹配项本身就是闰月（比如历史历法特殊情况？不会，闰月都在后面）
      // 正常情况下，平月是第一个。
      monthIndex = matches[0];

      // 特殊情况：如果用户输入 "二月" (isLeap=false)
      // 而该年闰正月（ym: 正, 闰正, 二...）
      // 那二月只有一个，matches[0] 就是它。

      // 如果该年闰二月 (ym: 二, 闰二...)
      // matches 有两个。取第一个。
    }

    // 4. 计算目标日期的 JD
    // 初一 JD
    double startJD = ssqRes.hs[monthIndex];
    // 加上日期偏移 (day - 1)
    double targetJD = startJD + (day - 1);

    // 加上时辰偏移
    // hs[i] 是 12:00. hourIndex * 2 是目标小时.
    // 偏移 = (hour - 12) / 24.
    targetJD += (hourIndex * 2.0 - 12.0) / 24.0;

    // 5. 构造 AstroDateTime 并调用 fromSolar
    final solarDate = AstroDateTime.fromJ2000(targetJD);

    return fromSolar(solarDate, gender, options: options, location: location);
  }

  static int _monthNameToInt(String name) {
    switch (name) {
      case "正":
        return 1;
      case "一":
        return 1;
      case "二":
        return 2;
      case "三":
        return 3;
      case "四":
        return 4;
      case "五":
        return 5;
      case "六":
        return 6;
      case "七":
        return 7;
      case "八":
        return 8;
      case "九":
        return 9;
      case "十":
        return 10;
      case "十一":
        return 11;
      case "十二":
        return 12;
      case "拾贰":
        return 12;
      case "十三":
        return 13;
      default:
        return 0;
    }
  }

  static GanZhi _parseGanZhi(String gz) {
    if (gz.length != 2) return GanZhi(TianGan.jia, DiZhi.zi);
    final ganName = gz[0];
    final zhiName = gz[1];
    return GanZhi(TianGan.fromName(ganName), DiZhi.fromName(zhiName));
  }
}
