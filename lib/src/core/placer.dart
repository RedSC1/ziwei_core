import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';

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
    int remainder; // 补数 (注意：这里我们算的不是余数，是这就差多少能整除)

    if (day % bureau == 0) {
      // 1. 能整除：商直接定宫位
      quotient = day ~/ bureau;
      remainder = 0;
    } else {
      // 2. 不能整除：需要“补”到一个能整除的数
      // 比如 木三局(3) 生日初五(5) -> 补 1 变成 6
      int toAdd = bureau - (day % bureau);
      quotient = (day + toAdd) ~/ bureau;
      remainder = (toAdd % 2 == 1) ? -toAdd : toAdd; // 奇减偶加
    }

    // 公式：商 + 余 + 寅宫基准(1)
    //商数1对应寅宫(index 2)
    // (quotient + remainder - 1 + 2) % 12
    int index = (quotient + remainder + 1) % 12;

    // 防止负数
    if (index < 0) index += 12;

    return (index, (4 - index + 12) % 12);
  }
}

class StarPlacer {
  final Map<String, int> anchorsMap; //再Engine里面算出来的锚点坐标，比如“anchor_ziwei”
  final List<Palace> palaces;
  StarPlacer(this.anchorsMap, this.palaces);

  void placeStar(StaticStar star) {
    StarRule rule = star.rule;

    int targetIndex = -1;

    switch (rule.type) {
      // ✅ case 1: 锚点偏移 (紫微系、天府系常用)
      case StarRuleType.anchorOffset:
        // 强制转型成 AnchorOffsetRule
        if (rule is AnchorOffsetRule) {
          targetIndex = _handleAnchorOffset(rule);
        }
        break;

      // ✅ case 2: 查表法
      // case StarRuleType.lookup:
      //   ...
      //   break;

      default:
        // 还没实现
        break;
    }

    if (targetIndex >= 0 && targetIndex < 12) {
      // 把星星塞进而去！
      palaces[targetIndex].addStar(star);
    }
  }

  int _handleAnchorOffset(AnchorOffsetRule rule) {
    // 1. 查锚点在哪 (比如找 "ziwei")
    String key = rule.anchorKey;

    // 如果找不到锚点，默认给 -1 (表示无法安星) 或者 0，看你心情
    if (!anchorsMap.containsKey(key)) {
      print("⚠️ 找不到锚点: $key");
      return -1;
    }

    int anchorIndex = anchorsMap[key]!;

    // 2. 加上偏移量
    int rawIndex = anchorIndex + rule.offset;

    // 3. 修正到 0-11 范围 (处理负数)
    return fixIndex(rawIndex);
  }

  int fixIndex(int index) {
    int result = index % 12;
    if (result < 0) result += 12;
    return result;
  }

  void placeAll(List<StaticStar> stars) {
    if (stars.isEmpty) return;
    for (var star in stars) {
      placeStar(star); // 里面就是你刚才写的 switch 逻辑
    }
  }
}
