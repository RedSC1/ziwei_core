/// 太阳/月亮位置计算。
///
/// 移植自寿星万年历 (sxwnl) eph0.js 的 XL 计算部分。
/// 原作者：许剑伟
///
/// 包含：
/// - XL0_calc: VSOP87 行星坐标级数求和
/// - XL1_calc: 月球坐标级数求和
/// - 太阳/月亮黄经、视黄经
/// - 给定黄经反求时刻（用于精确节气和合朔）
library;

import 'dart:math' as math;

import 'math_utils.dart';
import 'nutation.dart';
import 'xl_data.dart';

// ==================== 光行差 ====================

/// 太阳光行差（黄经光行差）。
///
/// [t] 为儒略世纪数。返回弧度。
///
/// 原函数名：gxc_sunLon(t)
double gxcSunLon(double t) {
  final v = -0.043126 + 628.301955 * t - 0.000002732 * t * t; // 平近点角
  final e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t; // 轨道离心率
  return (-20.49552 * (1 + e * math.cos(v))) / rad; // 黄经光行差
}

/// 月球黄经光行差。
///
/// 原函数名：gxc_moonLon(t)
double gxcMoonLon(double t) => -3.4e-6;

// ==================== XL0: 行星坐标计算 ====================

/// VSOP87 行星坐标级数求和。
///
/// [xt] 星体索引 (0=地球, 1=水星, ..., 7=海王星)
/// [zn] 坐标号 (0=黄经, 1=黄纬, 2=向径)
/// [t] 儒略世纪数 (J2000.0 起算)
/// [n] 计算项数 (负数=全部项)
///
/// 原函数名：XL0_calc(xt, zn, t, n)
double xl0Calc(int xt, int zn, double t, int n) {
  t /= 10; // 转为儒略千年数
  double v = 0, tn = 1;
  final f = xl0[xt];
  final pn = zn * 6 + 1;
  final n0 = f[pn + 1].toInt() - f[pn].toInt(); // N0 序列总数

  for (var i = 0; i < 6; i++, tn *= t) {
    final n1 = f[pn + i].toInt();
    final n2 = f[pn + 1 + i].toInt();
    final ni = n2 - n1;
    if (ni == 0) continue;

    int termN;
    if (n < 0) {
      termN = n2; // 全部项
    } else {
      termN = int2(3.0 * n * ni / n0 + 0.5) + n1;
      if (i != 0) termN += 3;
      if (termN > n2) termN = n2;
    }

    double c = 0;
    for (var j = n1; j < termN; j += 3) {
      c += f[j] * math.cos(f[j + 1] + t * f[j + 2]);
    }
    v += c * tn;
  }

  v /= f[0];

  if (xt == 0) {
    // 地球修正
    final t2 = t * t, t3 = t2 * t;
    if (zn == 0) {
      v += (-0.0728 - 2.7702 * t - 1.1019 * t2 - 0.0996 * t3) / rad;
    }
    if (zn == 1) {
      v += (0.0000 + 0.0004 * t + 0.0004 * t2 - 0.0026 * t3) / rad;
    }
    if (zn == 2) {
      v += (-0.0020 + 0.0044 * t + 0.0213 * t2 - 0.0250 * t3) / 1000000;
    }
  } else {
    // 其它行星修正
    final dv = xl0Xzb[(xt - 1) * 3 + zn];
    if (zn == 0) {
      v += -3 * t / rad;
    }
    if (zn == 2) {
      v += dv / 1000000;
    } else {
      v += dv / rad;
    }
  }

  return v;
}

// ==================== XL1: 月球坐标计算 ====================

/// 月球坐标级数求和。
///
/// [zn] 坐标号 (0=黄经, 1=黄纬, 2=距离)
/// [t] 儒略世纪数 (J2000.0 起算)
/// [n] 计算项数 (负数=全部项)
///
/// 原函数名：XL1_calc(zn, t, n)
double xl1Calc(int zn, double t, int n) {
  final ob = xl1[zn];
  double v = 0, tn = 1;
  var t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;
  final t5 = t4 * t;
  final tx = t - 10;

  if (zn == 0) {
    // 月球平黄经（弧度）
    v +=
        (3.81034409 +
            8399.684730072 * t -
            3.319e-05 * t2 +
            3.11e-08 * t3 -
            2.033e-10 * t4) *
        rad;
    // 岁差（角秒）
    v +=
        5028.792262 * t +
        1.1124406 * t2 +
        0.00007699 * t3 -
        0.000023479 * t4 -
        0.0000000178 * t5;
    // 对公元3000年至公元5000年的拟合
    if (tx > 0) v += -0.866 + 1.43 * tx + 0.054 * tx * tx;
  }

  // 缩放 t 的高次方
  t2 /= 1e4;
  final t3s = t3 / 1e8;
  final t4s = t4 / 1e8;

  var termN = n * 6;
  if (termN < 0) termN = ob[0].length;

  for (var i = 0; i < ob.length; i++, tn *= t) {
    final f = ob[i];
    var ni = int2(termN.toDouble() * f.length / ob[0].length + 0.5);
    if (i != 0) ni += 6;
    if (ni >= f.length) ni = f.length;

    double c = 0;
    for (var j = 0; j < ni; j += 6) {
      c +=
          f[j] *
          math.cos(
            f[j + 1] +
                t * f[j + 2] +
                t2 * f[j + 3] +
                t3s * f[j + 4] +
                t4s * f[j + 5],
          );
    }
    v += c * tn;
  }

  if (zn != 2) v /= rad;
  return v;
}

// ==================== 高层接口 ====================

/// 地球黄经。
///
/// [t] 儒略世纪数, [n] 计算项数 (负数=全部)。
/// 返回弧度。
///
/// 原函数名：XL.E_Lon(t, n)
double eLon(double t, int n) => xl0Calc(0, 0, t, n);

/// 月球黄经。
///
/// [t] 儒略世纪数, [n] 计算项数 (负数=全部)。
/// 返回弧度。
///
/// 原函数名：XL.M_Lon(t, n)
double mLon(double t, int n) => xl1Calc(0, t, n);

/// 太阳视黄经。
///
/// [t] 儒略世纪数, [n] 计算项数 (负数=全部)。
/// 返回弧度。
///
/// 原函数名：XL.S_aLon(t, n)
double sALon(double t, int n) {
  return eLon(t, n) + nutationLon2(t) + gxcSunLon(t) + math.pi;
}

/// 月日视黄经差（月球视黄经 - 太阳视黄经）。
///
/// [t] 儒略世纪数, [mn] 月球计算项数, [sn] 太阳计算项数。
/// 返回弧度。
///
/// 原函数名：XL.MS_aLon(t, Mn, Sn)
double msALon(double t, int mn, int sn) {
  return mLon(t, mn) + gxcMoonLon(t) - (eLon(t, sn) + gxcSunLon(t) + math.pi);
}

// ==================== 速度估算 ====================

/// 地球运动角速度估算（弧度/世纪）。
///
/// [t] 儒略世纪数。误差小于万分之三。
///
/// 原函数名：XL.E_v(t)
double eV(double t) {
  final f = 628.307585 * t;
  return 628.332 +
      21 * math.sin(1.527 + f) +
      0.44 * math.sin(1.48 + f * 2) +
      0.129 * math.sin(5.82 + f) * t +
      0.00055 * math.sin(4.21 + f) * t * t;
}

/// 月球运动角速度估算（弧度/世纪）。
///
/// [t] 儒略世纪数。
///
/// 原函数名：XL.M_v(t)
double mV(double t) {
  var v =
      8399.71 - 914 * math.sin(0.7848 + 8328.691425 * t + 0.0001523 * t * t);
  v -=
      179 * math.sin(2.543 + 15542.7543 * t) +
      160 * math.sin(0.1874 + 7214.0629 * t) +
      62 * math.sin(3.14 + 16657.3828 * t) +
      34 * math.sin(4.827 + 16866.9323 * t) +
      22 * math.sin(4.9 + 23871.4457 * t) +
      12 * math.sin(2.59 + 14914.4523 * t) +
      7 * math.sin(0.23 + 6585.7609 * t) +
      5 * math.sin(0.9 + 25195.624 * t) +
      5 * math.sin(2.32 + -7700.3895 * t) +
      5 * math.sin(3.88 + 8956.9934 * t) +
      5 * math.sin(0.49 + 7771.3771 * t);
  return v;
}

// ==================== 反求时间（牛顿迭代） ====================

/// 已知太阳视黄经反求时间（高精度）。
///
/// [w] 目标太阳视黄经（弧度）。
/// 返回 J2000.0 起算的儒略世纪数。
///
/// 原函数名：XL.S_aLon_t(W)
double sALonT(double w) {
  var v = 628.3319653318;
  var t = (w - 1.75347 - math.pi) / v;
  v = eV(t);
  t += (w - sALon(t, 10)) / v;
  v = eV(t);
  t += (w - sALon(t, -1)) / v;
  return t;
}

/// 已知太阳视黄经反求时间（低精度，误差不超过600秒）。
///
/// [w] 目标太阳视黄经（弧度）。
/// 返回 J2000.0 起算的儒略世纪数。
///
/// 原函数名：XL.S_aLon_t2(W)
double sALonT2(double w) {
  final v = 628.3319653318;
  var t = (w - 1.75347 - math.pi) / v;
  t -=
      (0.000005297 * t * t +
          0.0334166 * math.cos(4.669257 + 628.307585 * t) +
          0.0002061 * math.cos(2.67823 + 628.307585 * t) * t) /
      v;
  t +=
      (w -
          eLon(t, 8) -
          math.pi +
          (20.5 + 17.2 * math.sin(2.1824 - 33.75705 * t)) / rad) /
      v;
  return t;
}

/// 已知月日视黄经差反求时间（高精度）。
///
/// [w] 目标月日视黄经差（弧度）。
/// 返回 J2000.0 起算的儒略世纪数。
///
/// 原函数名：XL.MS_aLon_t(W)
double msALonT(double w) {
  var v = 7771.37714500204;
  var t = (w + 1.08472) / v;
  t += (w - msALon(t, 3, 3)) / v;
  v = mV(t) - eV(t);
  t += (w - msALon(t, 20, 10)) / v;
  t += (w - msALon(t, -1, 60)) / v;
  return t;
}

/// 已知月日视黄经差反求时间（低精度，误差不超过600秒）。
///
/// [w] 目标月日视黄经差（弧度）。
/// 返回 J2000.0 起算的儒略世纪数。
///
/// 原函数名：XL.MS_aLon_t2(W)
double msALonT2(double w) {
  var v = 7771.37714500204;
  var t = (w + 1.08472) / v;
  final t2 = t * t;
  t -=
      (-0.00003309 * t2 +
          0.10976 * math.cos(0.784758 + 8328.6914246 * t + 0.000152292 * t2) +
          0.02224 * math.cos(0.18740 + 7214.0628654 * t - 0.00021848 * t2) -
          0.03342 * math.cos(4.669257 + 628.307585 * t)) /
      v;
  final l =
      mLon(t, 20) -
      (4.8950632 +
          628.3319653318 * t +
          0.000005297 * t * t +
          0.0334166 * math.cos(4.669257 + 628.307585 * t) +
          0.0002061 * math.cos(2.67823 + 628.307585 * t) * t +
          0.000349 * math.cos(4.6261 + 1256.61517 * t) -
          20.5 / rad);
  v =
      7771.38 -
      914 * math.sin(0.7848 + 8328.691425 * t + 0.0001523 * t * t) -
      179 * math.sin(2.543 + 15542.7543 * t) -
      160 * math.sin(0.1874 + 7214.0629 * t);
  t += (w - l) / v;
  return t;
}
