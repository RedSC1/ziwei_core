/// sxwnl 天文数学工具函数和常量。
///
/// 移植自寿星万年历 (sxwnl) eph0.js 的基础数学工具部分。
/// 原作者：许剑伟
library;

import 'dart:math' as math;

// ==================== 天文常量 ====================

/// J2000.0 历元的儒略日 (2000-01-01 12:00 TT)
const double j2000 = 2451545.0;

/// 2π
const double pi2 = math.pi * 2;

/// π/2
const double piHalf = math.pi / 2;

/// 每弧度的角秒数 (206264.806...)
/// 用法：角秒值 / rad → 弧度值
final double rad = 180 * 3600 / math.pi;

/// 每弧度的度数 (57.2957...)
final double radd = 180 / math.pi;

// ==================== 天文物理常量 ====================

/// 地球赤道半径 (千米)
const double csREar = 6378.1366;

/// 地球平均半径 (千米)
const double csREarA = 0.99834 * csREar;

/// 地球极赤半径比
const double csBa = 0.99664719;

/// 地球极赤半径比的平方
const double csBa2 = csBa * csBa;

/// 天文单位长度 (千米)
const double csAU = 1.49597870691e8;

/// sin(太阳视差)
final double csSinP = csREar / csAU;

/// 光速 (千米/秒)
const double csGS = 299792.458;

/// 每天文单位的光行时间 (儒略世纪)
final double csAgx = csAU / csGS / 86400 / 36525;

// ==================== 数学工具函数 ====================

/// 取整数部分（向下取整），对应 JS 的 Math.floor()。
///
/// 原函数名：int2(v)
int int2(double v) => v.floor();

/// 临界余数：a 与最近的整倍数 b 相差的距离。
///
/// 原函数名：mod2(a, b)
/// 注意：sxwnl 中有两个 mod2，这里用的是后面那个（临界余数版本），
/// 因为它在历法计算中被广泛使用。
double mod2(double a, double b) {
  var c = (a + b) % b;
  if (c > b / 2.0) c -= b;
  return c;
}

/// 将角度归一化到 [0, 2π) 范围。
///
/// 原函数名：rad2mrad(v)
double rad2mrad(double v) {
  v = v % pi2;
  if (v < 0) v += pi2;
  return v;
}

/// 将角度归一化到 (-π, π] 范围。
///
/// 原函数名：rad2rrad(v)
double rad2rrad(double v) {
  v = v % pi2;
  if (v <= -math.pi) v += pi2;
  if (v > math.pi) v -= pi2;
  return v;
}
