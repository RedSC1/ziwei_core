/// 干支计算器。
///
/// 移植自寿星万年历 (sxwnl) lunar.js 的 obb.mingLiBaZi 部分。
/// 负责计算年、月、日、时的干支。
library;

import 'delta_t.dart';
import 'math_utils.dart';
import 'solar_lunar_pos.dart';

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
/// [jd] 为目标时刻的 J2000 相对儒略日 (UT)。
/// [trueSolarTimeJD] 为当地真太阳时的 J2000 相对儒略日 (用于定八字时柱)。
///
/// 返回完整的八字（四柱）。
GanZhiResult calcGanZhi(double jd, double trueSolarTimeJD) {
  // 1. 计算节气索引 k
  // jd 是 UT。需要转力学时 (TT)
  // jd2 = jd + dt_T(jd)
  final jd2 = jd + dtT(jd);

  // 计算太阳视黄经 (累积弧度)
  // t = 世纪数
  final w = sALon(jd2 / 36525.0, -1);

  // 计算节气数 (1984年立春起算)
  // k 是从某个基准点开始的节气计数
  // 立春对应 315度。
  // (w / 2pi * 360 + 45 + 15 * 360) / 30
  // 原版公式
  final k = int2((w / pi2 * 360 + 45 + 15 * 360) / 30);

  // 2. 年柱
  // v = int2(k/12 + 6000000)
  var v = int2(k / 12 + 6000000);
  final yearGan = _gan[v % 10];
  final yearZhi = _zhi[v % 12];

  // 3. 月柱
  // v = k + 2 + 60000000
  v = k + 2 + 60000000;
  final monthGan = _gan[v % 10];
  final monthZhi = _zhi[v % 12];

  // 4. 日柱
  // 原版逻辑：
  // jd += pty_zty2(...) + J/pi/2; // 本地真太阳时
  // jd += 13/24; // 转为前一日23点起算
  // D = floor(jd);
  // v = D - 6 + 9000000;

  // 我们直接用传入的真太阳时 trueSolarTimeJD (J2000相对值)
  // 真太阳时 JD (北京时间？不，trueSolarTimeJD 是基于 AstroDateTime.toJulianDay 算的，
  // 也就是绝对 JD ? 不，TimeAdapter 里传入的是 trueSolarJD - 2451545 (相对值)。
  // 这里的 trueSolarTimeJD 是相对值。

  // 原版 jd += 13/24 是为了处理早晚子时。
  // 我们已经有了 trueSolarTimeJD。
  // 日干支通常以 23:00 为界？还是 0:00？
  // 八字排盘通常 23:00 换日柱（早子时）。
  // sxwnl 的 `+ 13/24`：
  // 12:00 + 13h = 25:00 = 次日 1:00。
  // 也就是说 11:00 (23:00前) + 13h = 24:00 (刚好换日)。
  // 所以 23:00 以后算次日。
  //
  // 我们的 trueSolarTimeJD 是相对值 (x.0 = 12:00)。
  // x.0 (12:00) + 13/24 = x.5 + ... = x + 1.04.
  // x.458 (23:00) + 13/24 = x + 0.999... ≈ x+1.
  // 所以 trueSolarTimeJD + 13/24 向下取整，确实能实现 23:00 换日。

  // 注意：TimeAdapter 里的 trueSolarJD 是通过 `trueSolarTime.toJulianDay()` 获得的。
  // `trueSolarTime` 是 `AstroDateTime`。
  // 如果 `trueSolarTime` 是 23:30。JD 是 x.479。
  // + 13/24 (0.5416) = x + 1.02。
  // floor -> x+1。
  // 如果是 22:30。JD x.437。
  // + 0.5416 = x + 0.97.
  // floor -> x。
  // 逻辑成立。

  // 但是，我们还要加上绝对 JD 的基准 (2451545)。
  // trueSolarTimeJD 是相对值。
  // 相对值 0.0 (J2000 12:00) 是 戊午日 (54)。
  // 0 + 13/24 = 0.54。floor = 0。
  // 0 - 6 = -6。
  // -6 + 9000000 = ...
  // -6 % 60 = -6。54?
  // 让我们看看原版 v 计算：
  // v = D - 6 + 9000000。
  // 如果 D=0。v = 8999994。
  // 8999994 % 10 = 4 (戊)。
  // 8999994 % 12 = 6 (午)。
  // 戊午。对上了！
  // 所以只要 D 是相对天数即可。

  // 计算 D
  final jdForDay = trueSolarTimeJD + 13.0 / 24.0;
  final D = jdForDay.floor();

  v = D - 6 + 9000000;
  final dayGan = _gan[v % 10];
  final dayZhi = _zhi[v % 12];

  // 5. 时柱
  // SC = int2( (jd - D) * 12 )
  final SC = int2((jdForDay - D) * 12);

  v = (D - 1) * 12 + 90000000 + SC;
  final timeGan = _gan[v % 10];
  final timeZhi = _zhi[v % 12]; // SC 实际上就是 timeZhiIndex

  return GanZhiResult(
    yearGanZhi: "$yearGan$yearZhi",
    monthGanZhi: "$monthGan$monthZhi",
    dayGanZhi: "$dayGan$dayZhi",
    timeGanZhi: "$timeGan$timeZhi",
    timeZhiIndex: SC % 12,
  );
}

/// 辅助：获取天干
String getGan(int idx) => _gan[idx % 10];

/// 辅助：获取地支
String getZhi(int idx) => _zhi[idx % 12];
