import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

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
          break;
        case LeapMonthRule.splitAt15:
          effectiveMonth += date.lunar.day > 15 ? 1 : 0;
          break;
      }
    }
    // step1:安放命身宫
    final (int lifeIndex, int bodyIndex) = _calLifeAndBodyPalace(
      date,
      effectiveMonth,
    );
    //step2: 五虎遁安放干支
    // 1. 核心口诀：甲己之年丙作首...
    // 我们要算出“寅宫”（地支索引2）的天干是谁
    // TianGan.jia.index 是 0

    final method = date.options.wuHuDunBasedOn; //获取配置，防止有变态流派五虎遁要按照节气算
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
    _assignPalaceStems(yearGanIndex, palaces);

    //step3:定五行局

    FiveElementBureau elementBureau = _calculateBureau(
      palaces[lifeIndex].stem!,
      palaces[lifeIndex].branch,
    );

    return ZiWeiPlate(
      palaces: palaces, // 这里面已经是带天干的了
      originMingIndex: lifeIndex, // 命宫位置
      bodyPalaceIndex: bodyIndex, // 身宫位置
      elementBureau: elementBureau, // 五行局
    );
  }

  static (int, int) _calLifeAndBodyPalace(ZiweiDate date, int effectiveMonth) {
    const int yinOffset = 2; //寅宫位置锁死是2
    int monthOffset = effectiveMonth - 1; // 语义：相对于“正月”的偏移量
    int hourStep = date.lunar.timeIndex; // 子时=0
    int lifeIndex = (yinOffset + monthOffset - hourStep) % 12;
    if (lifeIndex < 0) lifeIndex += 12;
    //寅起正月，顺数至生月，顺数生时为身宫。
    int bodyIndex = (yinOffset + monthOffset + hourStep) % 12;
    if (bodyIndex < 0) bodyIndex += 12;
    return (lifeIndex, bodyIndex);
  }

  static void _assignPalaceStems(int yearGanIndex, List<Palace> palaces) {
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
  }

  static FiveElementBureau _calculateBureau(TianGan stem, DiZhi branch) {
    //ai说可以这么算
    // 1. 天干系数 (每两个一组)
    // 甲乙=0, 丙丁=1, 戊己=2, 庚辛=3, 壬癸=4
    final stemScore = stem.index ~/ 2;
    // 2. 地支系数 (每两个一组，隔着来)
    // 子丑/午未=0, 寅卯/申酉=1, 辰巳/戌亥=2
    final branchScore = (branch.index ~/ 2) % 3;
    // 3. 核心公式：加起来求余
    final result = (stemScore + branchScore) % 5;
    switch (result) {
      case 0:
        return FiveElementBureau.metal4;
      case 1:
        return FiveElementBureau.water2;
      case 2:
        return FiveElementBureau.fire6;
      case 3:
        return FiveElementBureau.earth5;
      case 4:
        return FiveElementBureau.wood3;
      default:
        throw StateError('Invalid bureau remainder: $result');
    }
  }
}
