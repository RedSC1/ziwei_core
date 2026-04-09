import 'dart:math';
import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

void main() {
  group('ZiweiReverseLookup Tier 1', () {
    late ZiweiRuleset ruleset;

    setUp(() {
      ruleset = ConfigLoader.getDefault();
    });

    /// 用已知日期正向排盘 → 提取星曜位置 → 反查 → 验证
    test('roundtrip: known birth date → star positions → reverse lookup', () {
      // 已知: 1990-08-15 12:00 (午时), 农历庚午年六月廿五
      final date = ZiweiDate.fromSolar(
        AstroDateTime(1990, 8, 15, 12, 0, 0),
        options: ruleset.calendarOptions,
      );

      final plate = ZiweiEngine.calculate(date, ruleset);

      // 从盘面提取 Tier 1 星曜位置
      int? lucunIdx, hongluanIdx, zuofuIdx, wenchangIdx, santaiIdx;

      for (final palace in plate.palaces) {
        for (final stars in palace.stars.values) {
          for (final star in stars) {
            if (star.key == 'lucun') lucunIdx = palace.index;
            if (star.key == 'hongluan') hongluanIdx = palace.index;
            if (star.key == 'zuofu') zuofuIdx = palace.index;
            if (star.key == 'wenchang') wenchangIdx = palace.index;
            if (star.key == 'santai') santaiIdx = palace.index;
          }
        }
      }

      expect(lucunIdx, isNotNull, reason: '禄存必须存在');
      expect(hongluanIdx, isNotNull, reason: '红鸾必须存在');
      expect(zuofuIdx, isNotNull, reason: '左辅必须存在');
      expect(wenchangIdx, isNotNull, reason: '文昌必须存在');
      expect(santaiIdx, isNotNull, reason: '三台必须存在');

      // 反查
      final results = ZiweiReverseLookup.searchTier1(
        ZiweiTier1Query(
          lucunIndex: lucunIdx,
          hongluanIndex: hongluanIdx,
          zuofuIndex: zuofuIdx,
          wenchangIndex: wenchangIdx,
          santaiIndex: santaiIdx,
          startDate: AstroDateTime(1990, 1, 1),
          endDate: AstroDateTime(1990, 12, 31),
          ruleset: ruleset,
        ),
      );

      expect(results.isNotEmpty, true, reason: '应该至少有一个结果');

      // 验证: 原始日期必须在结果中
      final match = results.where((c) =>
        c.plate.originMingIndex == plate.originMingIndex &&
        c.plate.elementBureau == plate.elementBureau
      );
      expect(match.isNotEmpty, true, reason: '应该找到匹配原始盘面的候选');
    });

    test('left+right verify month consistency', () {
      // 左辅和右弼应该给出相同的月份
      final date = ZiweiDate.fromSolar(
        AstroDateTime(2000, 6, 15, 14, 0, 0),
        options: ruleset.calendarOptions,
      );
      final plate = ZiweiEngine.calculate(date, ruleset);

      int? zuofuIdx, youbiIdx;
      for (final palace in plate.palaces) {
        for (final stars in palace.stars.values) {
          for (final star in stars) {
            if (star.key == 'zuofu') zuofuIdx = palace.index;
            if (star.key == 'youbi') youbiIdx = palace.index;
          }
        }
      }

      // 左辅: month = fixIndex(zuofu - 4) + 1
      final monthFromZuoFu = ZiweiConsts.fixIndex(zuofuIdx! - 4) + 1;
      // 右弼: month = fixIndex(10 - youbi) + 1
      final monthFromYouBi = ZiweiConsts.fixIndex(10 - youbiIdx!) + 1;

      expect(monthFromZuoFu, monthFromYouBi, reason: '左辅和右弼应反推出相同的月份');
    });

    test('wenchang+wenqu verify hour consistency', () {
      final date = ZiweiDate.fromSolar(
        AstroDateTime(1985, 3, 20, 8, 30, 0),
        options: ruleset.calendarOptions,
      );
      final plate = ZiweiEngine.calculate(date, ruleset);

      int? wenchangIdx, wenquIdx;
      for (final palace in plate.palaces) {
        for (final stars in palace.stars.values) {
          for (final star in stars) {
            if (star.key == 'wenchang') wenchangIdx = palace.index;
            if (star.key == 'wenqu') wenquIdx = palace.index;
          }
        }
      }

      final hourFromWenChang = ZiweiConsts.fixIndex(10 - wenchangIdx!);
      final hourFromWenQu = ZiweiConsts.fixIndex(wenquIdx! - 4);

      expect(hourFromWenChang, hourFromWenQu, reason: '文昌和文曲应反推出相同的时辰');
      expect(hourFromWenChang, date.timeIndex, reason: '反推时辰应与原始一致');
    });

    /// 从盘面提取指定星曜的宫位索引
    int? _findStar(ZiWeiPlate plate, String key) {
      for (final palace in plate.palaces) {
        for (final stars in palace.stars.values) {
          for (final star in stars) {
            if (star.key == key) return palace.index;
          }
        }
      }
      return null;
    }

    test('random roundtrip: 100 random dates all find themselves back', () {
      final rng = Random(42); // 固定种子，可复现
      const tier1Keys = ['lucun', 'hongluan', 'zuofu', 'wenchang', 'santai'];
      var passed = 0;

      for (var i = 0; i < 100; i++) {
        // 随机生成 1940-2030 之间的日期时间
        final year = 1940 + rng.nextInt(91);
        final month = 1 + rng.nextInt(12);
        final day = 1 + rng.nextInt(28); // 安全起见最大28
        final hour = rng.nextInt(24);

        final date = ZiweiDate.fromSolar(
          AstroDateTime(year, month, day, hour, 0, 0),
          options: ruleset.calendarOptions,
        );
        final plate = ZiweiEngine.calculate(date, ruleset);

        // 提取 Tier 1 星曜
        final indices = <String, int>{};
        for (final key in tier1Keys) {
          final idx = _findStar(plate, key);
          if (idx == null) continue;
          indices[key] = idx;
        }

        if (indices.length < tier1Keys.length) continue; // 跳过缺失星的盘

        // 反查
        final results = ZiweiReverseLookup.searchTier1(
          ZiweiTier1Query(
            lucunIndex: indices['lucun'],
            hongluanIndex: indices['hongluan'],
            zuofuIndex: indices['zuofu'],
            wenchangIndex: indices['wenchang'],
            santaiIndex: indices['santai'],
            startDate: AstroDateTime(year, 1, 1),
            endDate: AstroDateTime(year, 12, 31),
            ruleset: ruleset,
          ),
        );

        // 验证: 原始盘面必须在结果中
        final found = results.any((c) =>
          c.plate.originMingIndex == plate.originMingIndex &&
          c.plate.elementBureau == plate.elementBureau &&
          c.hourIndex == date.timeIndex
        );

        expect(found, true,
          reason: '$year-$month-$day ${hour}h (lunar ${date.lunar.month}/${date.lunar.day} '
            '时辰${date.timeIndex}) 反查失败！得到 ${results.length} 个结果');
        passed++;
      }

      print('✅ $passed/100 随机日期反查全部通过');
    });
  });
}
