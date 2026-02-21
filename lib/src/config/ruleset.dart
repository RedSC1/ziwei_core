import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/config/schemas/flow_definition.dart';
import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

class ZiweiRuleset {
  final List<StaticStar> stars;
  final List<FlowDefinition> flowDefinitions;
  final Map<int, String> brightnessLabels;
  final Map<TianGan, Map<SiHuaType, String>> siHuaRules;
  final MasterRule? mingZhuRule;
  final MasterRule? shenZhuRule;
  final CalendarOptions calendarOptions;

  final Map<String, StarRule> _starRules = {};
  final Map<String, StaticStar> _starDict = {};

  ZiweiRuleset({
    required this.stars,
    required this.flowDefinitions,
    required this.brightnessLabels,
    required this.siHuaRules,
    required this.calendarOptions,
    this.mingZhuRule,
    this.shenZhuRule,
  }) {
    // 建立星曜规则映射，用于快速定位
    for (var star in stars) {
      _starRules[star.key] = star.rule;
      _starDict[star.key] = star;
    }
  }

  /// 获取指定星曜的规则
  StarRule? getStarRule(String key) => _starRules[key];

  /// 获取指定星曜的对象
  StaticStar? getStar(String key) => _starDict[key];
}
