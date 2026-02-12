import 'package:test/test.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/time/astro_date_time.dart';
import 'package:ziwei_core/src/time/location.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

void main() {
  group('ZiweiDate 集成测试', () {
    test('现代日期: 2023-01-22 (癸卯年正月初一)', () {
      final dt = AstroDateTime(2023, 1, 22, 12, 0, 0); // 春节当天
      final date = ZiweiDate.fromSolar(dt);

      expect(date.lunar.year, 2023); // 2023年
      expect(date.lunar.month, 1); // 正月
      expect(date.lunar.day, 1); // 初一
      // 节气：立春(2月4日)前，年干支应该是壬寅？
      // 注意：农历年是癸卯，但八字年柱以立春为界。
      // 1月22日 < 2月4日，所以八字年柱还在 壬寅(2022)。
      expect(date.bazi.year.toString(), '壬寅');
    });

    test('现代日期: 2023-02-05 (立春后)', () {
      final dt = AstroDateTime(2023, 2, 5, 12, 0, 0);
      final date = ZiweiDate.fromSolar(dt);
      expect(date.bazi.year.toString(), '癸卯'); // 换年了
    });

    test('闰月: 2023-03-22 (闰二月初一)', () {
      final dt = AstroDateTime(2023, 3, 22, 12, 0, 0);
      final date = ZiweiDate.fromSolar(dt);

      expect(date.lunar.month, 2);
      expect(date.lunar.isLeap, true);
      expect(date.lunar.day, 1);
    });

    test('从农历构造: 2023年闰二月初一', () {
      final date = ZiweiDate.fromLunar(2023, 2, 1, 6, true); // 6=午时
      expect(date.solar.year, 2023);
      expect(date.solar.month, 3);
      expect(date.solar.day, 22);
      expect(date.lunar.isLeap, true);
    });

    test('公元前: BC 221 (秦始皇统一)', () {
      final dt = AstroDateTime(-220, 10, 1, 12, 0, 0);
      final date = ZiweiDate.fromSolar(dt);

      // 只要不报错，且能算出干支
      expect(date.bazi.day.toString().length, 2);
      expect(date.lunar.year, -220); // 应该大致对应
    });

    test('真太阳时生效', () {
      // 乌鲁木齐 (87.6°) vs 北京 (116.4°)
      // 经度差约 -29° ≈ -2小时
      // 北京时间 12:00 -> 乌鲁木齐真太阳时 ≈ 10:00 (巳时)
      // 北京真太阳时 ≈ 12:00 (午时)

      final dt = AstroDateTime(2023, 6, 1, 12, 0, 0);

      final dateBeijing = ZiweiDate.fromSolar(dt, location: Location.beijing);
      final dateUrumqi = ZiweiDate.fromSolar(
        dt,
        location: Location(87.6, 43.8),
      );

      expect(dateBeijing.bazi.time.toString(), contains('午'));
      expect(dateUrumqi.bazi.time.toString(), contains('巳'));
    });
  });
}
