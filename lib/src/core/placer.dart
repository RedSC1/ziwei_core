import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/src/core/star_locator.dart';
import 'package:ziwei_core/src/enums/consts.dart';

/// **紫微与天府双星定位器**
///
/// 专门用来推算紫微星系与天府星系起点。
class ZiweiAndTianfuPlacer {
  /// 核心定位算法：推算紫微星与天府星的落入宫位。
  ///
  /// - [day] 农历生日日期 (1-30)
  /// - [bureau] 命造所在五行局数 (水二局=2, 木三局=3...)
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

/// **星曜安放器 (Star Placer)**
///
/// 作为 `StarLocator` 的批量执行代理。
/// 其持有全局排盘引擎上下文，遍历配置好的星星实体列表，并将其置入对应的 `Palace` 格子中。
class StarPlacer {
  final RuleContext context;
  final List<Palace> palaces;
  final ZiweiDate date;

  StarPlacer(this.context, this.palaces, this.date);

  /// 批量安放列表中的所有星星实体
  ///
  /// - [stars] 需要被安放到物理宫位的静态星星集合
  void placeAll(List<StaticStar> stars) {
    if (stars.isEmpty) return;
    for (var star in stars) {
      placeStar(star);
    }
  }

  /// 针对单一特定静态星曜执行定位与安放
  ///
  /// - [star] 等待落宫的具体星体
  void placeStar(StaticStar star) {
    // 1. 将计算核心全部委托给 StarLocator 获取绝对或相对偏移量
    final int? rawIndex = StarLocator.locate(star.key, context);

    // 2. 检测计算合法性 (null 代表规则中枢无对应配置或触发逻辑异常)
    if (rawIndex != null) {
      // 3. 将任何跨界的数值包裹修剪为物理宫位范围 (0-11)
      final int finalIndex = ZiweiConsts.fixIndex(rawIndex);

      // 每次排盘都必须放入独立星体实例，避免后续四化装饰回写污染 ruleset.stars。
      palaces[finalIndex].addStar(star.clone());
    } else {
      // 若计算结果为 null，则表明这颗星曜不触发（留空处理）
    }
  }
}
