import 'dart:convert';
import '../time/ziwei_date.dart';
import '../enums/config_enums.dart';

class ConfigLoader {
  static CalendarOptions parse(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) {
      throw ArgumentError('JSON string cannot be null or empty');
    }

    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw ArgumentError('Root must be a JSON object');
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
}
