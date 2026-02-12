/// 干支计算器。
///
/// 移植自寿星万年历 (sxwnl) lunar.js 的 obb.mingLiBaZi 部分。
/// 负责计算年、月、日、时的干支。
library;

import 'math_utils.dart';

// 天干地支常量
const List<String> _gan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"];
const List<String> _zhi = [
  "子",
  "丑",
  "寅",
  "卯",
  "辰",
  "巳",
  "午",
  "未",
  "申",
  "酉",
  "戌",
  "亥",
];

/// 干支结果
class GanZhiResult {
  final String yearGanZhi;
  final String monthGanZhi;
  final String dayGanZhi;
  final String timeGanZhi;

  /// 时辰地支索引 (0=子, 1=丑, ...)
  final int timeZhiIndex;

  GanZhiResult({
    required this.yearGanZhi,
    required this.monthGanZhi,
    required this.dayGanZhi,
    required this.timeGanZhi,
    required this.timeZhiIndex,
  });

  @override
  String toString() => '$yearGanZhi $monthGanZhi $dayGanZhi $timeGanZhi';
}

/// 计算干支。
///
/// [jd] 为目标时刻的 J2000 相对儒略日 (TT)。
/// [trueSolarTimeJD] 为当地真太阳时的 J2000 相对儒略日 (用于定八字时柱)。
/// [solarTermJD] 为当前所属节令（立春、惊蛰等）的时刻，用于定月柱。
/// [lichunJD] 为当年立春的时刻，用于定年柱。
///
/// 注意：紫微斗数排盘的年干支可能基于农历年，也可能基于节气年。
/// 这里提供的是标准的节气八字计算。
/// 计算干支。
///
/// [jd] 为目标时刻的 J2000 相对儒略日 (TT)。
/// [trueSolarTimeJD] 为当地真太阳时的 J2000 相对儒略日 (用于定八字时柱)。
/// [zq] 为当年的节气表 (来自 SSQResult.zq)，包含从冬至开始的 25 个节气。
///
/// 返回完整的八字（四柱）。
GanZhiResult calcGanZhi(double jd, double trueSolarTimeJD, List<double> zq) {
  // 1. 年柱 (以立春为界)
  // zq[3] 是立春。如果 jd < 立春，则算上一年。
  // 但是这里的 zq 是“包含 jd 的这一年”的节气表。
  // 我们需要确定 jd 所在的“节气年”的立春。

  // SSQ.calcY 的逻辑是：以冬至为锚点计算一整年。
  // zq[0] 是冬至。zq[3] 是立春。
  // 如果 jd 在 [冬至, 立春) 之间，说明是上一年的尾巴（癸亥月/甲子月？不，是丑月/子月）。
  // 年份应该是“公历年”或者“农历年”？
  // 八字年柱是干支纪年。

  // 我们需要知道当前节气年相对于 1984(甲子) 的偏移。
  // 简单办法：根据立春时刻反推年份。
  // 1984年立春 JD ≈ -5844 (J2000相对)
  // 年数 ≈ (立春JD - (-5844)) / 365.2422

  final lichun = zq[3];

  // 估算当前立春对应的年份 (相对于 1984 甲子)
  // J2000 (2000年) 是 庚辰年 (16)
  // 2000年立春 (JD ≈ 34)
  // 年份偏移 = (lichun - 34) / 365.25 ≈ 年份差
  // 2000 + diff = 当前公历年
  // 当前干支序 = (2000 - 1984 + 16 + diff) % 60 ?
  // 1984是甲子(0)。2000是庚辰(16)。
  // diff 是 (CurrentYear - 2000).
  // GanZhi = (16 + diff) % 60.

  // J2000 基准 (2451545.0)
  // lichun 是 J2000 相对值，需要加上基准才变成绝对 JD
  // 1984年立春 JD ≈ 2445734.5
  // J2000 JD = 2451545.0
  // lichun (相对) ≈ -5810
  // lichun + 2451545 ≈ 2445735. 正确。

  // 修正年份偏移计算：
  // lichun + j2000 = 绝对 JD
  // 2000年立春绝对 JD ≈ 2451579
  // (AbsLichun - 2451579) / 365.2422
  // 或者直接用相对值算：
  // 2000年立春相对值 ≈ 34.0
  // (lichun - 34.0) / 365.2422
  final yearOffset = (lichun - 34.0) / 365.2422;

  var yearIdx = (16 + yearOffset.round()) % 60;
  if (yearIdx < 0) yearIdx += 60;

  // 比较时必须统一单位！
  // jd 是绝对 JD，lichun 是相对 JD
  if (jd < lichun + j2000) {
    yearIdx = (yearIdx - 1 + 60) % 60;
    // print("DEBUG: Decremented yearIdx to $yearIdx");
  } else {
    // print("JD >= Lichun ($jd >= ${lichun + j2000})");
  }

  final yearGan = _gan[yearIdx % 10];
  final yearZhi = _zhi[yearIdx % 12];

  // 2. 月柱 (以节令为界)
  // 寻找 jd 所在的节令区间
  // zq 索引:
  // 0=冬至(子中), 1=小寒(丑节), 2=大寒(丑中), 3=立春(寅节),
  // 4=雨水(寅中), 5=惊蛰(卯节), ...
  // 节令点是奇数索引：1, 3, 5, 7 ...
  // 实际上月建是看节令 (Section)，不是中气 (Center)。
  // 立春(3) -> 寅月
  // 惊蛰(5) -> 卯月
  // ...
  // 小寒(1) -> 丑月
  // 大雪(-1? 上一年的 23) -> 子月
  //
  // 我们需要遍历 zq 找到 jd 所在的节令。
  // zq[1] (小寒) <= jd < zq[3] (立春) -> 丑月 (11)
  // zq[3] (立春) <= jd < zq[5] (惊蛰) -> 寅月 (0)

  int monthZhiIdx = 0; // 默认寅月? 不，要算。

  // 我们只关心节令 (奇数索引: 1, 3, 5 ... 23)
  // zq[1] 小寒 (12月/丑)
  // zq[3] 立春 (1月/寅)
  // ...
  // zq[23] 大雪 (11月/子)
  // zq[25] (下一个小寒)

  // 如果 jd < zq[1] (冬至后，小寒前)，属于子月 (10) (即上一年的 11 月)
  // 等等，地支索引：0=子, 1=丑, 2=寅...
  // 寅月是 2。

  // 比较时同样需要加 j2000
  if (jd < zq[1] + j2000) {
    monthZhiIdx = 0; // 子月
  } else if (jd >= zq[23] + j2000) {
    monthZhiIdx = 0; // 子月 (下一个)
  } else {
    // 遍历中间的节令
    // 从 zq[1] 开始，步长 2
    for (int k = 1; k < 23; k += 2) {
      if (jd >= zq[k] + j2000 && jd < zq[k + 2] + j2000) {
        // k=1 (小寒) -> 丑月 (1)
        // k=3 (立春) -> 寅月 (2)
        // 规律: (k-1)/2 + 1
        monthZhiIdx = (k - 1) ~/ 2 + 1;
        break;
      }
    }
  }

  // 月干：五虎遁
  // 年干索引 yearIdx % 10 (0=甲)
  // 月支索引 monthZhiIdx (0=子, 1=丑, 2=寅...)
  // 五虎遁是从寅月开始的。
  // 甲己之年丙作首 (寅月=丙)
  // 如果是子月（11月/上一年的），年干要用哪一年的？
  // 子月通常算作当年（建子）还是次年？
  // 命理上，子月分早子晚子，或者冬至换年？
  // 标准八字：立春换年。
  // 所以子月、丑月都在立春前，属于“上一年”。
  // 我们的 yearIdx 已经在上面处理过 (jd < lichun 则 yearIdx--)。
  // 所以直接用 yearIdx 的年干来遁。

  // 五虎遁公式：(年干*2 + 月支偏移) % 10
  // 月支偏移：寅=2。需要把 monthZhiIdx 映射到“寅=0”的坐标系？
  // 不，直接用通用公式。
  // 甲(0)年，寅(2)月 -> 丙(2)。(0*2 + ?) = 2 -> +2
  // 甲(0)年，子(0)月 -> ?
  // 倒推：寅(丙) -> 丑(乙) -> 子(甲)
  // 所以子月应该是甲子。
  // 公式：(0*2 + ?) = 0 -> +0
  // 貌似 offset = 2 不对。

  // 重新推导：
  // 甲(0)年：
  // 子(0) -> 甲(0)
  // 丑(1) -> 乙(1)
  // 寅(2) -> 丙(2)
  // 卯(3) -> 丁(3)
  // ...
  // 看来公式就是 (年干 x 2 + 月支) % 10 ！
  // 验证：乙(1)年 -> (2+2)=4=戊寅。对的 (乙庚之年戊为头)。

  final yearGanIdx = yearIdx % 10;
  final monthGanIdx = (yearGanIdx * 2 + monthZhiIdx) % 10;

  final monthGan = _gan[monthGanIdx];
  final monthZhi = _zhi[monthZhiIdx];

  // 3. 日柱
  // jd 是绝对 JD。
  // J2000.0 (JD 2451545.0) 是 戊午日 (54)
  // (2451545.0 + 0.5) -> 2451545
  // (2451545 + 49) % 60 = 54. 正确。
  // 所以直接用 jd + 0.5
  final dayIdx = (int2(jd + 0.5) + 49) % 60;
  final dayGanIdx = dayIdx % 10;
  final dayGan = _gan[dayGanIdx];
  final dayZhi = _zhi[dayIdx % 12];

  // 4. 时柱
  var tjd = trueSolarTimeJD + 0.5; // 转为从子夜 0:00 起算
  tjd += 1.0 / 24.0; // 修正子时跨天 (23:00~01:00 为子)
  final timeTerm = tjd - int2(tjd); // 取小数部分
  final timeIndex = int2(timeTerm * 12) % 12; // 0~11

  // 五鼠遁
  final timeGanIdx = (dayGanIdx * 2 + timeIndex) % 10;
  final timeGan = _gan[timeGanIdx];
  final timeZhi = _zhi[timeIndex];

  return GanZhiResult(
    yearGanZhi: "$yearGan$yearZhi",
    monthGanZhi: "$monthGan$monthZhi",
    dayGanZhi: "$dayGan$dayZhi",
    timeGanZhi: "$timeGan$timeZhi",
    timeZhiIndex: timeIndex,
  );
}

/// 辅助：获取天干
String getGan(int idx) => _gan[idx % 10];

/// 辅助：获取地支
String getZhi(int idx) => _zhi[idx % 12];

/// 五虎遁（年上起月）
/// [yearGanIdx] 年干索引 (0=甲)
/// [monthIndex] 月份索引 (0=寅月/立春, 1=卯月/惊蛰...)
/// 返回月干索引
int wuHuDun(int yearGanIdx, int monthIndex) {
  // 甲己之年丙作首 -> 甲(0) -> 寅月是丙(2) -> (0%5)*2 + 2 = 2
  // 乙庚之年戊为头 -> 乙(1) -> 寅月是戊(4) -> (1%5)*2 + 2 = 4
  return ((yearGanIdx % 5) * 2 + 2 + monthIndex) % 10;
}

/// 五鼠遁（日上起时）
/// [dayGanIdx] 日干索引
/// [timeZhiIdx] 时支索引 (0=子)
/// 返回时干索引
int wuShuDun(int dayGanIdx, int timeZhiIdx) {
  return (dayGanIdx % 5 * 2 + timeZhiIdx) % 10;
}
