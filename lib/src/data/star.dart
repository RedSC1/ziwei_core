import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/enums/scope.dart';

import '../enums/star_enums.dart';

/// **抽象基星 (Abstract Star)**
///
/// 紫微斗数排盘系统中所有“星星”物体的顶层基类，无论是固定的主星还是游走的流曜，都继承于此。
abstract class Star {
  abstract final String key; // 唯一标识 (ziwei)
  abstract final StarType type; // 类型 (major/bad...)
  // 统一的构造/工厂
  const Star();

  /// 🚀 原型模式 (Prototype Pattern)深拷贝核心
  ///
  /// 用于在大限/流年排盘时深拷贝对象，防止流运状态污染原盘数据。
  Star clone();
}

/// **固态星曜 (Static Star)**
///
/// 包含紫微斗数中位置相对固定的原局星星（14主星 + 吉煞 + 杂曜）。
/// 它们的安星规则通常由 JSON 配置表直接加载决定。
class StaticStar extends Star {
  @override
  final String key;
  @override
  final StarType type;

  Map<ZiweiScope, SiHuaType> siHuaBuff;
  SiHuaType? selfSiHua;
  SiHuaType? centripetalSiHua;

  // 特有属性：安星规则 (因为流曜不需要这个，它们靠流年算)
  final StarRule rule;
  final List<int> brightnessTable;

  StaticStar({
    required this.key,
    required this.type,
    required this.rule,
    required this.brightnessTable,
    Map<ZiweiScope, SiHuaType>? siHuaBuff,
  }) : siHuaBuff = siHuaBuff ?? {};

  /// 🚀 深拷贝实现
  @override
  StaticStar clone() {
    return StaticStar(
        key: key,
        type: type,
        rule: rule, // Rule 是不可变配置，传引用即可
        brightnessTable: brightnessTable, // 只读表，传引用即可
        // 🔥 关键：Map 必须深拷贝！
        siHuaBuff: Map.of(siHuaBuff),
      )
      ..selfSiHua = selfSiHua
      ..centripetalSiHua = centripetalSiHua;
  }

  /// 获取静态星在指定宫底地支的亮度表现 (庙、旺、平、陷)
  ///
  /// - [branch]: 目标查询的宫位地支
  int getBrightness(DiZhi branch) {
    return brightnessTable[branch.index];
  }

  /// 引擎核心装载器：从预配置的数据字典里组装出这颗星星的实体
  ///
  /// - [json]: 加载自 `stars.json` 的单星星字典对象
  /// - [brightnessMap]: 加载自 `brightness.json` 的全局亮度映射表
  factory StaticStar.fromJson(
    Map<String, dynamic> json,
    Map<String, List<int>> brightnessMap,
  ) {
    if (!json.containsKey('key')) {
      throw FormatException(
        'Stars JSON error: Missing required field "key" in configuration. Raw data: $json',
      );
    }

    final String key = json['key'] as String;

    if (!json.containsKey('type')) {
      throw FormatException(
        'Stars JSON error: Star "$key" is missing the required field "type".',
      );
    }

    if (!json.containsKey('rule')) {
      throw FormatException(
        'Stars JSON error: Star "$key" is missing the placement "rule" object.',
      );
    }

    List<int> brightness = brightnessMap[key] ?? List.filled(12, 0);

    return StaticStar(
      key: key,
      type: StarType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => throw FormatException(
          'Stars JSON error: Star "$key" has an invalid type "${json['type']}". Valid types: ${StarType.values.map((e) => e.name).toList()}',
        ),
      ),
      rule: StarRule.fromJson(json['rule'] as Map<String, dynamic>),
      brightnessTable: brightness,
    );
  }
}

/// **流星星曜 (Flow Star)**
///
/// 流曜属于根据时间和大限动态游走的星星，比如常见的：流年禄存、流年羊陀、流年魁钺...
/// 特点：位置岁时间流动，同样享受亮度属性加持
class FlowStar extends Star {
  @override
  final String key; // "flow_year_lucun"
  @override
  final StarType type = StarType.flow; // 新增一个 flow 类型

  // 新增 scope 字段，方便后续逻辑判断
  final ZiweiScope scope;

  // 流曜也是有庙旺平陷的，通过 JSON 数据（如 flow_stars.json）独立配置并初始化
  final List<int> brightnessTable;

  FlowStar({
    required this.key,
    required this.brightnessTable,
    required this.scope,
  });

  /// 获取流曜在指定宫底地支的亮度表现
  ///
  /// 💡 流曜同样拥有自己独立配置的 `brightnessTable`，通常在 `flow_stars.json` 中定义。
  ///
  /// - [branch] 目标查询的宫位地支
  int getBrightness(DiZhi branch) {
    return brightnessTable[branch.index];
  }

  @override
  FlowStar clone() {
    return FlowStar(key: key, brightnessTable: brightnessTable, scope: scope);
  }
}
