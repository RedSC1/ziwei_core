/// 星曜类型
enum StarType {
  /// 14 主星 (紫微、天机...)
  major,

  /// 六吉星 (辅弼昌曲魁钺)
  lucky,

  /// 六煞星 (羊陀火铃空劫)
  bad,

  /// 四化星 (禄权科忌 - 或者是表示这颗星能四化)
  mutagen,

  /// 杂曜 (恩光天贵...)
  other,

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
        return StarRuleType.lookupOffset;
      // ... 以后加了别的再来补 ...
      default:
        // 如果遇到不认识的，最好报错或者给 unknown，看你的严厉程度
        print("⚠️ 警告：未知的安星规则类型: $str");
        return StarRuleType.unknown;
    }
  }
}
