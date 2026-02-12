import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/scope.dart';

import '../enums/star_enums.dart';

/// 1. 抽象基类
abstract class Star {
  abstract final String key; // 唯一标识 (ziwei)
  abstract final StarType type; // 类型 (major/bad...)
  // 统一的构造/工厂
  const Star();

  /// 核心：原型模式 (Prototype Pattern)
  /// 用于在大限/流年排盘时深拷贝对象，防止污染原盘数据
  Star clone();
}

/// 2. 普通静态星 (14主星 + 吉煞 + 杂曜)
/// 这些星位置是固定的，也是 stars.json 里配的那些
class StaticStar extends Star {
  @override
  final String key;
  @override
  final StarType type;

  Map<ZiweiScope, SiHuaType> siHuaBuff;
  SiHuaType? selfSiHua;
  SiHuaType? centripetalSiHua;

  // 特有属性：安星规则 (因为流曜不需要这个，它们靠流年算)
  // 注意：这个 Rule 类型你得在 schemas 里定义好
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

  @override
  GodStar clone() {
    // GodStar 目前属性都是 final 的，理论上不需要深拷贝
    // 但为了接口统一，还是返回一个新对象比较保险
    return GodStar(
      key: key,
      type: type,
      groupName: groupName,
    );
  }
}

/// 4. 流曜 (Flow Stars)
/// 比如：流年禄存、流年羊陀、流年魁钺
/// 特点：位置随时间变，但有亮度属性
class FlowStar extends Star {
  @override
  final String key; // "liu_lucun"
  @override
  final StarType type = StarType.flow; // 新增一个 flow 类型
  
  // 流曜也是有庙旺平陷的，直接复用原星的亮度表
  // 比如流羊的亮度表 = 原盘擎羊的亮度表
  final List<int> brightnessTable; 

  FlowStar({
    required this.key,
    required this.brightnessTable,
  });

  int getBrightness(DiZhi branch) {
    return brightnessTable[branch.index];
  }

  @override
  FlowStar clone() {
    return FlowStar(key: key, brightnessTable: brightnessTable);
  }
}

// 流曜以后再加...
