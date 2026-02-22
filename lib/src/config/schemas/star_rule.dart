import 'package:ziwei_core/src/enums/config_enums.dart';

import '../../enums/star_enums.dart';

/// 安星规则基类
abstract class StarRule {
  final StarRuleType type;
  StarRule(this.type);

  // 工厂模式：根据 JSON 里的 "type" 字段，自动变成具体的规则对象
  factory StarRule.fromJson(Map<String, dynamic> json) {
    final type = StarRuleType.fromJson(json['type']);

    switch (type) {
      case StarRuleType.anchorOffset:
        return AnchorOffsetRule.fromJson(json);
      case StarRuleType.lookup:
        return LookupRule.fromJson(json);
      case StarRuleType.lookupOffset:
        return LookupShiftRule.fromJson(json);
      // 🔥新增规则
      case StarRuleType.pipeline:
        return PipelineRule.fromJson(json);
      case StarRuleType.constant:
        return ConstantRule.fromJson(json);
      default:
        throw UnimplementedError("未知的规则类型: $type");
    }
  }
}

/// 规则A：锚点偏移 (紫微系、天府系)
class AnchorOffsetRule extends StarRule {
  final String anchorKey;
  final int offset;
  final StarDirection direction;
  // ✅ 补上 Boundary 字段
  final Boundary boundary;

  AnchorOffsetRule({
    required this.anchorKey,
    required this.offset,
    this.direction = StarDirection.shun,
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
      direction: _parseDirection(json['direction']),
      boundary: boundary, // ✅ 赋值
    );
  }

  static StarDirection _parseDirection(dynamic input) {
    if (input is int) {
      return input == -1 ? StarDirection.ni : StarDirection.shun;
    } else if (input is String) {
      if (input == 'gender_shun_ni') return StarDirection.genderShunNi;
      if (input == 'ni') return StarDirection.ni;
    }
    return StarDirection.shun;
  }
}

/// 规则B：查表法 (禄存、魁钺)
class LookupRule extends StarRule {
  final String anchorKey; // 查谁？(year_stem)
  final Map<String, int> table; // 查表数据
  final Boundary boundary; // 按什么历法查？(lunar/solar)
  final int offset; // 查完还要偏移多少？(默认0)
  final StarDirection direction; // ✅ 新增：方向 (默认顺行)

  LookupRule({
    required this.anchorKey,
    required this.table,
    required this.boundary,
    this.offset = 0,
    this.direction = StarDirection.shun,
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
      direction: AnchorOffsetRule._parseDirection(json['direction']), // ✅ 解析方向
    );
  }
}

//规则C：查表后再计算+偏移
class LookupShiftRule extends StarRule {
  final String anchorKey; // 第一锚点 (查表用，比如 year_branch)
  final String shiftAnchorKey; // 第二锚点 (偏移用，比如 hour)
  final Map<String, int> table; // 查表数据
  final Boundary boundary; // 按什么历法查？
  final StarDirection direction; // 偏移方向 (1顺 -1逆)

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
      direction: AnchorOffsetRule._parseDirection(json['direction']),
    );
  }
}

//规则D直接偏移
class ConstantRule extends StarRule {
  final int value;

  ConstantRule({required this.value}) : super(StarRuleType.constant);

  factory ConstantRule.fromJson(Map<String, dynamic> json) {
    return ConstantRule(value: (json['value'] as num?)?.toInt() ?? 0);
  }
}

//规则E流水线规则，是ABCD类型的排列组合
class PipelineRule extends StarRule {
  final List<StarRule> steps; // 🔥 里面全是继承自 StarRule 的兄弟姐妹
  final Boundary boundary;

  PipelineRule({required this.steps, required this.boundary})
    : super(StarRuleType.pipeline);

  factory PipelineRule.fromJson(Map<String, dynamic> json) {
    final boundaryStr = json['boundary'] as String? ?? 'lunar';
    final boundary = Boundary.values.firstWhere(
      (e) => e.name == boundaryStr,
      orElse: () => Boundary.lunar,
    );

    // 🚀 神仙套娃：递归解析 steps 里的每一个规则
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    final parsedSteps = stepsJson.map((stepJson) {
      return StarRule.fromJson(stepJson as Map<String, dynamic>);
    }).toList();

    return PipelineRule(steps: parsedSteps, boundary: boundary);
  }
}
