import 'dart:convert';
import 'package:ziwei_core/src/config/schemas/flow_definition.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';

import '../time/ziwei_date.dart';
import '../enums/config_enums.dart';
import '../core/logger.dart';
import '../core/star_locator.dart'; // 引入 StarLocator

class ConfigLoader {
  static List<StaticStar> stars = [];
  static List<FlowDefinition> flowDefinitions = []; // 🔥 新增：流曜定义缓存

  static Map<int, String> brightnessLabels = {};

  static Map<TianGan, Map<SiHuaType, String>> siHuaRules = {};

  static CalendarOptions parse(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      throw ArgumentError('JSON string cannot be null or empty');
    }

    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Root must be a JSON object');
    }

    if (decoded.containsKey('brightness_labels')) {
      final Map<String, dynamic> labels = decoded['brightness_labels'];

      brightnessLabels.clear(); // Clear old data
      labels.forEach((k, v) {
        if (int.tryParse(k) != null) {
          brightnessLabels[int.parse(k)] = v.toString();
        }
      });
      ZiweiLogger.info("Loaded ${brightnessLabels.length} brightness levels");
    }
    // 1. Get Calendar node
    final calMap = _requireMap(decoded, 'calendar');

    // 2. 拿配置项
    final splitRat = _requireBool(calMap, 'split_rat_hour');

    // 3. 解析枚举
    final leapStr = _requireString(calMap, 'leap_month_strategy');
    final leapRule = _parseLeapRule(leapStr);

    // 4. 解析五虎遁按照农历（默认）还是节气
    final wuHuStr = _requireString(calMap, 'wu_hu_dun_boundary');
    final wuHuBoundary = _parseBoundary(wuHuStr, 'wu_hu_dun_boundary');

    // 5. 解析四化按照农历（默认）还是节气
    final siHuaStr = _requireString(calMap, 'sihua_boundary');
    final siHuaBoundary = _parseBoundary(siHuaStr, 'sihua_boundary');

    //6.解析童限的计算规则
    final childhoodStr = _requireString(calMap, 'childhood_decade');
    final childhoodDecadeRule = _parseChildhoodDecadeRule(childhoodStr);

    //大运流年流月按照阴历还是农历
    final flowLimitstr = _requireString(calMap, 'flowLimit_boundary');
    final flowLimitBoundary = _parseBoundary(
      flowLimitstr,
      'flowLimit_boundary',
    );

    // 是否启用特殊历法（建子月/建丑月等历史历法调整）
    final enableHistorical = _requireBool(calMap, 'enable_historical');

    return CalendarOptions(
      splitRatHour: splitRat,
      leapRule: leapRule,
      wuHuDunBasedOn: wuHuBoundary,
      siHuaBasedOn: siHuaBoundary,
      childhoodRule: childhoodDecadeRule,
      flowLimitBasedOn: flowLimitBoundary,
      enableHistorical: enableHistorical,
    );
  }

  static Map<String, dynamic> _requireMap(
    Map<String, dynamic> map,
    String key,
  ) {
    if (!map.containsKey(key)) throw ArgumentError('❌ Missing field: $key');
    final val = map[key];
    if (val is! Map<String, dynamic>) {
      throw ArgumentError('field "$key" must be Object');
    }
    return val;
  }

  static bool _requireBool(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) throw ArgumentError('❌ Missing field: $key');
    final val = map[key];
    if (val is! bool) throw ArgumentError('field "$key" must be bool');
    return val;
  }

  static String _requireString(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) throw ArgumentError('❌ Missing field: $key');
    final val = map[key];
    if (val is! String) throw ArgumentError('field "$key" must be String');
    return val;
  }

  static LeapMonthRule _parseLeapRule(String str) {
    switch (str) {
      case 'split':
        return LeapMonthRule.splitAt15;
      case 'current':
        return LeapMonthRule.asPrevious;
      case 'as_next':
        return LeapMonthRule.asNext;
      default:
        throw ArgumentError('❌ Invalid leap strategy: $str');
    }
  }

  static Boundary _parseBoundary(String str, String fieldName) {
    switch (str) {
      case 'lunar':
        return Boundary.lunar;
      case 'solar':
        return Boundary.solar;
      default:
        throw ArgumentError('Invalid $fieldName: $str');
    }
  }

  //解析童限规则
  static ChildhoodRole _parseChildhoodDecadeRule(String childhoodStr) {
    switch (childhoodStr) {
      case 'skip':
        return ChildhoodRole.skip;
      case 'regular':
        return ChildhoodRole.regular;
      default:
        throw ArgumentError('❌ Invalid childhood_decade: $childhoodStr');
    }
  }

  //以下是解析stars.json的代码
  // ✅ Parse stars list
  // ✅ New param: brightnessJson
  static void parseStars(String starsJson, String brightnessJson) {
    // 1. Parse brightness map first (for fast lookup)
    Map<String, List<int>> brightnessMap = {};
    try {
      if (brightnessJson.isNotEmpty) {
        final Map<String, dynamic> rawMap = jsonDecode(brightnessJson);
        // Cast dynamic to List<int>
        rawMap.forEach((key, value) {
          if (value is List) {
            brightnessMap[key] = value.cast<int>();
          }
        });
      }
    } catch (e) {
      ZiweiLogger.warn(
        "Brightness table parsing failed (will use defaults)",
        e,
      );
    }

    // 2. Parse stars and inject brightness data
    if (starsJson.trim().isEmpty) {
      stars = [];
      return;
    }

    try {
      final List<dynamic> list = jsonDecode(starsJson);

      // 🔥 Critical: Pass brightnessMap to fromJson
      stars = list.map((e) {
        return StaticStar.fromJson(e, brightnessMap);
      }).toList();

      ZiweiLogger.info("Loaded ${stars.length} stars (with brightness data)");

      // 🔥 初始化 StarLocator 规则缓存
      StarLocator.init(stars);
    } catch (e, s) {
      ZiweiLogger.error("Stars parsing failed", e, s);
      stars = [];
      throw FormatException("Stars JSON error: $e");
    }
  }

  // ✅ 解析四化规则 (rules_sihua.json)
  static void parseSiHua(String jsonStr) {
    if (jsonStr.trim().isEmpty) return;

    try {
      final Map<String, dynamic> raw = jsonDecode(jsonStr);
      siHuaRules.clear();

      raw.forEach((ganKey, rules) {
        // ganKey: "jia", "yi"...
        final gan = TianGan.fromName(ganKey);
        if (rules is Map<String, dynamic>) {
          final Map<SiHuaType, String> ruleMap = {};
          rules.forEach((sihuaKey, starKey) {
            // sihuaKey: "lu", "quan"...
            // ✅遇到未知类型直接抛异常，不再吞掉
            final type = SiHuaType.fromJson(sihuaKey);
            ruleMap[type] = starKey.toString();
          });
          siHuaRules[gan] = ruleMap;
        }
      });
      ZiweiLogger.info("Loaded SiHua rules for ${siHuaRules.length} stems");
    } catch (e, s) {
      ZiweiLogger.error("SiHua rules parsing failed", e, s);
    }
  }

  // ✅ 解析流曜定义 (flow_stars.json)
  static void parseFlowStars(String jsonStr) {
    if (jsonStr.trim().isEmpty) return;

    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      flowDefinitions = list.map((e) => FlowDefinition.fromJson(e)).toList();
      ZiweiLogger.info("Loaded ${flowDefinitions.length} flow definitions");
    } catch (e, s) {
      ZiweiLogger.error("Flow definitions parsing failed", e, s);
      flowDefinitions = [];
    }
  }
}
