import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';
import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

void main() {
  group('ConfigLoader Ruleset Overrides', () {
    test('getDefault() properly sets up base rules', () {
      final base = ConfigLoader.getDefault();
      expect(base.stars.isNotEmpty, true);
      expect(base.siHuaRules.isNotEmpty, true);
      expect(base.flowDefinitions.isNotEmpty, true);
      expect(base.brightnessLabels.isNotEmpty, true);
      expect(base.calendarOptions.splitRatHour, isNotNull);
    });

    test('overrideWith() merges custom Sihua cleanly without affecting base', () {
      final base = ConfigLoader.getDefault();

      // We will override ONLY the 'jia' (甲干) rules.
      final customSihuaJson = '''
      {
        "jia": {
          "lu": "ziwei",
          "quan": "tianji",
          "ke": "wqu",
          "ji": "yang"
        }
      }
      ''';

      final customRules = ConfigLoader.overrideWith(
        base,
        sihuaJson: customSihuaJson,
      );

      final customJiaLu = customRules.siHuaRules[TianGan.jia]![SiHuaType.lu];
      expect(customJiaLu, 'ziwei');

      // Verify that other Gan (e.g. Yi Gan) is NOT missing in custom (because we now deep-merge).
      // This is a deep merge operation now.
      expect(customRules.siHuaRules.containsKey(TianGan.yi), true);

      // Verify other unchanged components (stars, calendarOptions) are structurally identical
      expect(customRules.stars, base.stars);
      expect(customRules.calendarOptions, base.calendarOptions);
    });

    test('calculate plate with custom rules works expectedly', () {
      final customSihuaJson = '''
        {
          "jia": {
            "lu": "ziwei",
            "quan": "tianji",
            "ke": "txia",
            "ji": "yang"
          }
        }
        ''';
      final base = ConfigLoader.getDefault();
      final testRules = ConfigLoader.overrideWith(
        base,
        sihuaJson: customSihuaJson,
      );

      final date = ZiweiDate.fromSolar(
        AstroDateTime(2004, 8, 1, 12, 0), // 甲申年 -> 对应甲干四化
        gender: Gender.male,
        options: testRules.calendarOptions,
      );

      final plate = ZiweiEngine.calculate(date, testRules);

      int? starIndex;
      for (int i = 0; i < 12; i++) {
        final stars = plate.palaces[i].allStars;
        if (stars.any((s) => s.key == 'ziwei')) {
          starIndex = i;
          break;
        }
      }

      expect(starIndex != null, true, reason: 'Could not find ziwei star');

      final targetStar =
          plate.palaces[starIndex!].allStars.firstWhere((s) => s.key == 'ziwei')
              as StaticStar;

      expect(
        targetStar.siHuaBuff[ZiweiScope.origin],
        SiHuaType.lu,
        reason: 'Ziwei did not have Lu',
      );
    });

    test(
      'overrideWith() smart patches a single star definition without losing others',
      () {
        final base = ConfigLoader.getDefault();

        // We will override ONLY the 'ziwei' star's start branch rule, setting it to always be 'zi' for testing.
        final customStarsJson = '''
      [
        {
          "key": "ziwei",
          "type": "major",
          "rule": {
             "type": "constant",
             "value": 0
          }
        }
      ]
      ''';

        final customRules = ConfigLoader.overrideWith(
          base,
          starsJson: customStarsJson,
        );

        // Verify that the total number of stars is exactly the same as base (nothing was deleted)
        expect(customRules.stars.length, base.stars.length);

        // Verify that 'ziwei' was updated
        final customZiwei = customRules.stars.firstWhere(
          (s) => s.key == 'ziwei',
        );
        expect(customZiwei.rule is ConstantRule, true);

        // Verify that another star (e.g. 'tianji') wasn't touched
        final customTianji = customRules.stars.firstWhere(
          (s) => s.key == 'tianji',
        );
        final baseTianji = base.stars.firstWhere((s) => s.key == 'tianji');
        expect(customTianji.rule.type, baseTianji.rule.type);
      },
    );
  });
}
