import 'package:ziwei_core/ziwei_core.dart';

// 引用星星定义

/// **十二地支宫位 (Palace)**
///
/// 紫微斗数排盘中的“格子”。总共 12 个，每个宫位都有固定的地支坐标，并容纳不同的星曜与天干。
class Palace {
  /// 宫位地支的绝对物理索引 (0=子, 1=丑 ... 11=亥)
  /// 此为只读固定坐标，初始化后不可变。
  final int index;

  /// 该宫位对应的地支枚举 (根据 index 推演)，方便跨模块做地支数学计算
  DiZhi get branch => DiZhi.values[index];

  /// 该宫位被分配的天干 (宫干)
  ///
  /// 这是活属性，在排盘初期根据命造年份使用“五虎遁”口诀推算填入。
  TianGan? stem;

  /// 住在这个宫位格子里所有的星星集合
  ///
  /// 根据星曜的类型分门别类 (如主星、辅曜、杂曜等)，装安星时逐一置入。
  Map<StarType, List<Star>> stars = {};

  /// 标准构造器
  ///
  /// - [index] 物理地支索引 (0-11)
  /// - [stem] (可选) 直接注入宫干
  Palace(this.index, {this.stem});

  /// 地支枚举构造器
  ///
  /// - [branch] 地支枚举
  /// - [stem] (可选) 直接注入宫干
  factory Palace.fromDiZhi(DiZhi branch, {TianGan? stem}) {
    return Palace(branch.index, stem: stem);
  }

  /// 封装宫位本身的干支对象
  GanZhi get ganzhi {
    if (stem == null) {
      throw StateError("宫位天干尚未推算，无法获取 GanZhi 对象。请确保已执行完整的原局排盘。");
    }
    return GanZhi(stem!, branch);
  }

  // --- 辅助方法 ---

  /// 往当前宫位安插一颗星星
  ///
  /// - [star] 星体实例 (StaticStar 或 FlowStar)
  void addStar(Star star) {
    stars.putIfAbsent(star.type, () => []).add(star);
  }

  /// 🚀 原型深拷贝 (Deep Copy)
  ///
  /// 将该宫位格子以及内部的所有星星都进行引用剥离的克隆，
  /// 这是底层能够无损支撑各个大限与流年切片计算“星耀四化变化”的核心机制。
  Palace clone() {
    return Palace(index, stem: stem)
      ..stars.addAll(
        stars.map(
          (type, starList) =>
              MapEntry(type, starList.map((s) => s.clone()).toList()),
        ),
      );
  }

  /// 控制台调试格式化
  @override
  String toString() {
    String stemStr = stem?.label ?? "?";
    String branchStr = branch.label;
    return "[$stemStr$branchStr]: $stars";
  }

  /// 在该宫位中检索指定的星星实例对象
  ///
  /// - [key] 星星配置中的标识键 (如 "ziwei")
  /// - [type] (可选) 指定星星大类来加速检索，避免全盘扫表
  Star? findStar(String key, {StarType? type}) {
    if (type != null) {
      final list = stars[type];
      if (list == null) return null;
      try {
        return list.firstWhere((s) => s.key == key);
      } catch (_) {
        return null;
      }
    }

    for (var starList in stars.values) {
      for (var star in starList) {
        if (star.key == key) return star;
      }
    }
    return null;
  }

  /// 快速探询该宫位中是否驻扎了某颗星
  ///
  /// - [key] 星星标识键
  /// - [type] (可选) 加速探询所在的星星大群类
  bool hasStar(String key, {StarType? type}) {
    if (type != null) {
      return stars[type]?.any((s) => s.key == key) ?? false;
    }
    return stars.values.any((list) => list.any((s) => s.key == key));
  }

  /// 提取宫内一切星星的扁平数组列表
  List<Star> get allStars => stars.values.expand((e) => e).toList();
}
