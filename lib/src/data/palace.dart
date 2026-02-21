import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/ziwei_core.dart';

import 'star.dart'; // 引用星星定义

class Palace {
  // 1. 地支索引 (0=子, 1=丑 ... 11=亥) - 这是死的，初始化后不可变
  final int index;

  // 2. 对应的地支枚举 (方便调试和显示，自动根据index算出来)
  DiZhi get branch => DiZhi.values[index];

  // 3. 宫干 (天干) - 活的，排盘时通过“五虎遁”算出来填进去
  TianGan? stem;

  // 5. 住在这里的星星列表 - 活的，安星时一颗颗塞进去
  //List<Star> stars = [];
  Map<StarType, List<Star>> stars = {};

  // --- 构造函数 ---
  // 创建时只需要指定它是第几个格子(index)，其他的后面填
  Palace(this.index, {this.stem});

  factory Palace.fromDiZhi(DiZhi branch, {TianGan? stem}) {
    return Palace(branch.index, stem: stem);
  }

  GanZhi get ganzhi {
    if (stem == null) {
      throw Exception("还没排盘就算大运？？？");
    }
    return GanZhi(stem!, branch);
  }

  // --- 辅助方法 ---

  // 往宫里安一颗星
  void addStar(Star star) {
  // 1. 如果 stars[star.type] 还没创建，就先创建一个空的 List []
  // 2. 然后直接把星星 add 进去
    stars.putIfAbsent(star.type, () => []).add(star);
  }
  /// 🚀 深拷贝 (Deep Copy)
  /// 用于大限/流年排盘，防止污染原盘
 Palace clone() {
  return Palace(index, stem: stem)
    ..stars.addAll(
      // 1. 遍历旧 Map 的每一个“抽屉” (StarType -> List<Star>)
      stars.map((type, starList) => MapEntry(
            type,
            // 2. 让抽屉里的每一颗星星都自我克隆，并生成一个新的 List
            starList.map((s) => s.clone()).toList(),
          )),
    );
}

  // 方便调试打印看结果，不仅看地支，还能看到里面的星星
  @override
  String toString() {
    // 效果：[丙子] 命宫: Star(紫微), Star(天府)
    String stemStr = stem?.label ?? "?"; // 如果没算出来显示?
    String branchStr = branch.label;
    return "[$stemStr$branchStr]: $stars";
  }


  Star? findStar(String key, {StarType? type}) {
    // 1. 如果指定了类型，直接精准打击
    if (type != null) {
      final list = stars[type];
      if (list == null) return null;
      try {
        return list.firstWhere((s) => s.key == key);
      } catch (_) {
        return null;
      }
    }

    // 2. 如果没给类型，再全盘扫描（复用上面的逻辑）
    for (var starList in stars.values) {
      for (var star in starList) {
        if (star.key == key) return star;
      }
    }
    return null;
  }
  bool hasStar(String key, {StarType? type}) {
  // 1. 如果你给了类型，我直接开那个抽屉，瞬发！
    if (type != null) {
      return stars[type]?.any((s) => s.key == key) ?? false;
    }
    // 2. 如果没给类型，我再全盘扫描
    return stars.values.any((list) => list.any((s) => s.key == key));
  }

  // 在 Palace 类内部
  List<Star> get allStars => stars.values.expand((e) => e).toList();
}
