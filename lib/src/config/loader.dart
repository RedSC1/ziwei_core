import 'dart:convert';
import 'package:ziwei_core/src/core/logger.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';

import 'package:ziwei_core/src/time/ziwei_date.dart'; // Import for CalendarOptions
import '../enums/config_enums.dart'; // Import enums locally
import 'schemas/flow_definition.dart';
import 'ruleset.dart';
import 'default_jsons.dart';

class MasterRule {
  final Boundary boundary;
  final Map<int, String> table;

  MasterRule(this.boundary, this.table);
}

class ConfigLoader {
  /// **获取系统内置的默认排盘规则集 (Default Ruleset)**
  ///
  /// 返回引擎打包时内建的这套星曜坐标、四化字典及流年流动设定。
  /// 对于常规排盘，开发者只需调用此方法即可。
  static ZiweiRuleset getDefault() {
    return createRuleset(
      starsJson: DefaultJsons.stars,
      brightnessJson: DefaultJsons.brightness,
      sihuaJson: DefaultJsons.sihua,
      flowJson: DefaultJsons.flowStars,
      mainRulesJson: DefaultJsons.mainRules,
      mastersJson: DefaultJsons.masters,
    );
  }

  /// **局部覆盖并派生自定义规则集 (Override Ruleset)**
  ///
  /// 这个方法是你能够介入引擎，改变星曜布星、四化等核心逻辑或文字显示的**唯一合法入口**。
  ///
  /// 💡 你只需要传入你**想改变的那一部分**的 JSON 字符串即可。引擎会自动用你的配置做热补丁覆盖，
  /// 对于那些你没有传的字段，它依然会沿用 `baseRuleset` 也就是系统原版的逻辑。这相当于做了一次 "Deep Merge"。
  ///
  /// - [baseRuleset] 基准规则集，通常传入 `ConfigLoader.getDefault()` 的结果
  /// - [starsJson] (可选) 新的安星规矩定义 `stars.json`
  /// - [brightnessJson] (可选) 新的各宫亮度定义 `brightness.json`
  /// - [sihuaJson] (可选) 新的四化演变规则 `sihua.json`
  /// - [flowJson] (可选) 新的流运规则定义 `flow_stars.json`
  /// - [mainRulesJson] (可选) 新的引擎整体历法运行配制 `main_rules.json`
  /// - [mastersJson] (可选) 新的命主身主起例配制 `masters.json`
  static ZiweiRuleset overrideWith(
    ZiweiRuleset baseRuleset, {
    String? starsJson,
    String? brightnessJson,
    String? sihuaJson,
    String? flowJson,
    String? mainRulesJson,
    String? mastersJson,
  }) {
    // 覆盖逻辑：如果有传入新的 JSON，则使用新 JSON 创建一份临时 ruleset；
    // 否则，沿用基准 baseRuleset 里的对象引用。
    // 这要求 createRuleset 内部逻辑进行分离，或者为了简便，我们可以通过提取局部方法来复用。

    // 由于原始的 createRuleset 是全量构建，为了简化，这里我们可以直接复用 createRuleset 的核心代码。
    // 但是要避免重复解析 baseRuleset 已经解析好的对象。

    // 1. Brightness
    Map<int, String> brightnessLabels = Map.from(baseRuleset.brightnessLabels);
    Map<String, List<int>> brightnessMap = {};
    if (brightnessJson != null && brightnessJson.isNotEmpty) {
      try {
        final Map<String, dynamic> rawMap = jsonDecode(brightnessJson);
        rawMap.forEach((key, value) {
          if (value is List) {
            brightnessMap[key] = value.cast<int>();
          } else if (int.tryParse(key) != null) {
            // It's a label overwrite
            brightnessLabels[int.parse(key)] = value.toString();
          }
        });
      } catch (e) {
        ZiweiLogger.warn("Brightness table parsing failed", e);
      }
    }

    // 2. Stars
    List<StaticStar> stars = List.from(baseRuleset.stars);
    if (starsJson != null && starsJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(starsJson);
        for (var e in list) {
          final newStar = StaticStar.fromJson(e, brightnessMap);
          final existingIndex = stars.indexWhere((s) => s.key == newStar.key);
          if (existingIndex >= 0) {
            stars[existingIndex] = newStar; // update
          } else {
            stars.add(newStar); // append
          }
        }
      } on FormatException catch (e) {
        throw FormatException("Failed to patch Stars config: ${e.message}");
      } catch (e, s) {
        ZiweiLogger.error("Stars parsing failed due to unexpected error", e, s);
        throw Exception("Stars JSON parsing syntax error: $e");
      }
    }

    // 3. Sihua
    Map<TianGan, Map<SiHuaType, String>> siHuaRules = baseRuleset.siHuaRules;
    if (sihuaJson != null && sihuaJson.isNotEmpty) {
      try {
        final Map<String, dynamic> raw = jsonDecode(sihuaJson);
        siHuaRules = Map.from(baseRuleset.siHuaRules); // copy base map
        raw.forEach((ganKey, rules) {
          final gan = TianGan.fromName(ganKey);
          if (rules is Map<String, dynamic>) {
            // merge into existing gan rules if any
            final Map<SiHuaType, String> ruleMap = Map.from(
              siHuaRules[gan] ?? {},
            );
            rules.forEach((sihuaKey, starKey) {
              final type = SiHuaType.fromJson(sihuaKey);
              ruleMap[type] = starKey.toString();
            });
            siHuaRules[gan] = ruleMap;
          }
        });
      } on FormatException catch (e) {
        throw FormatException("Failed to patch SiHua rules: ${e.message}");
      } catch (e, s) {
        ZiweiLogger.error(
          "SiHua rules parsing failed due to unexpected error",
          e,
          s,
        );
        throw Exception("SiHua JSON parsing syntax error: $e");
      }
    }

    // 4. Flow
    List<FlowDefinition> flowDefinitions = List.from(
      baseRuleset.flowDefinitions,
    );
    if (flowJson != null && flowJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(flowJson);
        for (var e in list) {
          final newFlow = FlowDefinition.fromJson(e);
          final existingIndex = flowDefinitions.indexWhere(
            (f) => f.key == newFlow.key,
          );
          if (existingIndex >= 0) {
            flowDefinitions[existingIndex] = newFlow; // update
          } else {
            flowDefinitions.add(newFlow); // append
          }
        }
      } on FormatException catch (e) {
        throw FormatException("Failed to patch Flow Definitions: ${e.message}");
      } catch (e, s) {
        ZiweiLogger.error(
          "Flow definitions parsing failed due to unexpected error",
          e,
          s,
        );
        throw Exception("Flow JSON parsing syntax error: $e");
      }
    }

    // 5. Calendar Options
    CalendarOptions calOptions = baseRuleset.calendarOptions;
    if (mainRulesJson != null && mainRulesJson.isNotEmpty) {
      // Create a mutable copy of existing labels just in case the main json alters them.
      Map<int, String> newLabels = Map.from(brightnessLabels);
      calOptions = _parseCalendarOptions(mainRulesJson, newLabels);
      brightnessLabels = newLabels;
    }

    // 6. Masters
    MasterRule? mingZhuRule = baseRuleset.mingZhuRule;
    MasterRule? shenZhuRule = baseRuleset.shenZhuRule;
    if (mastersJson != null && mastersJson.isNotEmpty) {
      try {
        final Map<String, dynamic> raw = jsonDecode(mastersJson);
        if (raw.containsKey('ming_zhu')) {
          final mz = raw['ming_zhu'];
          final boundary = _parseBoundary(
            mz['boundary'] ?? mingZhuRule?.boundary.name ?? 'lunar',
            'ming_zhu boundary',
          );
          final Map<int, String> table = Map.from(mingZhuRule?.table ?? {});
          (mz['table'] as Map<String, dynamic>).forEach((k, v) {
            table[int.parse(k)] = v.toString();
          });
          mingZhuRule = MasterRule(boundary, table);
        }
        if (raw.containsKey('shen_zhu')) {
          final sz = raw['shen_zhu'];
          final boundary = _parseBoundary(
            sz['boundary'] ?? shenZhuRule?.boundary.name ?? 'lunar',
            'shen_zhu boundary',
          );
          final Map<int, String> table = Map.from(shenZhuRule?.table ?? {});
          (sz['table'] as Map<String, dynamic>).forEach((k, v) {
            table[int.parse(k)] = v.toString();
          });
          shenZhuRule = MasterRule(boundary, table);
        }
      } catch (e, s) {
        ZiweiLogger.error("Masters parsing failed", e, s);
      }
    }

    final ruleset = ZiweiRuleset(
      stars: stars,
      flowDefinitions: flowDefinitions,
      brightnessLabels: brightnessLabels,
      siHuaRules: siHuaRules,
      calendarOptions: calOptions,
      mingZhuRule: mingZhuRule,
      shenZhuRule: shenZhuRule,
    );

    _validateBrightnessDependencies(ruleset);

    return ruleset;
  }

  /// **直接由原生大JSON全量装载一套完整的引擎规则集**
  ///
  /// 此方法常用于开发者想要完全摒弃自带的默认规则，不借助 `overrideWith` 差异覆盖，
  /// 而是从零开始注入所有的排盘算法数据。
  ///
  /// - [starsJson] `stars.json`
  /// - [brightnessJson] `brightness.json` (可选)
  /// - [sihuaJson] `sihua.json`
  /// - [flowJson] `flow_stars.json`
  /// - [mainRulesJson] `main_rules.json`
  /// - [mastersJson] `masters.json` (可选)
  static ZiweiRuleset createRuleset({
    required String starsJson,
    String? brightnessJson,
    required String sihuaJson,
    required String flowJson,
    required String mainRulesJson,
    String? mastersJson,
  }) {
    // 1. parse brightness map
    final Map<int, String> brightnessLabels = {};
    Map<String, List<int>> brightnessMap = {};
    if (brightnessJson != null && brightnessJson.isNotEmpty) {
      try {
        final Map<String, dynamic> rawMap = jsonDecode(brightnessJson);
        rawMap.forEach((key, value) {
          if (value is List) {
            brightnessMap[key] = value.cast<int>();
          }
        });
      } catch (e) {
        ZiweiLogger.warn("Brightness table parsing failed", e);
      }
    }

    // 2. parse stars
    List<StaticStar> stars = [];
    if (starsJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(starsJson);
        stars = list.map((e) {
          return StaticStar.fromJson(e, brightnessMap);
        }).toList();
      } catch (e, s) {
        ZiweiLogger.error("Stars parsing failed", e, s);
      }
    }

    // 3. parse sihua
    Map<TianGan, Map<SiHuaType, String>> siHuaRules = {};
    if (sihuaJson.isNotEmpty) {
      try {
        final Map<String, dynamic> raw = jsonDecode(sihuaJson);
        raw.forEach((ganKey, rules) {
          final gan = TianGan.fromName(ganKey);
          if (rules is Map<String, dynamic>) {
            final Map<SiHuaType, String> ruleMap = {};
            rules.forEach((sihuaKey, starKey) {
              final type = SiHuaType.fromJson(sihuaKey);
              ruleMap[type] = starKey.toString();
            });
            siHuaRules[gan] = ruleMap;
          }
        });
      } catch (e, s) {
        ZiweiLogger.error("SiHua rules parsing failed", e, s);
      }
    }

    // 4. parse flow definitions
    List<FlowDefinition> flowDefinitions = [];
    if (flowJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(flowJson);
        flowDefinitions = list.map((e) => FlowDefinition.fromJson(e)).toList();
      } catch (e, s) {
        ZiweiLogger.error("Flow definitions parsing failed", e, s);
      }
    }

    // 5. parse main rules
    final calOptions = _parseCalendarOptions(mainRulesJson, brightnessLabels);

    // 6. parse masters
    MasterRule? mingZhuRule;
    MasterRule? shenZhuRule;
    if (mastersJson != null && mastersJson.isNotEmpty) {
      try {
        final Map<String, dynamic> raw = jsonDecode(mastersJson);
        if (raw.containsKey('ming_zhu')) {
          final mz = raw['ming_zhu'];
          final boundary = _parseBoundary(
            mz['boundary'] ?? 'lunar',
            'ming_zhu boundary',
          );
          final Map<int, String> table = {};
          (mz['table'] as Map<String, dynamic>).forEach((k, v) {
            table[int.parse(k)] = v.toString();
          });
          mingZhuRule = MasterRule(boundary, table);
        }
        if (raw.containsKey('shen_zhu')) {
          final sz = raw['shen_zhu'];
          final boundary = _parseBoundary(
            sz['boundary'] ?? 'lunar',
            'shen_zhu boundary',
          );
          final Map<int, String> table = {};
          (sz['table'] as Map<String, dynamic>).forEach((k, v) {
            table[int.parse(k)] = v.toString();
          });
          shenZhuRule = MasterRule(boundary, table);
        }
      } catch (e, s) {
        ZiweiLogger.error("Masters parsing failed", e, s);
      }
    }

    final ruleset = ZiweiRuleset(
      stars: stars,
      flowDefinitions: flowDefinitions,
      brightnessLabels: brightnessLabels,
      siHuaRules: siHuaRules,
      calendarOptions: calOptions,
      mingZhuRule: mingZhuRule,
      shenZhuRule: shenZhuRule,
    );

    _validateBrightnessDependencies(ruleset);

    return ruleset;
  }

  static CalendarOptions _parseCalendarOptions(
    String jsonStr,
    Map<int, String> outLabels,
  ) {
    if (jsonStr.trim().isEmpty) {
      throw ArgumentError('JSON string cannot be null or empty');
    }

    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Root must be a JSON object');
    }

    if (decoded.containsKey('brightness_labels')) {
      final Map<String, dynamic> labels = decoded['brightness_labels'];
      labels.forEach((k, v) {
        if (int.tryParse(k) != null) {
          outLabels[int.parse(k)] = v.toString();
        }
      });
    }

    final calMap = _requireMap(decoded, 'calendar');
    final splitRat = _requireBool(calMap, 'split_rat_hour');
    final leapStr = _requireString(calMap, 'leap_month_strategy');
    final leapRule = _parseLeapRule(leapStr);
    final wuHuStr = _requireString(calMap, 'wu_hu_dun_boundary');
    final wuHuBoundary = _parseBoundary(wuHuStr, 'wu_hu_dun_boundary');
    final siHuaStr = _requireString(calMap, 'sihua_boundary');
    final siHuaBoundary = _parseBoundary(siHuaStr, 'sihua_boundary');
    final childhoodStr = _requireString(calMap, 'childhood_decade');
    final childhoodDecadeRule = _parseChildhoodDecadeRule(childhoodStr);
    final flowLimitstr = _requireString(calMap, 'flowLimit_boundary');
    final flowLimitBoundary = _parseBoundary(
      flowLimitstr,
      'flowLimit_boundary',
    );
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

  static ChildhoodRole _parseChildhoodDecadeRule(String str) {
    switch (str) {
      case 'skip':
        return ChildhoodRole.skip;
      case 'regular':
        return ChildhoodRole.regular;
      default:
        throw ArgumentError('❌ Invalid childhood_decade: $str');
    }
  }

  /// 内部校验器：确保每一颗星曜身上的亮度数字，在当前的规则集下都合法存在（-1 除外）
  static void _validateBrightnessDependencies(ZiweiRuleset ruleset) {
    if (ruleset.brightnessLabels.isEmpty) {
      ZiweiLogger.warn(
        "Brightness labels are empty. Ensure main_rules.json defines them.",
      );
    }

    final validKeys = ruleset.brightnessLabels.keys.toList();

    // 1. 校验所有的静态星曜
    for (var star in ruleset.stars) {
      for (var b in star.brightnessTable) {
        if (b != -1 && !validKeys.contains(b)) {
          throw FormatException(
            "💥 Validation Error: StaticStar '${star.key}' uses an undefined brightness value '$b'. Defined labels are: $validKeys",
          );
        }
      }
    }

    // 2. 校验所有的流运星曜
    for (var flow in ruleset.flowDefinitions) {
      for (var b in flow.brightness) {
        if (b != -1 && !validKeys.contains(b)) {
          throw FormatException(
            "💥 Validation Error: FlowStar '${flow.key}' uses an undefined brightness value '$b'. Defined labels are: $validKeys",
          );
        }
      }
    }
  }
}
