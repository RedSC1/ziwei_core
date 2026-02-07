import 'dart:convert';
import 'package:ziwei_core/src/data/star.dart';

import '../time/ziwei_date.dart';
import '../enums/config_enums.dart';

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

      brightnessLabels.clear(); // 清空旧数据
      labels.forEach((k, v) {
        // k 是字符串 "5", v 是 "level_miao"
        // 把它转成 int 存进 map
        if (int.tryParse(k) != null) {
          brightnessLabels[int.parse(k)] = v.toString();
        }
      });
      print("✅ 已加载 ${brightnessLabels.length} 个亮度等级配置");
    }
    // 1. 拿 Calendar 节点
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
  // ✅ 解析星星列表
  // ✅ 新增参数：brightnessJson
  static void parseStars(String starsJson, String brightnessJson) {
    // 1. 先把亮度表解析成 Map (为了快查)
    Map<String, List<int>> brightnessMap = {};
    try {
      if (brightnessJson.isNotEmpty) {
        final Map<String, dynamic> rawMap = jsonDecode(brightnessJson);
        // 把 dynamic 强转成 List<int>
        rawMap.forEach((key, value) {
          if (value is List) {
            brightnessMap[key] = value.cast<int>();
          }
        });
      }
    } catch (e) {
      print("⚠️ 亮度表解析失败 (将使用默认全0): $e");
    }

    // 2. 再解析星星，并注入亮度数据
    if (starsJson.trim().isEmpty) {
      stars = [];
      return;
    }

    try {
      final List<dynamic> list = jsonDecode(starsJson);

      // 🔥 关键点：把 brightnessMap 传给 fromJson
      stars = list.map((e) {
        return StaticStar.fromJson(e, brightnessMap);
      }).toList();

      print("✅ 已加载 ${stars.length} 颗星星 (带亮度数据)");
    } catch (e) {
      print("❌ 星星解析失败: $e");
      stars = [];
      throw FormatException("Stars JSON error: $e");
    }
  }

  // ... 原有的 helper 方法 ...
}
