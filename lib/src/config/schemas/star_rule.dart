import 'package:ziwei_core/src/enums/config_enums.dart';

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
        return LookupRule.fromJson(json);
      case StarRuleType.lookupOffset:
        return LookupShiftRule.fromJson(json);
      default:
        throw UnimplementedError("未知的规则类型: $type");
    }
  }
}

/// 规则A：锚点偏移 (紫微系、天府系)
class AnchorOffsetRule extends StarRule {
  final String anchorKey;
  final int offset;
  final int direction;
  // ✅ 补上 Boundary 字段
  final Boundary boundary;

  AnchorOffsetRule({
    required this.anchorKey,
    required this.offset,
    this.direction = 1,
    this.boundary = Boundary.lunar, // 默认为农历
  }) : super(StarRuleType.anchorOffset);

  factory AnchorOffsetRule.fromJson(Map<String, dynamic> json) {
    // 解析 Boundary
    final boundaryStr = json['boundary'] as String? ?? 'lunar';
    final boundary = Boundary.values.firstWhere(
      (e) => e.name == boundaryStr,
      orElse: () => Boundary.lunar,
    );

    return AnchorOffsetRule(
      anchorKey: json['anchor'] as String,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      direction: (json['direction'] as num?)?.toInt() ?? 1,
      boundary: boundary, // ✅ 赋值
    );
  }
}

/// 规则B：查表法 (禄存、魁钺)
class LookupRule extends StarRule {
  final String anchorKey; // 查谁？(year_stem)
  final Map<String, int> table; // 查表数据
  final Boundary boundary; // 按什么历法查？(lunar/solar)
  final int offset; // 查完还要偏移多少？(默认0)

  LookupRule({
    required this.anchorKey,
    required this.table,
    required this.boundary,
    this.offset = 0,
  }) : super(StarRuleType.lookup);

  factory LookupRule.fromJson(Map<String, dynamic> json) {
    // 1. 转换 Table (从 dynamic 转 int)
    final rawTable = json['table'] as Map<String, dynamic>;
    final table = rawTable.map((k, v) => MapEntry(k, v as int));

    // 2. 解析 Boundary 枚举 (字符串 -> 枚举)
    final boundaryStr = json['boundary'] as String? ?? 'lunar';
    final boundary = Boundary.values.firstWhere(
      (e) => e.name == boundaryStr,
      orElse: () => Boundary.lunar,
    );

    return LookupRule(
      anchorKey: json['anchor'] as String, // 必填
      table: table,
      boundary: boundary,
      offset: (json['offset'] as int?) ?? 0, // 选填，默认0
    );
  }
}

//规则C：查表后再计算+偏移
class LookupShiftRule extends StarRule {
  final String anchorKey; // 第一锚点 (查表用，比如 year_branch)
  final String shiftAnchorKey; // 第二锚点 (偏移用，比如 hour)
  final Map<String, int> table; // 查表数据
  final Boundary boundary; // 按什么历法查？
  final int direction; // 偏移方向 (1顺 -1逆)

  LookupShiftRule({
    required this.anchorKey,
    required this.shiftAnchorKey,
    required this.table,
    required this.boundary,
    required this.direction,
  }) : super(StarRuleType.lookupOffset);

  factory LookupShiftRule.fromJson(Map<String, dynamic> json) {
    // 1. 安全转换 Table
    final rawTable = json['table'] as Map<String, dynamic>;
    final table = rawTable.map((k, v) => MapEntry(k, v as int));

    // 2. 解析 Boundary
    final boundaryStr = json['boundary'] as String? ?? 'lunar';
    final boundary = Boundary.values.firstWhere(
      (e) => e.name == boundaryStr,
      orElse: () => Boundary.lunar,
    );

    return LookupShiftRule(
      anchorKey: json['anchor'] as String,
      shiftAnchorKey: json['shift_anchor'] as String, // 必填
      table: table,
      boundary: boundary,
      direction: (json['direction'] as int?) ?? 1, // 默认顺行
    );
  }
}
