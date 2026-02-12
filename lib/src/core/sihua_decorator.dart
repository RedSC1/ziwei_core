import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';

class SiHuaDecorator {
  /// 1. 原盘四化 (Base Decoration)
  /// 包括：生年四化 (Origin SiHua) + 自化 (Self) + 向心 (Centripetal)
  /// 注意：生年四化其实也可以用 decorateByStem(scope: origin) 来做，
  /// 但原盘逻辑里通常包含自化/向心，所以保留这个专用方法。
  static void decorateBase(
    ZiWeiPlate plate,
    Map<TianGan, Map<SiHuaType, String>> rules,
  ) {
    // A. 生年四化 (Year Origin)
    // 直接复用通用逻辑，Scope = origin
    // ✅ Fix: 使用 getGanZhi(ZiweiScope.origin) 自动处理 节气/农历 分界线配置
    final yearGan = plate.date.getGanZhi(ZiweiScope.origin).gan;
    decorateByStem(
      plate: plate,
      stem: yearGan,
      siHuaTable: rules,
      scope: ZiweiScope.origin,
    );

    // B. 自化 (Self) & 向心 (Centripetal)
    for (int i = 0; i < 12; i++) {
      final currentPalace = plate.palaces[i];

      // 1. 自化: 用本宫干，飞入本宫星
      final selfGan = currentPalace.stem;
      if (selfGan != null && rules.containsKey(selfGan)) {
        final ruleMap = rules[selfGan]!;
        for (var star in currentPalace.stars) {
          if (star is! StaticStar) continue;
          for (var entry in ruleMap.entries) {
            if (entry.value == star.key) {
              star.selfSiHua = entry.key;
            }
          }
        }
      }

      // 2. 向心: 用对宫干，飞入本宫星
      final oppositeIndex = (i + 6) % 12;
      final oppositePalace = plate.palaces[oppositeIndex];
      final oppositeGan = oppositePalace.stem;

      if (oppositeGan != null && rules.containsKey(oppositeGan)) {
        final ruleMap = rules[oppositeGan]!;
        for (var star in currentPalace.stars) {
          if (star is! StaticStar) continue;
          for (var entry in ruleMap.entries) {
            if (entry.value == star.key) {
              star.centripetalSiHua = entry.key;
            }
          }
        }
      }
    }
  }

  /// 2. Si Hua for Limits
  /// 用于大限、流年、流月等
  /// [stem]: 触发四化的天干 (如大限宫干、流年天干)
  /// [scope]: 作用域 (决定存在 siHuaBuff 的哪个 key 里)
  static void decorateByStem({
    required ZiWeiPlate plate,
    required TianGan stem,
    required Map<TianGan, Map<SiHuaType, String>> siHuaTable,
    required ZiweiScope scope,
  }) {
    // 查表：如果这个天干没有四化规则 (不可能，除非表缺了)，直接跳过
    if (!siHuaTable.containsKey(stem)) return;

    // 获取该天干对应的四化规则: { lu: "lianzhen", quan: "pojun", ... }
    final rule = siHuaTable[stem]!;

    // 遍历全盘星曜，寻找中奖的星
    // 效率优化：虽然是双层循环，但星曜总数固定，开销可控
    for (final palace in plate.palaces) {
      for (final star in palace.stars) {
        if (star is! StaticStar) continue;

        // 检查这颗星是否在规则 values 里
        // 比如 rule: { lu: "lianzhen" }, star.key: "lianzhen"
        // 稍微反过来查比较快：遍历 rule entries
        for (final entry in rule.entries) {
          if (entry.value == star.key) {
            // 中奖！应用 Buff
            // 比如 scope=decade, type=lu
            star.siHuaBuff[scope] = entry.key;
          }
        }
      }
    }
  }
}
