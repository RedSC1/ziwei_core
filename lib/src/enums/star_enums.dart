import 'package:ziwei_core/src/core/logger.dart';

/// 星曜类型
enum StarType {
  /// 14 主星 (紫微、天机...)
  major,

  /// 六吉星 (辅弼昌曲魁钺)
  lucky,

  /// 六煞星 (羊陀火铃空劫)
  bad,

  /// 乙级星 (红鸾、天喜、天刑、天姚...)
  minor,

  /// ---------------------------
  /// 丙级星 (杂曜/十二神)
  /// ---------------------------

  /// 博士十二神 (跟禄存)
  boshi12,

  /// 岁建十二神 (跟太岁)
  suijian12,

  ///将前十二神
  jiangqian12,

  /// 长生十二神 (跟五行局)
  changsheng12,

  /// 杂曜 (其他)
  other,

  //流曜
  flow,

  /// 默认兜底
  unknown;

  /// Helper: 从 JSON 字符串转枚举
  /// 比如 json写 "major" -> StarType.major
  static StarType fromJson(String str) {
    return StarType.values.firstWhere(
      (e) => e.name == str,
      orElse: () => StarType.unknown,
    );
  }
}

/// 安星规则类型 (对应 stars.json 里的 rule.type)
enum StarRuleType {
  /// 锚点偏移法 (Base + Offset)
  /// 比如：天机 = 紫微 - 1
  anchorOffset,

  /// 查表法 (Lookup)
  /// 比如：禄存 = 查年干表
  lookup,

  // 先看表再偏移
  lookupOffset,

  pipeline, // 🔥 新增：流水线大本营，专门搞三台八座这种需要组合的

  constant, // 🔥 新增：纯数字微调组件

  /// 默认/未知
  unknown;

  // Helper: String 转 Enum
  static StarRuleType fromJson(String str) {
    switch (str) {
      case 'anchor_offset':
        return StarRuleType.anchorOffset;
      case 'lookup':
        return StarRuleType.lookup;
      case 'lookup_offset':
      case 'lookup_shift':
        return StarRuleType.lookupOffset;

      case 'pipeline':
        return StarRuleType.pipeline;
      case 'constant':
        return StarRuleType.constant;

      default:
        ZiweiLogger.warn("⚠️ 警告：未知的安星规则类型: $str");
        return StarRuleType.unknown;
    }
  }
}

//四化类型
enum SiHuaType {
  lu, // 禄
  quan, // 权
  ke, // 科
  ji; // 忌

  static SiHuaType fromJson(String str) {
    switch (str) {
      case 'lu':
        return SiHuaType.lu;
      case 'quan':
        return SiHuaType.quan;
      case 'ke':
        return SiHuaType.ke;
      case 'ji':
        return SiHuaType.ji;
      default:
        throw ArgumentError('未知的四化类型: $str');
    }
  }
}

enum StarDirection { shun, ni, genderShunNi }
