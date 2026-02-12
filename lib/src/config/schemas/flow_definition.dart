import 'package:ziwei_core/src/config/schemas/star_rule.dart';

/// 流曜定义 (Flow Star Definition)
///
/// 对应 flow_stars.json 中的配置项。
/// 包含完整的安星规则 (Rule) 和亮度表 (Brightness)，完全独立于原局。
class FlowDefinition {
  final String key; // e.g. "flow_lucun" (作为唯一标识和 i18n key 的一部分)
  final StarRule rule; // 🔥 独立的安星规则
  final List<int> brightness; // 🔥 独立的亮度表

  const FlowDefinition({
    required this.key,
    required this.rule,
    required this.brightness,
  });

  factory FlowDefinition.fromJson(Map<String, dynamic> json) {
    // 1. 解析规则
    if (!json.containsKey('rule')) {
      throw FormatException("Flow star ${json['key']} missing 'rule'");
    }
    final rule = StarRule.fromJson(json['rule']);

    // 2. 解析亮度 (可选，如果没有则默认为平)
    List<int> brightnessTable = List.filled(12, 0);
    if (json.containsKey('brightness')) {
      brightnessTable = (json['brightness'] as List).cast<int>();
    }

    return FlowDefinition(
      key: json['key'] as String,
      rule: rule,
      brightness: brightnessTable,
    );
  }
}
