import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/core/logger.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/consts.dart';

/// 规则上下文 (Rule Context)
///
/// 这是一个 Map 的包装器，用于传递计算星曜位置所需的所有参数。
/// 核心变更：不再硬编码 getter，而是作为“哑数据容器”，
/// 具体的 Key 选择逻辑 (Lunar vs Solar) 移交给 [StarLocator] 处理。
class RuleContext {
  final Map<String, dynamic> _data;

  RuleContext(this._data);

  /// 通用获取器
  dynamic operator [](String key) => _data[key];

  /// 检查是否包含某个 Key
  bool containsKey(String key) => _data.containsKey(key);

  // === 核心锚点 (Helpers for debugging/logging) ===
  int? get ziwei => _data['ziwei'] as int?;
  int? get tianfu => _data['tianfu'] as int?;
  int? get ming => _data['ming'] as int?;
  int? get body => _data['body'] as int?;
}

/// 星曜定位服务 (Star Locator Service)
///
/// 职责：
/// 1. 缓存 [StarRule]
/// 2. 解析 [Boundary] (农历/节气)
/// 3. 执行具体的定位算法 (Offset/Lookup)
class StarLocator {
  static final Map<String, StarRule> _rules = {};

  static void init(List<StaticStar> stars) {
    _rules.clear();
    for (var star in stars) {
      _rules[star.key] = star.rule;
    }
    ZiweiLogger.info("StarLocator initialized with ${_rules.length} rules.");
  }

  /// 核心计算方法 (通过 Key 查找缓存规则)
  static int locate(String starKey, RuleContext ctx) {
    final rule = _rules[starKey];
    if (rule == null) {
      return -1;
    }
    return locateByRule(rule, ctx);
  }

  /// 🔥 新增：直接根据规则对象计算 (用于流曜等动态规则)
  static int locateByRule(StarRule rule, RuleContext ctx) {
    try {
      // 1. 根据规则类型分发
      if (rule is AnchorOffsetRule) {
        return _handleAnchorOffset(rule, ctx);
      } else if (rule is LookupRule) {
        return _handleLookup(rule, ctx);
      } else if (rule is LookupShiftRule) {
        return _handleLookupShift(rule, ctx);
      } else {
        return -1;
      }
    } catch (e) {
      ZiweiLogger.error("Failed to locate by rule: $rule", e);
      return -1;
    }
  }

  // 🛠️ 智能 Key 映射器 (Smart Key Mapper)
  // 负责将 JSON 里的通用 Key (e.g. "year_stem")
  // 映射到 Context 里的具体 Key (e.g. "solar_year_stem" or "lunar_year_stem")
  static String _resolveKey(String rawKey, Boundary? boundary) {
    // 1. 如果明确指定了 Solar (节气盘)
    if (boundary == Boundary.solar) {
      switch (rawKey) {
        case "month":
          return "solar_month";
        case "day":
        case "day_number":
          return "solar_day";
        case "hour":
          return "solar_hour";
        case "year_stem":
          return "solar_year_stem";
        case "year_branch":
          return "solar_year_branch";
        case "month_stem":
          return "solar_month_stem";
        case "month_branch":
          return "solar_month_branch";
        case "year": // 年份索引
          return "solar_year_index";
        default:
          return rawKey;
      }
    }

    // 2. 如果明确指定 Lunar 或 Default (农历盘)
    // 默认情况 (boundary == null) 也走这里，因为大部分星星是农历星
    switch (rawKey) {
      case "month":
        // ⚠️ 农历安星核心逻辑：通常使用“有效月份”(处理过闰月规则的)
        return "effective_month";
      case "day":
      case "day_number":
        return "lunar_day";
      case "hour":
        return "lunar_hour";
      case "year_stem":
        return "lunar_year_stem";
      case "year_branch":
        return "lunar_year_branch";
      case "month_stem":
        return "lunar_month_stem";
      case "month_branch":
        return "lunar_month_branch";
      case "year":
        return "lunar_year_index";
      default:
        // 其他如 "ziwei", "ming", "tianfu" 保持原样
        return rawKey;
    }
  }

  // === 内部算法实现 ===

  static int _handleAnchorOffset(AnchorOffsetRule rule, RuleContext ctx) {
    // 1. 解析真实的 Key (e.g. "month" -> "effective_month")
    final realKey = _resolveKey(rule.anchorKey, rule.boundary);

    // 2. 从 Context 取值 (必须是 int)
    final anchorVal = ctx[realKey];
    if (anchorVal == null || anchorVal is! int) {
      // 允许 null，表示该规则在此 Context 下无效
      return -1;
    }

    // 3. 计算: offset + (anchor * direction)
    int rawIndex = rule.offset + (anchorVal * rule.direction);
    return ZiweiConsts.fixIndex(rawIndex);
  }

  static int _handleLookup(LookupRule rule, RuleContext ctx) {
    // Lookup 通常用 String (e.g. "jia"), 但也可能用 int (e.g. hour index)
    final realKey = _resolveKey(rule.anchorKey, rule.boundary);

    final lookupKey = ctx[realKey];
    if (lookupKey == null) {
      return -1;
    }

    // 查表
    if (rule.table.containsKey(lookupKey)) {
      int baseIndex = rule.table[lookupKey]!;
      return ZiweiConsts.fixIndex(baseIndex + rule.offset);
    }
    return -1;
  }

  static int _handleLookupShift(LookupShiftRule rule, RuleContext ctx) {
    // 1. 查表键
    final realLookupKey = _resolveKey(rule.anchorKey, rule.boundary);
    final lookupKey = ctx[realLookupKey]; // e.g. "jia" (String)

    // 2. 偏移键
    final realShiftKey = _resolveKey(rule.shiftAnchorKey, rule.boundary);
    final shiftVal = ctx[realShiftKey]; // e.g. hour index (int)

    if (lookupKey == null || shiftVal == null || shiftVal is! int) {
      return -1;
    }

    // 3. 查表得起点
    if (!rule.table.containsKey(lookupKey)) {
      return -1;
    }
    int startIndex = rule.table[lookupKey]!;

    // 4. 计算
    return ZiweiConsts.fixIndex(startIndex + (shiftVal * rule.direction));
  }
}
