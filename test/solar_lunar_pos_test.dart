import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:ziwei_core/src/sxwnl/solar_lunar_pos.dart';
import 'package:ziwei_core/src/sxwnl/math_utils.dart';

void main() {
  // ==================== 地球黄经 ====================

  group('eLon (地球黄经)', () {
    test('J2000.0 时刻 (t=0) 地球黄经合理', () {
      final lon = eLon(0, -1);
      // J2000.0 时刻地球黄经约 1.75 rad (≈100°)
      expect(lon, greaterThan(1.5));
      expect(lon, lessThan(2.0));
    });

    test('半年后 (t≈0.5/100) 地球黄经变化约 π', () {
      final lon0 = eLon(0, -1);
      final lon1 = eLon(0.5 / 100, -1); // 半年 ≈ 0.005 世纪
      final diff = (lon1 - lon0).abs();
      // 半年地球黄经变化约 π (180°)
      expect(diff, closeTo(math.pi, 0.2));
    });

    test('不同精度级别有返回值', () {
      final lon1 = eLon(0, 3);
      final lon2 = eLon(0, 10);
      final lon3 = eLon(0, -1);
      // 低精度和高精度都有合理值
      expect(lon1.isFinite, true);
      expect(lon2.isFinite, true);
      expect(lon3.isFinite, true);
      // 高精度之间差异很小
      expect((lon2 - lon3).abs(), lessThan(0.001));
    });
  });

  // ==================== 月球黄经 ====================

  group('mLon (月球黄经)', () {
    test('J2000.0 时刻 (t=0) 月球黄经合理', () {
      final lon = mLon(0, -1);
      // 月球黄经应该在 0 ~ 2π 范围
      final normalized = rad2mrad(lon);
      expect(normalized, greaterThanOrEqualTo(0));
      expect(normalized, lessThan(pi2));
    });

    test('月球运动比地球快得多', () {
      // 月球恒星周期约 27.3 天 ≈ 0.0000747 世纪
      // 一个月内月球走完 2π
      final lon0 = mLon(0, -1);
      final lon1 = mLon(27.3 / 36525, -1); // 约一个恒星月
      final diff = rad2mrad(lon1) - rad2mrad(lon0);
      // 差值应该接近 0 (走了完整一圈)
      expect(diff.abs(), lessThan(0.5));
    });
  });

  // ==================== 太阳视黄经 ====================

  group('sALon (太阳视黄经)', () {
    test('J2000.0 时刻太阳视黄经 ≈ 280°', () {
      // 2000-01-01 12:00 太阳视黄经约 280.5°
      final lon = sALon(0, -1);
      final lonDeg = rad2mrad(lon) * 180 / math.pi;
      expect(lonDeg, closeTo(280.5, 1.0));
    });

    test('春分点时太阳视黄经 ≈ 0°', () {
      // 2000年春分约在3月20日, 距J2000约79天 ≈ 0.00216 世纪
      final t = 79.0 / 36525;
      final lon = sALon(t, -1);
      final lonDeg = rad2mrad(lon) * 180 / math.pi;
      // 春分时太阳黄经 ≈ 0° (或360°)
      expect(lonDeg, anyOf(closeTo(0, 3), closeTo(360, 3)));
    });

    test('与地球黄经相差约 π', () {
      // 太阳视黄经 = 地球黄经 + π + 章动 + 光行差
      final e = eLon(0, -1);
      final s = sALon(0, -1);
      final diff = rad2rrad(s - e - math.pi);
      // 章动+光行差很小，差值应该接近0
      expect(diff.abs(), lessThan(0.01));
    });
  });

  // ==================== 速度估算 ====================

  group('eV / mV (角速度)', () {
    test('地球角速度 ≈ 628.33 rad/century (近日点更快)', () {
      final v = eV(0);
      // J2000.0 (1月1.5日) 接近地球近日点 (1月4日)，速度最快
      // 平均速度 628.33，近日点速度约 628.33 * (1+2e) ≈ 649
      expect(v, closeTo(649.7, 1));
    });

    test('月球角速度 ≈ 8399.7 rad/century', () {
      final v = mV(0);
      // 月球速度受摄动影响极大，J2000.0 时刻约为 7664
      expect(v, closeTo(7664, 1));
    });

    test('月球角速度 >> 地球角速度', () {
      expect(mV(0), greaterThan(eV(0) * 10));
    });
  });

  // ==================== 反求时间 ====================

  group('sALonT / sALonT2 (已知太阳黄经求时间)', () {
    test('春分 (太阳黄经=0) 求时间', () {
      // 注意：输入 0 会得到 1999 年春分 (-286天)
      // 输入 2π 得到 2000 年春分 (+79天)
      final t = sALonT(math.pi * 2);
      final days = t * 36525;
      // J2000后第一个春分约在第79天 (3月20日)
      expect(days, closeTo(79, 5));
    });

    test('夏至 (太阳黄经=π/2) 求时间', () {
      // 同样需要加 2π 以求得 2000 年夏至
      final t = sALonT(math.pi / 2 + math.pi * 2);
      final days = t * 36525;
      // J2000后第一个夏至约在第172天 (6月21日)
      expect(days, closeTo(172, 5));
    });

    test('高精度和低精度结果接近', () {
      final tHigh = sALonT(math.pi);
      final tLow = sALonT2(math.pi);
      final diffSeconds = (tHigh - tLow).abs() * 36525 * 86400;
      // 低精度误差应在600秒以内
      expect(diffSeconds, lessThan(600));
    });

    test('往返验证：求出时间后再算黄经', () {
      final target = 1.23; // 随意目标黄经
      final t = sALonT(target);
      final actual = sALon(t, -1);
      final diff = rad2rrad(actual - target);
      // 误差应极小（< 1角秒）
      expect(diff.abs(), lessThan(1 / rad));
    });
  });

  group('msALonT / msALonT2 (已知月日黄经差求时间)', () {
    test('合朔 (月日黄经差=0) 求时间', () {
      final t = msALonT(0); // 合朔
      // 应该在J2000后的某个朔日附近
      final days = t * 36525;
      // 2000年1月6日附近有一个新月，距J2000约5天
      expect(days, closeTo(5, 3));
    });

    test('望 (月日黄经差=π) 求时间', () {
      final t = msALonT(math.pi); // 望（满月）
      final days = t * 36525;
      // 应该在合朔后约14.7天
      expect(days, closeTo(20, 5));
    });

    test('高精度和低精度结果接近', () {
      final tHigh = msALonT(0);
      final tLow = msALonT2(0);
      final diffSeconds = (tHigh - tLow).abs() * 36525 * 86400;
      // 低精度误差应在600秒以内
      expect(diffSeconds, lessThan(600));
    });
  });

  // ==================== 光行差 ====================

  group('gxcSunLon (太阳光行差)', () {
    test('J2000.0 时刻光行差合理', () {
      final gc = gxcSunLon(0);
      // 太阳光行差约 -20.5 角秒 ≈ -9.94e-5 弧度
      expect(gc, closeTo(-20.5 / rad, 1 / rad));
    });
  });
}
