/// 章动 (Nutation) 和黄赤交角 (Obliquity) 计算。
///
/// 移植自寿星万年历 (sxwnl) eph0.js。
/// 原作者：许剑伟
library;

import 'dart:math' as math;

import 'math_utils.dart';

// ==================== 章动计算 ====================

/// 中精度章动计算表。
///
/// 每 5 个元素为一组：[相位, 频率, 频率修正, 黄经章动系数, 交角章动系数]
final List<double> _nutB = [
  2.1824,
  -33.75705,
  36e-6,
  -1720,
  920,
  3.5069,
  1256.66393,
  11e-6,
  -132,
  57,
  1.3375,
  16799.4182,
  -51e-6,
  -23,
  10,
  4.3649,
  -67.5141,
  72e-6,
  21,
  -9,
  0.04,
  -628.302,
  0,
  -14,
  0,
  2.36,
  8328.691,
  0,
  7,
  0,
  3.46,
  1884.966,
  0,
  -5,
  2,
  5.44,
  16833.175,
  0,
  -4,
  2,
  3.69,
  25128.110,
  0,
  -3,
  0,
  3.55,
  628.362,
  0,
  2,
  0,
];

/// 中精度章动计算。
///
/// [t] 为儒略世纪数 (J2000.0 起算)。
/// 返回 [黄经章动, 交角章动]，单位为弧度。
///
/// 原函数名：nutation2(t)
List<double> nutation2(double t) {
  final t2 = t * t;
  double dL = 0, dE = 0;

  for (var i = 0; i < _nutB.length; i += 5) {
    final c = _nutB[i] + _nutB[i + 1] * t + _nutB[i + 2] * t2;
    final a = (i == 0) ? -1.742 * t : 0.0;
    dL += (_nutB[i + 3] + a) * math.sin(c);
    dE += _nutB[i + 4] * math.cos(c);
  }

  return [dL / 100 / rad, dE / 100 / rad];
}

/// 只计算黄经章动（比 nutation2 快，不需要交角章动时使用）。
///
/// [t] 为儒略世纪数。
/// 返回黄经章动，单位为弧度。
///
/// 原函数名：nutationLon2(t)
double nutationLon2(double t) {
  final t2 = t * t;
  double dL = 0;

  for (var i = 0; i < _nutB.length; i += 5) {
    final a = (i == 0) ? -1.742 * t : 0.0;
    dL +=
        (_nutB[i + 3] + a) *
        math.sin(_nutB[i] + _nutB[i + 1] * t + _nutB[i + 2] * t2);
  }

  return dL / 100 / rad;
}

// ==================== 黄赤交角 ====================

/// 计算黄赤交角 (P03 模型)。
///
/// [t] 为儒略世纪数 (J2000.0 起算)。
/// 返回黄赤交角，单位为弧度。
///
/// 原函数名：hcjj(t)
double hcjj(double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;
  final t5 = t4 * t;
  return (84381.4060 -
          46.836769 * t -
          0.0001831 * t2 +
          0.00200340 * t3 -
          5.76e-7 * t4 -
          4.34e-8 * t5) /
      rad;
}
