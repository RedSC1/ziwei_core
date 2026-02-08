import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

class SiHuaDecorator {
  /// ✅ 1. 万能入口：根据天干注入四化
  /// 适用于：原局(生年干)、大限(大限干)、流年(流年干)
  static void decorateByStem({
    required ZiWeiPlate plate,
    required TianGan stem,
    required Map<TianGan, Map<SiHuaType, String>> siHuaTable,
    required ZiweiScope scope,
  }) {
    // 1. 查表获取规则 (例如: 甲 -> {lu: "lianzhen", ji: "taiyang"...})
    final rules = siHuaTable[stem];
    if (rules == null) return;

    // 2. 遍历所有宫位
    for (var palace in plate.palaces) {
      // 3. 遍历宫内星星
      for (var star in palace.stars) {
        if (star is StaticStar) {
          // 4. 匹配并注入四化
          // 这里使用倒排判断更直观
          if (rules[SiHuaType.lu] == star.key) {
            star.siHuaBuff[scope] = SiHuaType.lu;
          } else if (rules[SiHuaType.quan] == star.key) {
            star.siHuaBuff[scope] = SiHuaType.quan;
          } else if (rules[SiHuaType.ke] == star.key) {
            star.siHuaBuff[scope] = SiHuaType.ke;
          } else if (rules[SiHuaType.ji] == star.key) {
            star.siHuaBuff[scope] = SiHuaType.ji;
          }
        }
      }
    }
  }

  /// ✅ 2. 便捷入口：根据日期注入四化 (通常用于原局)
  static void decorateByDate({
    required ZiWeiPlate plate,
    required ZiweiDate date,
    required Map<TianGan, Map<SiHuaType, String>> siHuaTable,
    required ZiweiScope scope,
  }) {
    // 自动获取对应的天干 (比如生年干)
    // 复用了 ZiweiDate 里的逻辑 (含节气/农历判断)
    final stem = date.getGanZhi(scope, b: date.options.siHuaBasedOn).gan;
    decorateByStem(
      plate: plate,
      stem: stem,
      siHuaTable: siHuaTable,
      scope: scope,
    );
  }
}
