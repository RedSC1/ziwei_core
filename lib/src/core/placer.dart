import 'package:ziwei_core/src/config/schemas/star_rule.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

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
  final ZiweiDate date;
  StarPlacer(this.anchorsMap, this.palaces, this.date);

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
      case StarRuleType.lookup:
        if (rule is LookupRule) {
          targetIndex = _handleLookup(rule);
        }
        break;

      case StarRuleType.lookupOffset:
        if (rule is LookupShiftRule) {
          targetIndex = _handleLookupShift(rule, rule.boundary);
        }
        break;

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
    // 1. 查锚点 (现在 anchorsMap 已经是全知全能的了，直接查)
    String key = rule.anchorKey;

    if (!anchorsMap.containsKey(key)) {
      print("⚠️ 找不到锚点: $key");
      return -1;
    }

    int anchorIndex = anchorsMap[key]!;

    // 2. 🔥 核心修改：支持方向 (direction)
    // 旧公式: anchorIndex + rule.offset (只能顺行)
    // 新公式: rule.offset + (anchorIndex * rule.direction) (支持逆行)

    // 举例：地空 (offset=11, direction=-1, anchor=时辰)
    // 结果 = 11 + (时辰 * -1) = 11 - 时辰 (完美！)

    int rawIndex = rule.offset + (anchorIndex * rule.direction);

    // 3. 修正到 0-11 范围
    return fixIndex(rawIndex);
  }

  int _handleLookup(LookupRule rule) {
    // 1. 获取锚点的值 (比如 "jia", "yi")
    // 注意：这里需要用到 date 对象！
    String key = _getAnchorValue(rule.anchorKey, rule.boundary);

    // 2. 查表
    if (rule.table.containsKey(key)) {
      int baseIndex = rule.table[key]!;
      // 3. 加上偏移 (比如擎羊在禄存+1)
      return fixIndex(baseIndex + rule.offset);
    }
    return -1; // 查不到
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

  // 🛠️ 辅助函数：根据 anchorKey 获取时间值
  // 输入: "year_stem", Boundary.lunar
  // 输出: "jia" (甲)
  String _getAnchorValue(String anchorKey, Boundary boundary) {
    switch (anchorKey) {
      // ====== 年干 (Year Stem) ======
      case 'year_stem':
        return date.getGanZhi(ZiweiScope.origin, b: boundary).gan.name;

      // ====== 年支 (Year Branch) ======
      case 'year_branch':
        return date.getGanZhi(ZiweiScope.origin, b: boundary).zhi.name;

      // ====== 月干 (Month Stem) ======
      case 'month_stem':
        return date.getGanZhi(ZiweiScope.month, b: boundary).gan.name;

      // ====== 月支 (Month Branch) ======
      case 'month_branch':
        return date.getGanZhi(ZiweiScope.month, b: boundary).zhi.name;

      // ... 日时逻辑 ...
      // ... 日时逻辑 ...
      // ====== 日 (Day) ======

      // 1. 日数 (1, 2, 3...)
      case 'day_number':
        if (boundary == Boundary.solar) {
          return date.solarDay.toString(); // ✅ 节气日 (立春后第几天)
        } else {
          return date.lunar.day.toString(); // 农历日 (初一、十五)
        }

      // 2. 日干 (Day Stem)
      case 'day_stem':
        // 日干支是连续的，通常不分阴阳历，直接拿八字的就行
        return date.bazi.day.gan.name;

      // 3. 日支 (Day Branch)
      case 'day_branch':
        return date.bazi.day.zhi.name;

      // ====== 时 (Hour) ======

      // 1. 时数 (0-11)
      case 'hour_number':
      case 'hour_index': // 兼容一下叫法
        // 时辰也不分阴阳历，直接用索引
        return date.lunar.timeIndex.toString();

      // 2. 时干 (Hour Stem)
      case 'hour_stem':
        // ✅ Refactored: 时干也统一用 ZiweiDate 算 (虽然 ZiweiDate 里没写 hourStem 方法，但 bazi 属性里有)
        // 既然我们有 bazi.time.gan，直接用即可
        // 注意：原代码的农历分支里手算了五鼠遁，其实 luanr 库算的八字里已经有了
        return date.bazi.time.gan.name;

      // 3. 时支 (Hour Branch)
      case 'hour_branch':
        return date.bazi.time.zhi.name;
    }
    return "";
  }

  int _handleLookupShift(LookupShiftRule rule, Boundary boundary) {
    // 1. 拿到查表的 Key (比如年支 "yin")
    String lookupKey = _getAnchorValue(rule.anchorKey, rule.boundary);

    // 2. 查表得到起点 (比如 寅年起丑宫 -> 1)
    if (!rule.table.containsKey(lookupKey)) {
      return -1; // 查不到就放弃
    }
    int startIndex = rule.table[lookupKey]!;
    // 3. 拿到偏移的步数 (比如时辰)
    int shiftSteps = _getShiftValue(rule.shiftAnchorKey, boundary);

    // 4. 核心公式：起点 + (方向 * 步数)
    // 注意：通常时辰要减1 (子时是0)，具体看你的 shiftSteps 怎么算的
    // 如果 shiftSteps 返回的是 0(子), 1(丑)，那就直接用
    return fixIndex(startIndex + (rule.direction * shiftSteps));
  }

  int _getShiftValue(String key, Boundary boundary) {
    switch (key) {
      case 'hour':
      case 'hour_index':
        // 时辰通常不分阴阳历，都是地支索引
        return date.lunar.timeIndex;

      case 'month':
        if (boundary == Boundary.solar) {
          // 节气月：直接用八字月支索引 (寅=0, 卯=1...)
          // 注意：BaZi 的 monthZhi.index 是 2(寅)...
          // 我们需要把它转成 0-based 步数
          // 通常寅月是正月，所以 index - 2
          int idx = date.bazi.month.zhi.index - 2;
          return idx < 0 ? idx + 12 : idx;
        } else {
          // 农历月：1-12 -> 0-11
          // ✅ Fix: 加上 .abs() 解决闰月(负数)崩溃问题
          return date.lunar.month.abs() - 1;
        }

      case 'day':
        if (boundary == Boundary.solar) {
          // 节气日：用你之前加的 solarDay (节气后第几天)
          return date.solarDay - 1;
        } else {
          // 农历日：初一 -> 0
          return date.lunar.day - 1;
        }

      default:
        return 0;
    }
  }
}
