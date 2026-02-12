import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ziwei_core/src/sxwnl/delta_t.dart';
import 'package:ziwei_core/src/sxwnl/math_utils.dart';
import 'package:ziwei_core/src/sxwnl/nutation.dart';

void main() {
  // ==================== math_utils ====================

  group('math_utils 常量', () {
    test('J2000', () {
      expect(j2000, 2451545.0);
    });

    test('pi2 ≈ 2π', () {
      expect(pi2, closeTo(2 * math.pi, 1e-15));
    });

    test('rad ≈ 206264.8', () {
      // 每弧度的角秒数
      expect(rad, closeTo(206264.806, 0.001));
    });

    test('radd ≈ 57.2958', () {
      expect(radd, closeTo(57.29577951, 0.0001));
    });
  });

  group('int2', () {
    test('正数', () {
      expect(int2(3.7), 3);
      expect(int2(3.0), 3);
    });

    test('负数向下取整', () {
      expect(int2(-1.2), -2);
      expect(int2(-1.0), -1);
    });
  });

  group('mod2 (临界余数)', () {
    test('基本用例', () {
      // a=5, b=3 → (5+3)%3 = 2, 2 > 1.5 → 2-3 = -1
      expect(mod2(5, 3), closeTo(-1, 1e-10));
    });

    test('a=1, b=3 → 1 (小于 b/2 不减)', () {
      expect(mod2(1, 3), closeTo(1, 1e-10));
    });

    test('a=0, b=3 → 0', () {
      expect(mod2(0, 3), closeTo(0, 1e-10));
    });

    test('负数', () {
      // a=-1, b=3 → (-1+3)%3 = 2, 2 > 1.5 → -1
      expect(mod2(-1, 3), closeTo(-1, 1e-10));
    });
  });

  group('rad2mrad', () {
    test('已经在 [0, 2π) 内不变', () {
      expect(rad2mrad(1.0), closeTo(1.0, 1e-10));
    });

    test('负角度归一化', () {
      expect(rad2mrad(-math.pi / 2), closeTo(3 * math.pi / 2, 1e-10));
    });

    test('大于 2π 归一化', () {
      expect(rad2mrad(3 * math.pi), closeTo(math.pi, 1e-10));
    });

    test('0 不变', () {
      expect(rad2mrad(0), closeTo(0, 1e-10));
    });
  });

  group('rad2rrad', () {
    test('已经在 (-π, π] 内不变', () {
      expect(rad2rrad(1.0), closeTo(1.0, 1e-10));
    });

    test('大于 π 归一化', () {
      expect(rad2rrad(3 * math.pi / 2), closeTo(-math.pi / 2, 1e-10));
    });

    test('小于 -π 归一化', () {
      expect(rad2rrad(-3 * math.pi / 2), closeTo(math.pi / 2, 1e-10));
    });
  });

  // ==================== delta_t ====================

  group('dtCalc (ΔT 秒)', () {
    test('2000年 ≈ 63.87秒', () {
      // dt_at 表中 2000 年的 a0 就是 63.87
      expect(dtCalc(2000), closeTo(63.87, 0.5));
    });

    test('1900年 ≈ -2.3秒', () {
      expect(dtCalc(1900), closeTo(-2.3, 1.0));
    });

    test('2020年 ≈ 69秒', () {
      expect(dtCalc(2020), closeTo(69.36, 1.0));
    });

    test('公元前1000年有合理值', () {
      final dt = dtCalc(-1000);
      // 公元前1000年 ΔT 应该很大（几万秒级别）
      expect(dt, greaterThan(10000));
    });

    test('远未来外推不崩溃', () {
      final dt = dtCalc(3000);
      // 不要求精确，只要不崩溃且返回合理范围
      expect(dt.isFinite, true);
    });

    test('单调性：近现代 ΔT 大致递增', () {
      // 1960-2020 期间 ΔT 整体递增
      final dt1960 = dtCalc(1960);
      final dt1980 = dtCalc(1980);
      final dt2000 = dtCalc(2000);
      final dt2020 = dtCalc(2020);
      expect(dt1980, greaterThan(dt1960));
      expect(dt2000, greaterThan(dt1980));
      expect(dt2020, greaterThan(dt2000));
    });
  });

  group('dtT (ΔT 天)', () {
    test('J2000.0 时刻 (t=0) ≈ 63.87/86400 天', () {
      // t=0 对应 2000 年
      expect(dtT(0), closeTo(63.87 / 86400, 0.0001));
    });

    test('返回值单位是天', () {
      final dtDays = dtT(0);
      // 应该在 0.0005 ~ 0.001 天的量级 (约 40-90 秒)
      expect(dtDays, greaterThan(0.0005));
      expect(dtDays, lessThan(0.002));
    });
  });

  // ==================== nutation ====================

  group('nutation2 (章动)', () {
    test('J2000.0 时刻 (t=0) 章动值合理', () {
      final result = nutation2(0);
      // 黄经章动通常在 ±20" 以内 = ±20/206265 ≈ ±1e-4 弧度
      expect(result[0].abs(), lessThan(1e-3));
      // 交角章动通常在 ±10" 以内
      expect(result[1].abs(), lessThan(1e-3));
    });

    test('返回两个元素 [黄经章动, 交角章动]', () {
      final result = nutation2(0);
      expect(result.length, 2);
    });

    test('不同时刻值不同', () {
      final r1 = nutation2(0);
      final r2 = nutation2(1); // 1个世纪后
      // 章动是周期性的，不同时刻应该不同
      expect(r1[0], isNot(closeTo(r2[0], 1e-10)));
    });
  });

  group('nutationLon2 (黄经章动)', () {
    test('与 nutation2 的第一个分量一致', () {
      for (final t in [0.0, 0.5, -1.0, 2.0]) {
        final full = nutation2(t);
        final lonOnly = nutationLon2(t);
        expect(lonOnly, closeTo(full[0], 1e-15), reason: 't=$t 时黄经章动不一致');
      }
    });
  });

  group('hcjj (黄赤交角)', () {
    test('J2000.0 时刻 ≈ 23.4393°', () {
      final eps = hcjj(0);
      // 23.4393° = 23.4393 * π / 180
      expect(eps, closeTo(23.4393 * math.pi / 180, 0.001));
    });

    test('缓慢变化', () {
      final eps0 = hcjj(0);
      final eps1 = hcjj(1); // 100年后
      // 每世纪变化约 46.8"，即 ~0.013°
      final diffDegrees = (eps0 - eps1).abs() * 180 / math.pi;
      expect(diffDegrees, closeTo(0.013, 0.005));
    });
  });
}
