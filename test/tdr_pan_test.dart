import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

void main() {
  group('天地人盘 (TDRpan) Tests', () {
    late ZiweiRuleset ruleset;
    late ZiweiDate date;

    setUpAll(() {
      ruleset = ConfigLoader.getDefault();
      // 2000-01-01 12:00 男
      date = ZiweiDate.fromSolar(DateTime(2000, 1, 1, 12, 0, 0), gender: Gender.male);
    });

    test('默认排天盘', () {
      final plate = ZiweiEngine.calculate(date, ruleset);
      expect(plate.tdrPan, TDRpan.tianPan);
    });

    test('天盘与显式传 tianPan 结果一致', () {
      final defaultPlate = ZiweiEngine.calculate(date, ruleset);
      final tianPlate = ZiweiEngine.calculate(date, ruleset, tdrPan: TDRpan.tianPan);

      expect(defaultPlate.originMingIndex, tianPlate.originMingIndex);
      expect(defaultPlate.bodyPalaceIndex, tianPlate.bodyPalaceIndex);
      expect(defaultPlate.elementBureau, tianPlate.elementBureau);
    });

    test('地盘：命宫移至身宫位置', () {
      final tianPlate = ZiweiEngine.calculate(date, ruleset);
      final diPlate = ZiweiEngine.calculate(date, ruleset, tdrPan: TDRpan.diPan);

      expect(diPlate.tdrPan, TDRpan.diPan);
      // 地盘命宫 == 天盘身宫
      expect(diPlate.originMingIndex, tianPlate.bodyPalaceIndex);
    });

    test('人盘：命宫为天盘命宫+2', () {
      final tianPlate = ZiweiEngine.calculate(date, ruleset);
      final renPlate = ZiweiEngine.calculate(date, ruleset, tdrPan: TDRpan.renPan);

      expect(renPlate.tdrPan, TDRpan.renPan);
      // 人盘命宫 == 天盘命宫顺数两位（福德宫）
      expect(renPlate.originMingIndex, (tianPlate.originMingIndex + 2) % 12);
      // 身宫不变
      expect(renPlate.bodyPalaceIndex, tianPlate.bodyPalaceIndex);
    });

    test('三盘五行局可能不同', () {
      final tianPlate = ZiweiEngine.calculate(date, ruleset);
      final diPlate = ZiweiEngine.calculate(date, ruleset, tdrPan: TDRpan.diPan);
      final renPlate = ZiweiEngine.calculate(date, ruleset, tdrPan: TDRpan.renPan);

      // 命宫位置不同，五行局可能不同（至少验证不报错）
      expect(tianPlate.elementBureau, isNotNull);
      expect(diPlate.elementBureau, isNotNull);
      expect(renPlate.elementBureau, isNotNull);
    });
  });
}
