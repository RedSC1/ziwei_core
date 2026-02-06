import 'package:ziwei_core/src/time/ziwei_date.dart';

import '../enums/config_enums.dart';
import 'star.dart'; // 引用星星定义

class Palace {
  // 1. 地支索引 (0=子, 1=丑 ... 11=亥) - 这是死的，初始化后不可变
  final int index;

  // 2. 对应的地支枚举 (方便调试和显示，自动根据index算出来)
  DiZhi get branch => DiZhi.values[index];

  // 3. 宫干 (天干) - 活的，排盘时通过“五虎遁”算出来填进去
  TianGan? stem;

  // 5. 住在这里的星星列表 - 活的，安星时一颗颗塞进去
  List<Star> stars = [];

  // --- 构造函数 ---
  // 创建时只需要指定它是第几个格子(index)，其他的后面填
  Palace(this.index, {this.stem});

  // --- 辅助方法 ---

  // 往宫里安一颗星
  void addStar(Star star) {
    stars.add(star);
  }

  // 方便调试打印看结果，不仅看地支，还能看到里面的星星
  @override
  String toString() {
    // 效果：[丙子] 命宫: Star(紫微), Star(天府)
    String stemStr = stem?.label ?? "?"; // 如果没算出来显示?
    String branchStr = branch.label;
    return "[$stemStr$branchStr]: $stars";
  }
}

class ZiWeiPlate {
  final List<Palace> palaces;
  final int originMingIndex;
  final int bodyPalaceIndex;

  int? decadeMingIndex;
  int? yearMingIndex;
  int? monthMingIndex;
  int? dayMingIndex;
  int? hourMingIndex;
  ZiWeiPlate({
    required this.palaces,
    required this.originMingIndex,
    required this.bodyPalaceIndex,
    this.decadeMingIndex,
    this.yearMingIndex,
    this.monthMingIndex,
    this.dayMingIndex,
    this.hourMingIndex,
  });
}

class ZiWeiEngine {
  static ZiWeiPlate calculate(ZiweiDate date) {
    //(0=子, 1=丑 ... 11=亥)
    List<Palace> palaces = List.generate(12, (i) => Palace(i));

    final calendarOptions = date.options; //获取日历选项
    int effectiveMonth =
        date.lunar.month; //effectiveMonth是指实际计算的月份，会因为闰月的处理方式不一样
    if (date.lunar.isLeap) {
      switch (calendarOptions.leapRule) {
        case LeapMonthRule.asNext:
          effectiveMonth++;
          break;
        case LeapMonthRule.asPrevious:
          effectiveMonth--;
          break;
        case LeapMonthRule.splitAt15:
          effectiveMonth += date.lunar.day > 15 ? 1 : 0;
          break;
      }
    }
    // step1:安放命身宫
    //寅起正月，顺数至生月，逆数生时为命宫。
    const int yinOffset = 2; //寅宫位置锁死是2
    int monthOffset = effectiveMonth - 1; // 语义：相对于“正月”的偏移量
    int hourStep = date.lunar.timeIndex; // 子时=0
    int lifeIndex = (yinOffset + monthOffset - hourStep) % 12;
    if (lifeIndex < 0) lifeIndex += 12;
    //寅起正月，顺数至生月，顺数生时为身宫。
    int bodyIndex = (yinOffset + monthOffset + hourStep) % 12;
    if (bodyIndex < 0) bodyIndex += 12;

    //step2: 五虎遁安放干支
    // 1. 核心口诀：甲己之年丙作首...
    // 我们要算出“寅宫”（地支索引2）的天干是谁
    // TianGan.jia.index 是 0
    // 获取配置
    final method = date.options.wuHuDunBasedOn; //防止有变态流派五虎遁要按照节气算
    int yearGanIndex;

    if (method == Boundary.solar) {
      // 1. 变态流派：按节气（立春）算
      // 直接取八字里的年干 (lunar库已经帮你算好了立春逻辑)
      yearGanIndex = date.bazi.year.gan.index;
    } else {
      // 2. 主流流派：按春节（农历年）算
      int offset = (date.lunar.year - 4) % 10;
      yearGanIndex = offset < 0 ? offset + 10 : offset;
    }

    // 五虎遁公式：(年干索引 % 5) * 2 + 2
    // 原理：
    // 甲(0)、己(5) -> 余0 -> *2+2 = 2 (丙) -> 丙寅
    // 乙(1)、庚(6) -> 余1 -> *2+2 = 4 (戊) -> 戊寅
    int startStemIndex = (yearGanIndex % 5) * 2 + 2;

    // 2. 顺时针填满 12 个宫位
    for (int i = 0; i < 12; i++) {
      // 按照寅宫(2)开始数
      // 这里的 i 代表从寅开始走的步数
      // 实际宫位索引 (0-11)
      int palaceIndex = (2 + i) % 12;

      // 计算宫干索引 (0-9)，超过10要回头
      int stemIndex = (startStemIndex + i) % 10;

      // 赋值！
      palaces[palaceIndex].stem = TianGan.values[stemIndex];
    }

    return ZiWeiPlate(
      palaces: palaces, // 这里面已经是带天干的了
      originMingIndex: lifeIndex, // 刚才算的命宫位置
      bodyPalaceIndex: bodyIndex, // 刚才算的身宫位置
    );
  }
}
