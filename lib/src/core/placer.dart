import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/src/core/star_locator.dart';
import 'package:ziwei_core/src/enums/consts.dart';

class ZiweiAndTianfuPlacer {
  /// 安紫微星
  /// [day] 农历生日 (1-30)
  /// [bureau] 五行局数 (2,3,4,5,6)
  /// 返回: 紫微星的宫位索引 (0-11, 0是子宫)
  static (int ziweiIndex, int tianfuIndex) placeZiweiAndTianfu(
    int day,
    int bureau,
  ) {
    int quotient; // 商
    int remainder; // 补数

    if (day % bureau == 0) {
      quotient = day ~/ bureau;
      remainder = 0;
    } else {
      int toAdd = bureau - (day % bureau);
      quotient = (day + toAdd) ~/ bureau;
      remainder = (toAdd % 2 == 1) ? -toAdd : toAdd; // 奇减偶加
    }

    // 公式：商 + 余 + 寅宫基准(1)
    int index = ZiweiConsts.fixIndex(quotient + remainder + 1);

    return (index, ZiweiConsts.fixIndex(4 - index));
  }
}

/// 星曜安放器 (Star Placer)
///
/// 现在的职责非常单一：它只是 StarLocator 的“操作员”。
/// 它持有上下文，遍历星星列表，然后把 StarLocator 算出来的结果填进 Palace 里。
class StarPlacer {
  final RuleContext context;
  final List<Palace> palaces;
  final ZiweiDate date;

  StarPlacer(this.context, this.palaces, this.date);

  void placeAll(List<StaticStar> stars) {
    if (stars.isEmpty) return;
    for (var star in stars) {
      placeStar(star);
    }
  }

  void placeStar(StaticStar star) {
    // 1. 核心逻辑委托给 StarLocator (现在返回的是 int?)
    final int? rawIndex = StarLocator.locate(star.key, context);

    // 2. 先判断是不是 null (代表规则缺失或计算彻底失败)
    if (rawIndex != null) {
      
      // 3只要不是 null，哪怕是 -1, -5, 13
      // 都统统交给 fixIndex 修正回 0-11 的合法宫位索引
      final int finalIndex = ZiweiConsts.fixIndex(rawIndex);
      
      palaces[finalIndex].addStar(star);
      
      // Optional: 调试的时候可以看看它最后落在了哪
      // print("${star.key} raw: $rawIndex -> fixed: $finalIndex");
    } else {
      // 如果是 null，这颗星就安安静静地不出现在盘上
      // ZiweiLogger.warn("星曜 ${star.key} 计算失败，跳过安星");
    }
  }
}
