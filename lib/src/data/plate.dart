import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/enums/basic.dart';

import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/src/config/ruleset.dart';

/// **紫微斗数命盘 (ZiWei Plate)**
///
/// 整个排盘引擎的核心数据结构。这里存储了12宫的所有星曜、神煞、四化，
/// 以及当前所处的各种大限、小限和流年状态。
///
/// ---
/// ### 📦 核心配置属性
/// - [palaces] 包含十二宫位的完整状态集合
/// - [date] 真正的命盘出生时间设定
/// - [ruleset] 从JSON读取的排盘规则字典，详见 `ZiweiRuleset`
/// - [elementBureau] 该命盘的五行局
/// - [effectiveMonth] 实际用于排盘的有效历法月
/// - [effectiveYear] 实际用于排盘的有效历法年
/// - [mingZhu] 命主星
/// - [shenZhu] 身主星
///
/// ---
/// ### 📍 宫位指针结构
/// - [originMingIndex] 原局命宫索引
/// - [bodyPalaceIndex] 身宫索引
/// - [decadeMingIndex] 大限命宫索引 (若进入流运)
/// - [smallLimitMingIndex] 小限命宫索引 (若进入小限)
/// - [yearMingIndex] 流年命宫索引
/// - [monthMingIndex] 流月命宫索引
/// - [dayMingIndex] 流日命宫索引
/// - [hourMingIndex] 流时命宫索引
class ZiWeiPlate {
  final List<Palace> palaces;
  final int originMingIndex;
  final int bodyPalaceIndex;
  final FiveElementBureau elementBureau;
  final ZiweiDate date;
  final ZiweiRuleset ruleset;
  final int effectiveMonth;
  final int effectiveYear;

  final String? mingZhu;
  final String? shenZhu;

  int? decadeMingIndex;
  int? smallLimitMingIndex;
  int? yearMingIndex;
  int? monthMingIndex;
  int? dayMingIndex;
  int? hourMingIndex;

  // ==========================================
  // 快速获取各个流层的“命宫”实体
  // ==========================================

  /// 获取[原局命宫]实体对象
  Palace get originMingPalace =>
      palaces.firstWhere((p) => p.index == originMingIndex);

  /// 获取[身宫]实体对象
  Palace get bodyPalace =>
      palaces.firstWhere((p) => p.index == bodyPalaceIndex);

  /// 如果当前有大限流运，快速获取[大限命宫]实体对象；否则返回 null
  Palace? get decadeMingPalace => decadeMingIndex != null
      ? palaces.firstWhere((p) => p.index == decadeMingIndex)
      : null;

  /// 如果当前有小限，快速获取[小限命宫]实体对象；否则返回 null
  Palace? get smallLimitMingPalace => smallLimitMingIndex != null
      ? palaces.firstWhere((p) => p.index == smallLimitMingIndex)
      : null;

  /// 如果当前有流年流运，快速获取[流年命宫]实体对象；否则返回 null
  Palace? get yearMingPalace => yearMingIndex != null
      ? palaces.firstWhere((p) => p.index == yearMingIndex)
      : null;

  /// 如果当前有特定流月，快速获取[流月命宫]实体对象；否则返回 null
  Palace? get monthMingPalace => monthMingIndex != null
      ? palaces.firstWhere((p) => p.index == monthMingIndex)
      : null;

  /// 如果当前有推演到流日，快速获取[流日命宫]实体对象；否则返回 null
  Palace? get dayMingPalace => dayMingIndex != null
      ? palaces.firstWhere((p) => p.index == dayMingIndex)
      : null;

  /// 如果当前有推演到流时，快速获取[流时命宫]实体对象；否则返回 null
  Palace? get hourMingPalace => hourMingIndex != null
      ? palaces.firstWhere((p) => p.index == hourMingIndex)
      : null;

  ZiWeiPlate({
    required this.palaces,
    required this.originMingIndex,
    required this.bodyPalaceIndex,
    required this.elementBureau,
    required this.date,
    required this.ruleset,
    required this.effectiveMonth,
    required this.effectiveYear,

    required this.mingZhu,
    required this.shenZhu,

    this.decadeMingIndex,
    this.smallLimitMingIndex,
    this.yearMingIndex,
    this.monthMingIndex,
    this.dayMingIndex,
    this.hourMingIndex,
  });

  /// 核心查询方法：获取某一层级、某一角色的宫位
  ///
  /// 比如: `getPalace(ZiweiScope.decade, PalaceRole.spouse)` -> 返回当前大限夫妻宫
  ///
  /// - [scope] 所查询的流运层级 (原局,大限,流年...)
  /// - [role] 目标查看的角色名称 (命,兄弟,夫妻...)
  Palace getPalace(ZiweiScope scope, PalaceRole role) {
    // 1. 先找到那一层的【命宫】在哪
    int mingIndex = _getMingIndex(scope);

    // 2. 根据角色计算偏移 (逆时针)
    // 命宫=0, 兄弟=1...
    // 逆时针公式: (命宫索引 - 角色偏移 + 12) % 12
    int targetIndex = role.getIndex(mingIndex);
    return palaces[targetIndex];
  }

  /// 反查角色 (给定某个宫位格子，查它在指定流派层级里是什么职能)
  ///
  /// - [scope] 目标评估的流运层级 (原局,大限,流年...)
  /// - [palaceIndex] 宫位的硬装地支绝对索引 (0=子, 1=丑...)
  PalaceRole getRole(ZiweiScope scope, int palaceIndex) {
    // 1. 先找那一层的命宫在哪
    int mingIndex = _getMingIndex(scope);

    // 2. 核心公式：逆推 (命宫 - 格子 + 12) % 12
    // 比如命在4(辰)，查2(寅)是什么宫？
    // (4 - 2 + 12) % 12 = 2 -> PalaceRole.spouse (夫妻)
    int offset = (mingIndex - palaceIndex + 12) % 12;
    // 3. 把数字转成枚举 (PalaceRole 的顺序必须是 命兄夫子...)
    return PalaceRole.values[offset];
  }

  /// 🚀 深拷贝 (Deep Copy)
  ///
  /// 生成一个完全独立的数据副本模型，允许时间在流转时 (如生成流运盘) 随意篡改星体引用状态，
  /// 同时不破坏原盘局数据。
  ZiWeiPlate clone() {
    return ZiWeiPlate(
      // 1. 关键：所有宫位深拷贝 (Recursive Clone)
      palaces: palaces.map((p) => p.clone()).toList(),

      // 2. 基础数据复制 (值类型)
      originMingIndex: originMingIndex,
      bodyPalaceIndex: bodyPalaceIndex,
      elementBureau: elementBureau,

      // 3. 规则引用复制 (浅拷贝即可，因为规则是只读的)
      ruleset: ruleset,
      effectiveMonth: effectiveMonth,
      effectiveYear: effectiveYear,

      mingZhu: mingZhu,
      shenZhu: shenZhu,

      // 4. 状态指针复制
      decadeMingIndex: decadeMingIndex,
      smallLimitMingIndex: smallLimitMingIndex,
      yearMingIndex: yearMingIndex,
      monthMingIndex: monthMingIndex,
      dayMingIndex: dayMingIndex,
      hourMingIndex: hourMingIndex,

      date: date,
    );
  }

  int _getMingIndex(ZiweiScope scope) {
    int? mingIndex;
    switch (scope) {
      case ZiweiScope.origin:
        mingIndex = originMingIndex;
        break;
      case ZiweiScope.decade:
        mingIndex = decadeMingIndex;
        break;
      case ZiweiScope.year:
        mingIndex = yearMingIndex;
        break;
      case ZiweiScope.month:
        mingIndex = monthMingIndex;
        break;
      case ZiweiScope.day:
        mingIndex = dayMingIndex;
        break;
      case ZiweiScope.hour:
        mingIndex = hourMingIndex;
        break;
      case ZiweiScope.smallLimit:
        mingIndex = smallLimitMingIndex;
        break;
    }
    if (mingIndex == null) {
      throw Exception("❌ 还没计算 ${scope.name} 的命宫位置！");
    }
    return mingIndex;
  }

  /// 序列化紫微斗数全局命盘结构
  ///
  /// 这是总控级别的 JSON 输出，整合了基础元数据、出生时刻模型、流运游标位置以及完整的十二宫星曜分布。
  Map<String, dynamic> toJson() {
    return {
      'meta': {
        'element_bureau': elementBureau.name,
        'effective_year': effectiveYear,
        'effective_month': effectiveMonth,
        'ming_zhu': mingZhu,
        'shen_zhu': shenZhu,
      },
      'date': date.toJson(),
      'time_cursors': {
        'origin_ming': originMingIndex,
        'body_palace': bodyPalaceIndex,
        'decade_ming': decadeMingIndex,
        'small_limit_ming': smallLimitMingIndex,
        'year_ming': yearMingIndex,
        'month_ming': monthMingIndex,
        'day_ming': dayMingIndex,
        'hour_ming': hourMingIndex,
      },
      // 遍历 12 个宫位，调用各个 Palace 自己的 toJson 进行递归装配
      'palaces': palaces
          .map((p) => p.toJson(brightnessLabels: ruleset.brightnessLabels))
          .toList(),
    };
  }
}
