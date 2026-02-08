import 'dart:convert';
import 'package:ziwei_core/src/data/star.dart';

import '../time/ziwei_date.dart';
import '../enums/config_enums.dart';
import '../core/logger.dart';

class ConfigLoader {
  static List<StaticStar> stars = [];
  static Map<int, String> brightnessLabels = {};

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
    final wuHuBoundary = _parseWuHuBoundary(wuHuStr);

    return CalendarOptions(
      splitRatHour: splitRat,
      leapRule: leapRule,
      wuHuDunBasedOn: wuHuBoundary,
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

  static Boundary _parseWuHuBoundary(String str) {
    switch (str) {
      case 'lunar':
        return Boundary.lunar;
      case 'solar':
        return Boundary.solar;
      default:
        throw ArgumentError('❌ Invalid wu_hu_dun_boundary: $str');
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
      ZiweiLogger.warn("Brightness table parsing failed (will use defaults)", e);
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
    } catch (e, s) {
      ZiweiLogger.error("Stars parsing failed", e, s);
      stars = [];
      throw FormatException("Stars JSON error: $e");
    }
  }

  // ... 原有的 helper 方法 ...
}
