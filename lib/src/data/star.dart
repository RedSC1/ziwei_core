import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';

import '../enums/star_enums.dart';

/// 1. 抽象基类
abstract class Star {
  abstract final String key; // 唯一标识 (ziwei)
  abstract final StarType type; // 类型 (major/bad...)
  // 统一的构造/工厂
  const Star();
}

/// 2. 普通静态星 (14主星 + 吉煞 + 杂曜)
/// 这些星位置是固定的，也是 stars.json 里配的那些
class StaticStar extends Star {
  @override
  final String key;
  @override
  final StarType type;

  // 特有属性：安星规则 (因为流曜不需要这个，它们靠流年算)
  // 注意：这个 Rule 类型你得在 schemas 里定义好
  final StarRule rule;
  final List<int> brightnessTable;

  const StaticStar({
    required this.key,
    required this.type,
    required this.rule,
    required this.brightnessTable,
  });

  int getBrightness(DiZhi branch) {
    return brightnessTable[branch.index];
  }

  factory StaticStar.fromJson(
    Map<String, dynamic> json,
    Map<String, List<int>> brightnessMap,
  ) {
    String key = json['key'];
    List<int> brightness = brightnessMap[key] ?? List.filled(12, 0);
    return StaticStar(
      // 1. 基础字段可以直接拿
      key: json['key'] as String,

      // 2. 枚举转换 (假设你在 StarType 里写了 fromJson，或者用 firstWhere)
      // 如果没写 helper，这里可以临时手写：
      type: StarType.values.firstWhere((e) => e.name == json['type']),

      // 3. 规则对象递归解析
      rule: StarRule.fromJson(json['rule'] as Map<String, dynamic>),

      // 4. 列表强转 (List<dynamic> -> List<int>)
      brightnessTable: brightness,
    );
  }
}

/// 3. 十二神 (博士、长生...)
/// 它们是成组出现的，不需要 rule，只需要知道跟谁混
class GodStar extends Star {
  @override
  final String key;
  @override
  final StarType type; // StarType.god

  final String groupName; // "boshi_12"

  const GodStar({
    required this.key,
    required this.type,
    required this.groupName,
  });
}

// 流曜以后再加...
