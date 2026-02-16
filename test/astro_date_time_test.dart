import 'package:test/test.dart';
import 'package:sxwnl_spa_dart/src/astro_date_time.dart';
import 'package:sxwnl_spa_dart/src/location.dart';

void main() {
  group('Location', () {
    test('北京预设值', () {
      expect(Location.beijing.longitude, 116.4074);
      expect(Location.beijing.latitude, 39.9042);
    });

    test('自定义经纬度', () {
      final loc = Location(121.4737, 31.2304); // 上海
      expect(loc.longitude, 121.4737);
      expect(loc.latitude, 31.2304);
    });

    test('toString', () {
      expect(Location.beijing.toString(), 'Location(116.4074, 39.9042)');
    });
  });

  group('AstroDateTime 构造', () {
    test('基础构造 - 与 DateTime 签名一致', () {
      final dt = AstroDateTime(2003, 7, 29, 2, 36);
      expect(dt.year, 2003);
      expect(dt.month, 7);
      expect(dt.day, 29);
      expect(dt.hour, 2);
      expect(dt.minute, 36);
      expect(dt.second, 0);
    });

    test('默认参数', () {
      final dt = AstroDateTime(2000);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 0);
      expect(dt.minute, 0);
      expect(dt.second, 0);
    });

    test('公元前日期', () {
      final dt = AstroDateTime(-210, 3, 15, 14, 30, 0);
      expect(dt.year, -210);
      expect(dt.isBCE, true);
      expect(dt.bceYear, 211); // 天文纪年 -210 = 公元前211年
    });

    test('公元前1年 = 天文纪年0年', () {
      final dt = AstroDateTime(0, 1, 1);
      expect(dt.isBCE, true);
      expect(dt.bceYear, 1);
    });

    test('公元后日期 isBCE = false', () {
      final dt = AstroDateTime(2024, 6, 15);
      expect(dt.isBCE, false);
      expect(dt.bceYear, isNull);
    });
  });

  group('AstroDateTime ↔ DateTime 互转', () {
    test('fromDateTime', () {
      final dartDt = DateTime(2003, 7, 29, 2, 36, 15);
      final astro = AstroDateTime.fromDateTime(dartDt);
      expect(astro.year, 2003);
      expect(astro.month, 7);
      expect(astro.day, 29);
      expect(astro.hour, 2);
      expect(astro.minute, 36);
      expect(astro.second, 15);
    });

    test('toDateTime - 现代日期', () {
      final astro = AstroDateTime(2024, 1, 15, 8, 30, 0);
      final dartDt = astro.toDateTime();
      expect(dartDt, isNotNull);
      expect(dartDt!.year, 2024);
      expect(dartDt.month, 1);
      expect(dartDt.day, 15);
      expect(dartDt.hour, 8);
      expect(dartDt.minute, 30);
    });

    test('toDateTime - 公元前返回 null', () {
      final astro = AstroDateTime(-100, 6, 1);
      expect(astro.toDateTime(), isNull);
    });

    test('往返转换不丢失精度', () {
      final original = DateTime(1990, 12, 25, 23, 59, 59);
      final roundTrip = AstroDateTime.fromDateTime(original).toDateTime();
      expect(roundTrip, isNotNull);
      expect(roundTrip!.year, original.year);
      expect(roundTrip.month, original.month);
      expect(roundTrip.day, original.day);
      expect(roundTrip.hour, original.hour);
      expect(roundTrip.minute, original.minute);
      expect(roundTrip.second, original.second);
    });
  });

  group('AstroDateTime 儒略日转换', () {
    test('J2000.0 常量', () {
      expect(AstroDateTime.j2000, 2451545.0);
    });

    test('J2000.0 时刻: 2000-01-01 12:00', () {
      // J2000.0 = 2451545.0 = 2000年1月1日12时(正午) TT
      final dt = AstroDateTime(2000, 1, 1, 12, 0, 0);
      expect(dt.toJulianDay(), closeTo(2451545.0, 0.0001));
      expect(dt.toJ2000(), closeTo(0.0, 0.0001));
    });

    test('已知日期: 2000-01-01 00:00', () {
      final dt = AstroDateTime(2000, 1, 1, 0, 0, 0);
      // 2000-01-01 00:00 = JD 2451544.5
      expect(dt.toJulianDay(), closeTo(2451544.5, 0.0001));
    });

    test('已知日期: 1582-10-15 (格里历起始)', () {
      final dt = AstroDateTime(1582, 10, 15, 0, 0, 0);
      // 1582-10-15 00:00 = JD 2299160.5
      expect(dt.toJulianDay(), closeTo(2299160.5, 0.0001));
    });

    test('已知日期: 1582-10-04 (儒略历最后一天)', () {
      final dt = AstroDateTime(1582, 10, 4, 0, 0, 0);
      // 1582-10-04 00:00 (儒略历) = JD 2299159.5
      // 注：格里历 1582-10-15 = JD 2299160.5，两者相差1天是正确的
      // （10月5日~14日在历史上被跳过了）
      expect(dt.toJulianDay(), closeTo(2299159.5, 0.0001));
    });

    test('公元前日期: -4712-01-01 12:00 (JD 起点)', () {
      // 天文纪年 -4712 = 公元前4713年
      // JD 0.0 = 公元前4713年1月1日格林尼治正午 (儒略历)
      final dt = AstroDateTime(-4712, 1, 1, 12, 0, 0);
      expect(dt.toJulianDay(), closeTo(0.0, 0.0001));
    });

    test('fromJulianDay 逆转换', () {
      final jd = 2451545.0; // J2000.0
      final dt = AstroDateTime.fromJulianDay(jd);
      expect(dt.year, 2000);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 12);
      expect(dt.minute, 0);
      expect(dt.second, 0);
    });

    test('fromJ2000 逆转换', () {
      final dt = AstroDateTime.fromJ2000(0.0);
      expect(dt.year, 2000);
      expect(dt.month, 1);
      expect(dt.day, 1);
      expect(dt.hour, 12);
    });

    test('往返转换: 现代日期', () {
      final original = AstroDateTime(2024, 6, 15, 14, 30, 0);
      final jd = original.toJulianDay();
      final restored = AstroDateTime.fromJulianDay(jd);
      expect(restored.year, original.year);
      expect(restored.month, original.month);
      expect(restored.day, original.day);
      expect(restored.hour, original.hour);
      expect(restored.minute, original.minute);
      expect(restored.second, original.second);
    });

    test('往返转换: 公元前日期', () {
      final original = AstroDateTime(-721, 2, 22, 6, 0, 0);
      final jd = original.toJulianDay();
      final restored = AstroDateTime.fromJulianDay(jd);
      expect(restored.year, original.year);
      expect(restored.month, original.month);
      expect(restored.day, original.day);
      expect(restored.hour, original.hour);
    });

    test('往返转换: 天文纪年0年', () {
      final original = AstroDateTime(0, 6, 15, 12, 0, 0);
      final jd = original.toJulianDay();
      final restored = AstroDateTime.fromJulianDay(jd);
      expect(restored.year, 0);
      expect(restored.month, 6);
      expect(restored.day, 15);
    });
  });

  group('AstroDateTime 运算', () {
    test('add - 加1小时 (现有代码的使用方式)', () {
      final dt = AstroDateTime(2024, 1, 1, 23, 30, 0);
      final result = dt.add(const Duration(hours: 1));
      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 2);
      expect(result.hour, 0);
      expect(result.minute, 30);
    });

    test('add - 跨月', () {
      final dt = AstroDateTime(2024, 1, 31, 23, 0, 0);
      final result = dt.add(const Duration(hours: 2));
      expect(result.month, 2);
      expect(result.day, 1);
    });

    test('subtract', () {
      final dt = AstroDateTime(2024, 1, 1, 0, 30, 0);
      final result = dt.subtract(const Duration(hours: 1));
      expect(result.year, 2023);
      expect(result.month, 12);
      expect(result.day, 31);
      expect(result.hour, 23);
      expect(result.minute, 30);
    });

    test('difference', () {
      final a = AstroDateTime(2024, 1, 1, 12, 0, 0);
      final b = AstroDateTime(2024, 1, 2, 12, 0, 0);
      final diff = b.difference(a);
      expect(diff.inHours, 24);
    });

    test('isAfter / isBefore', () {
      final a = AstroDateTime(2024, 1, 1);
      final b = AstroDateTime(2024, 1, 2);
      expect(b.isAfter(a), true);
      expect(a.isBefore(b), true);
      expect(a.isAfter(b), false);
    });
  });

  group('AstroDateTime weekday', () {
    test('2024-01-01 是星期一', () {
      final dt = AstroDateTime(2024, 1, 1);
      expect(dt.weekday, DateTime.monday); // 1
    });

    test('2024-01-07 是星期日', () {
      final dt = AstroDateTime(2024, 1, 7);
      expect(dt.weekday, DateTime.sunday); // 7
    });

    test('与 DateTime 一致', () {
      // 随便找几个日期对比
      for (final date in [
        [2003, 7, 29], // 测试文件中的生日
        [2026, 2, 11], // 测试文件中的日期
        [1990, 7, 29],
        [2000, 1, 1],
      ]) {
        final dartDt = DateTime(date[0], date[1], date[2]);
        final astroDt = AstroDateTime(date[0], date[1], date[2]);
        expect(
          astroDt.weekday,
          dartDt.weekday,
          reason: '${date[0]}-${date[1]}-${date[2]} weekday mismatch',
        );
      }
    });
  });

  group('AstroDateTime 相等性 / 排序', () {
    test('相等', () {
      final a = AstroDateTime(2024, 1, 1, 12, 0, 0);
      final b = AstroDateTime(2024, 1, 1, 12, 0, 0);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('不等', () {
      final a = AstroDateTime(2024, 1, 1, 12, 0, 0);
      final b = AstroDateTime(2024, 1, 1, 12, 0, 1);
      expect(a, isNot(equals(b)));
    });

    test('排序', () {
      final dates = [
        AstroDateTime(2024, 3, 1),
        AstroDateTime(2024, 1, 1),
        AstroDateTime(2024, 2, 1),
      ];
      dates.sort();
      expect(dates[0].month, 1);
      expect(dates[1].month, 2);
      expect(dates[2].month, 3);
    });
  });

  group('AstroDateTime toString', () {
    test('现代日期', () {
      final dt = AstroDateTime(2024, 1, 5, 8, 3, 7);
      expect(dt.toString(), '2024-01-05 08:03:07');
    });

    test('公元前日期', () {
      final dt = AstroDateTime(-210, 3, 15);
      expect(dt.toString(), '公元前211-03-15 00:00:00');
    });

    test('公元前1年 (天文纪年0年)', () {
      final dt = AstroDateTime(0, 6, 1);
      expect(dt.toString(), '公元前1-06-01 00:00:00');
    });
  });
}
