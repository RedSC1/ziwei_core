import 'dart:io';
import 'package:test/test.dart';
import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/ziwei_core.dart'; // 引用统一出口
// 或者: import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';

void main() {
  group('ConfigLoader 集成测试', () {
    test('输出五虎遁结果', () {
      // 模拟一个配置对象
      const opts = CalendarOptions(wuHuDunBasedOn: Boundary.lunar);

      // 创建时间
      final date = ZiweiDate.fromSolar(
        DateTime(2003, 8, 28, 2, 58),
        options: opts,
      );
      ZiWeiPlate plate = ZiWeiEngine.calculate(date);
      print(plate.originMingIndex);
      print(plate.bodyPalaceIndex);
      for (var palace in plate.palaces) {
        print('${palace.stem?.label}${palace.branch.label}');
      }
      print(plate.elementBureau.label);
    });
  });
}
