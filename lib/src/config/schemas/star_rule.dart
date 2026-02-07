import '../../enums/star_enums.dart';

/// 安星规则基类
abstract class StarRule {
  final StarRuleType type;
  StarRule(this.type);

  // 工厂模式：根据 JSON 里的 "type" 字段，自动变成具体的规则对象
  factory StarRule.fromJson(Map<String, dynamic> json) {
    // 记得去 StarRuleType 里写好 fromJson 转换
    final type = StarRuleType.fromJson(json['type']);

    switch (type) {
      case StarRuleType.anchorOffset:
        return AnchorOffsetRule.fromJson(json);
      case StarRuleType.lookup:
      //return LookupRule.fromJson(json);
      default:
        throw UnimplementedError("未知的规则类型: $type");
    }
  }
}

/// 规则A：锚点偏移 (紫微系、天府系)
class AnchorOffsetRule extends StarRule {
  final String anchorKey; // "ANCHOR_ZIWEI"
  final int offset; // -1

  AnchorOffsetRule({required this.anchorKey, required this.offset})
    : super(StarRuleType.anchorOffset);

  factory AnchorOffsetRule.fromJson(Map<String, dynamic> json) {
    return AnchorOffsetRule(anchorKey: json['anchor'], offset: json['offset']);
  }
}

/// 规则B：查表法 (禄存、魁钺)
