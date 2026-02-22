import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/config/schemas/flow_definition.dart';
import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

/// **核心排盘规则中枢 (Ruleset)**
///
/// 承载了紫微斗数引擎所有推演算法与资源定义的数据总线。
/// 一般无需手动构造，而是交由 `ConfigLoader` 查阅 JSON 配置字典统一装配。
class ZiweiRuleset {
  /// 原局静态星曜（包含紫微星系、辅曜等固化星星）及其安星轨道的全量汇编
  final List<StaticStar> stars;

  /// 专供大限、流年、流月等微观切片时间体系使用的“动态增补流曜”定义表
  final List<FlowDefinition> flowDefinitions;

  /// 引擎全局唯一亮度环境字典（数字到 i18n 标识键的映射，如：`10` -> `"miao"`）
  final Map<int, String> brightnessLabels;

  /// 全局四化飞星词典（如某天干触发某星化禄字典映射）
  final Map<TianGan, Map<SiHuaType, String>> siHuaRules;

  /// 本派别的命主安放起例规则
  final MasterRule? mingZhuRule;

  /// 本派别的身主安放起例规则
  final MasterRule? shenZhuRule;

  /// 控制早晚子时、五虎遁边界、阴历转换等基准运行开关的历法调度器
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

  /// 精准提取指定键值的单颗星曜起例与定位规则
  StarRule? getStarRule(String key) => _starRules[key];

  /// 精准提取指定键值的已就绪原局静态星曜实体大对象
  StaticStar? getStar(String key) => _starDict[key];
}
