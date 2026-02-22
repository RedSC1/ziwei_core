import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';

class SiHuaDecorator {
  /// 1. 原盘四化 (生年 + 自化 + 向心)
  static void decorateBase(
    ZiWeiPlate plate,
    Map<TianGan, Map<SiHuaType, String>> rules,
  ) {
    // A. 生年四化 (Year Origin)
    final yearGan = plate.date.getGanZhi(ZiweiScope.origin).gan;
    decorateByStem(
      plate: plate,
      stem: yearGan,
      siHuaTable: rules,
      scope: ZiweiScope.origin,
    );

    // B. 自化与向心
    for (int i = 0; i < 12; i++) {
      final currentPalace = plate.palaces[i];
      final oppositeIndex = (i + 6) % 12;
      final oppositeGan = plate.palaces[oppositeIndex].stem;
      final selfGan = currentPalace.stem;

      // 遍历当前宫位的所有抽屉
      for (final starList in currentPalace.stars.values) {
        for (final star in starList) {
          if (star is! StaticStar) continue;

          // 1. 处理自化 (本宫干)
          if (selfGan != null && rules.containsKey(selfGan)) {
            final selfRule = rules[selfGan]!;
            for (var entry in selfRule.entries) {
              if (entry.value == star.key) {
                star.selfSiHua = entry.key;
              }
            }
          }

          // 2. 处理向心 (对宫干)
          if (oppositeGan != null && rules.containsKey(oppositeGan)) {
            final oppoRule = rules[oppositeGan]!;
            for (var entry in oppoRule.entries) {
              if (entry.value == star.key) {
                star.centripetalSiHua = entry.key;
              }
            }
          }
        }
      }
    }
  }

  /// 2. 通用四化应用 (大限、流年等)
  static void decorateByStem({
    required ZiWeiPlate plate,
    required TianGan stem,
    required Map<TianGan, Map<SiHuaType, String>> siHuaTable,
    required ZiweiScope scope,
  }) {
    if (!siHuaTable.containsKey(stem)) return;
    final rule = siHuaTable[stem]!;

    for (final palace in plate.palaces) {
      // 这里的 stars 现在是 Map，所以得加一层 values 循环
      for (final starList in palace.stars.values) {
        for (final star in starList) {
          if (star is! StaticStar) continue;

          // 检查这颗星是否符合四化规则
          for (final entry in rule.entries) {
            if (entry.value == star.key) {
              star.siHuaBuff[scope] = entry.key;
            }
          }
        }
      }
    }
  }
}
