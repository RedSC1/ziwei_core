import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/scope.dart';

class ZiWeiPlate {
  final List<Palace> palaces;
  final int originMingIndex;
  final int bodyPalaceIndex;
  final FiveElementBureau elementBureau;

  int? decadeMingIndex;
  int? yearMingIndex;
  int? monthMingIndex;
  int? dayMingIndex;
  int? hourMingIndex;
  ZiWeiPlate({
    required this.palaces,
    required this.originMingIndex,
    required this.bodyPalaceIndex,
    required this.elementBureau,
    this.decadeMingIndex,
    this.yearMingIndex,
    this.monthMingIndex,
    this.dayMingIndex,
    this.hourMingIndex,
  });

  /// 核心查询方法：获取某一层级、某一角色的宫位
  /// 比如: getPalace(ZiweiScope.decade, PalaceRole.spouse) -> 大限夫妻宫
  Palace getPalace(ZiweiScope scope, PalaceRole role) {
    // 1. 先找到那一层的【命宫】在哪
    int mingIndex = _getMingIndex(scope);

    // 2. 根据角色计算偏移 (逆时针)
    // 命宫=0, 兄弟=1...
    // 逆时针公式: (命宫索引 - 角色偏移 + 12) % 12
    int targetIndex = role.getIndex(mingIndex);
    return palaces[targetIndex];
  }

  // ✅ 新增：反查角色 (给定某个宫位格子，查它是什么职能)
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
    }
    if (mingIndex == null) {
      throw Exception("❌ 还没计算 ${scope.name} 的命宫位置！");
    }
    return mingIndex;
  }
}
