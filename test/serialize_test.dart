import 'dart:convert';
import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

void main() {
  group('JSON Serialization Tests', () {
    late ZiweiRuleset ruleset;

    setUpAll(() async {
      // 通过 Loader 拉取完整的配置环境
      ruleset = ConfigLoader.getDefault();
    });

    test('Serialize a ZiWeiPlate with full depth', () {
      // 1. 初始化一个测试用的盘 (2000-01-01 12:00:00 男)
      final dt = DateTime(2000, 1, 1, 12, 0, 0);
      final zDate = ZiweiDate.fromSolar(dt, gender: Gender.male);
      final plate = ZiweiEngine.calculate(zDate, ruleset);

      // 2. 调用根节点 toJson()
      final jsonMap = plate.toJson();

      // 3. 基础校验元数据
      expect(jsonMap, isNotNull);
      expect(jsonMap['meta'], isNotNull);
      expect(jsonMap['meta']['element_bureau'], isNotNull);

      // 4. 校验日期模块
      expect(jsonMap['date'], isNotNull);
      expect(jsonMap['date']['bazi']['year'], isNotNull);

      // 5. 校验宫位列表
      final palaces = jsonMap['palaces'] as List;
      expect(palaces.length, 12);

      // 6. 取出一个宫位深入探查
      final firstPalace = palaces[0] as Map<String, dynamic>;
      expect(firstPalace['index'], 0);
      expect(firstPalace['branch'], 'zi');
      expect(firstPalace.containsKey('stem'), true);

      // 7. 校验星曜序列化形态
      if (firstPalace.containsKey('stars')) {
        final starsTypeMap = firstPalace['stars'] as Map<String, dynamic>;

        // 我们知道宫里必定至少有 major/minor 等类别的星星存在
        expect(starsTypeMap.isNotEmpty, true);

        // 抓取第一颗星曜探测
        final firstList = starsTypeMap.values.first as List;
        if (firstList.isNotEmpty) {
          final firstStar = firstList.first as Map<String, dynamic>;
          expect(firstStar['key'], isA<String>());
          expect(firstStar['type'], isA<String>());

          // 如果该星曜配有亮度则一定不带中文，全是 i18n tag
          if (firstStar.containsKey('brightness')) {
            expect(firstStar['brightness'], isA<String>());
            expect(firstStar['brightness'], isNot(contains('庙')));
          }
        }
      }

      // 控制台直观感受下输出
      print(JsonEncoder.withIndent('  ').convert(jsonMap));
    });

    test('Serialize Context with time travels', () {
      final dt = DateTime(2000, 1, 1, 12, 0, 0);
      final zDate = ZiweiDate.fromSolar(dt, gender: Gender.female);
      final plate = ZiweiEngine.calculate(zDate, ruleset);

      // 1. 发动机：跳跃至 2026年 5月 (带出四柱全状态切片)
      // 注意：真实求流日求流时的干支需要借助更复杂的万年历，
      // 这里为了简测序列化结构，仅跳转到流年和流月，看看 toJson 表现即可
      final context = TimeMachine.travel(plate, year: 2026, month: 5);

      final jsonMap = context.toJson();

      expect(jsonMap.containsKey('decade'), true);
      expect(jsonMap.containsKey('small_limit'), true);
      expect(jsonMap.containsKey('flow_year'), true);
      expect(jsonMap.containsKey('flow_month'), true);
      expect(jsonMap.containsKey('flow_day'), false);

      expect(jsonMap['flow_year']['year'], 2026);
      expect(jsonMap['flow_month']['month'], 5);
    });
  });
}
