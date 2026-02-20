import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/core/logger.dart';
import 'package:ziwei_core/src/enums/config_enums.dart'; // import Gender
import 'package:ziwei_core/src/enums/consts.dart';
import 'package:ziwei_core/src/enums/star_enums.dart'; // 引入 StarDirection

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

  // Helper: 解析方向 (顺/逆/性别顺逆)
  static int _getDirectionMultiplier(
    StarDirection dir,
    RuleContext ctx,
    Boundary? boundary,
  ) {
    switch (dir) {
      case StarDirection.shun:
        return 1;
      case StarDirection.ni:
        return -1;
      case StarDirection.genderShunNi:
        // 1. 获取性别
        // Context passes gender as String name
        final genderStr = ctx['gender'] as String?;
        Gender? gender;
        if (genderStr != null) {
          // Find Gender enum from string
          try {
            gender = Gender.values.firstWhere((e) => e.name == genderStr);
          } catch (_) {}
        }

        if (gender == null) return 1; // 兜底顺行

        // 2. 获取当前上下文的年干 (用于定阴阳)
        // Resolve key based on boundary
        // Wait, _resolveKey logic handles key mappings.
        // We need 'year_stem' resolved to 'lunar_year_stem' or 'solar_year_stem'
        // based on boundary.
        // Let's resolve 'year_stem' manually correctly here.
        final stemKey = _resolveKey('year_stem', boundary);
        final stemName = ctx[stemKey] as String?;
        if (stemName == null) return 1;

        try {
          final stem = TianGan.fromName(stemName);
          final isYangStem = stem.index % 2 == 0; // 0=甲(Yang), 1=乙(Yin)

          // 3. 逻辑: 阳男阴女顺(1), 阴男阳女逆(-1)
          // 这里的 "阳男" 意思是 Gender=Male 且 Stem=Yang
          bool isShun =
              (gender == Gender.male && isYangStem) ||
              (gender == Gender.female && !isYangStem);
          return isShun ? 1 : -1;
        } catch (e) {
          ZiweiLogger.warn("Failed to parse stem for direction: $stemName");
          return 1;
        }
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

    // 3. 计算方向乘数
    int dirMult = _getDirectionMultiplier(rule.direction, ctx, rule.boundary);

    // 4. 计算
    // 🚑 紧急修复：区分“时间偏移”和“星曜偏移”
    // - 文昌(逆时辰): 从固定点(Offset) 逆数 时辰(Anchor) -> Result = Offset + (Anchor * Dir)
    // - 力士(逆星曜): 从星曜(Anchor) 逆数 固定点(Offset) -> Result = Anchor + (Offset * Dir)

    bool isTimeAnchor =
        realKey.contains("month") ||
        realKey.contains("hour") ||
        realKey.contains("day") ||
        realKey.contains("year_index");

    int rawIndex;
    if (isTimeAnchor) {
      // 时间作为变量(Shift)，Offset作为基准(Base)
      // Offset + (Val * Dir)
      rawIndex = rule.offset + (anchorVal * dirMult);
    } else {
      // 星曜作为基准(Base)，Offset作为变量(Shift)
      // Anchor + (Offset * Dir)
      rawIndex = anchorVal + (rule.offset * dirMult);
    }

    return ZiweiConsts.fixIndex(rawIndex);
  }

  static int _handleLookup(LookupRule rule, RuleContext ctx) {
    // Lookup 通常用 String (e.g. "jia"), 但也可能用 int (e.g. hour index)
    final realKey = _resolveKey(rule.anchorKey, rule.boundary);

    final lookupKey = ctx[realKey];
    if (lookupKey == null) {
      return -1;
    }

    // Normalize key to string for lookup
    final keyStr = lookupKey.toString();

    // 查表
    if (rule.table.containsKey(keyStr)) {
      int baseIndex = rule.table[keyStr]!;

      // ✅ 关键修复：应用方向乘数 (这样 gender_shun_ni 才能生效)
      int dirMult = _getDirectionMultiplier(rule.direction, ctx, rule.boundary);

      // 计算: base + (offset * direction)
      return ZiweiConsts.fixIndex(baseIndex + (rule.offset * dirMult));
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

    final keyStr = lookupKey.toString();

    // 3. 查表得起点
    if (!rule.table.containsKey(keyStr)) {
      return -1;
    }
    int startIndex = rule.table[keyStr]!;

    // 4. 计算方向乘数
    int dirMult = _getDirectionMultiplier(rule.direction, ctx, rule.boundary);

    // 5. 计算
    return ZiweiConsts.fixIndex(startIndex + (shiftVal * dirMult));
  }
}
