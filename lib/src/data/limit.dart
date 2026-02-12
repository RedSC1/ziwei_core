import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/consts.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

abstract class FlowLimit {
  GanZhi get ganzhi;
  int get index {
    return ganzhi.zhi.index;
  }
}

class Decade extends FlowLimit {
  @override
  final GanZhi ganzhi;

  final int startTime;
  final int endTime;
  final PalaceRole role;

  static List<int> childHoodDecadeOffsetTable = [0, 4, 5, 2, 10, 8];

  Decade(this.ganzhi, this.startTime, this.endTime, this.role);

  factory Decade.createByYear(int year, ZiWeiPlate plate) {
    // 1. 基础参数计算
    int bureauNum = plate.elementBureau.number;
    int firstDecadeYear = getStartDecadeYear(plate);
    int mingIndex = plate.originMingIndex;

    // 计算有效出生年 (用于定阴阳 & 算虚岁)
    int effectiveBirthYear = getEffectiveBirthYear(plate);

    // 计算虚岁: year - birth + 1
    int virtualAge = year - effectiveBirthYear + 1;
    if (virtualAge < 1) {
      throw ArgumentError("查询年份 $year 早于出生年份 $effectiveBirthYear");
    }

    // 确定顺逆 (阴阳 x 性别)
    // 年干索引: (year - 4) % 10. 0=甲(阳), 1=乙(阴)...
    int stemIndex = (effectiveBirthYear - 4) % 10;
    if (stemIndex < 0) stemIndex += 10;

    bool isYangYear = stemIndex.isEven;
    bool isMale = plate.date.gender == Gender.male;

    // 顺行条件：(阳男) || (阴女) -> T (Clockwise)
    bool isClockwise = (isYangYear == isMale);

    int startAge;
    int endAge;
    int targetPalaceIndex;

    // 2. 分支逻辑：童限 vs 大限
    if (year < firstDecadeYear) {
      // === 童限 (Childhood) ===
      // 童限通常按1年1宫算，Role为这一年的“小限/童限”角色
      startAge = virtualAge;
      endAge = virtualAge;

      ChildhoodRole rule = plate.date.options.childhoodRule;

      if (rule == ChildhoodRole.skip) {
        // [流派A]: 口诀跳跃派 (一命二財三疾厄...)
        // 直接查表定位置，不涉及顺逆步数
        // 1岁=命(offset0), 2岁=财(offset4), 3岁=疾(offset5)...
        int tableIndex = virtualAge - 1;
        int offset = 0;
        // 防止数组越界 (虽然理论上童限不会超过6岁)
        if (tableIndex >= 0 && tableIndex < childHoodDecadeOffsetTable.length) {
          offset = childHoodDecadeOffsetTable[tableIndex];
        }

        // 目标 = 命宫 - Offset (逆时针)
        targetPalaceIndex = ZiweiConsts.fixIndex(mingIndex - offset);
      } else {
        // [流派B]: 常规顺延派 (Regular)
        // 从命宫起，按阳男阴女顺逆规则，一年走一格
        // 1岁: steps=0 (在命宫)
        // 2岁: steps=1 (下一宫)
        int steps = virtualAge - 1;

        if (isClockwise) {
          targetPalaceIndex = ZiweiConsts.fixIndex(mingIndex + steps);
        } else {
          targetPalaceIndex = ZiweiConsts.fixIndex(mingIndex - steps);
        }
      }
    } else {
      // === 大限 (Decade) ===

      // Index 0-based: 0=第一大限(命宫), 1=第二大限...
      int decadeIndex = (year - firstDecadeYear) ~/ 10;

      startAge = bureauNum + decadeIndex * 10;
      endAge = startAge + 9;

      // 大限起跑点是【命宫】
      int mingIndex = plate.originMingIndex;
      int steps = decadeIndex;

      if (isClockwise) {
        targetPalaceIndex = ZiweiConsts.fixIndex(mingIndex + steps);
      } else {
        targetPalaceIndex = ZiweiConsts.fixIndex(mingIndex - steps);
      }
    }

    // 3. 组装返回
    Palace targetPalace = plate.palaces[targetPalaceIndex];
    // 获取这个宫位在【原盘】中的角色
    PalaceRole role = plate.getRole(ZiweiScope.origin, targetPalaceIndex);

    return Decade(targetPalace.ganzhi, startAge, endAge, role);
  }

  /// 获取“有效出生年” (Effective Birth Year)
  ///
  /// 这是紫微斗数排盘的基准年份。
  /// - 农历流派：直接返回农历年。
  /// - 节气流派：如果在立春前出生，算作上一年。
  static int getEffectiveBirthYear(ZiWeiPlate plate) {
    if (plate.date.options.flowLimitBasedOn == Boundary.lunar) {
      // 农历流派：基准是农历年 (比如 2026)
      return plate.date.lunar.year;
    } else {
      // 节气流派：看立春
      int solarYear = plate.date.solar.year;

      // 1. 算出公历年对应的标准地支索引 (2026 -> 6)
      int standardBranchIndex = ZiweiConsts.fixIndex(solarYear - 4);

      // 2. 获取八字实际地支索引
      int baziBranchIndex = plate.date.bazi.year.zhi.index;

      // 3. 对暗号
      if (standardBranchIndex != baziBranchIndex) {
        // 对不上 (通常是立春前)，说明还在上一年
        return solarYear - 1;
      } else {
        return solarYear;
      }
    }
  }

  static int getStartDecadeYear(ZiWeiPlate plate) {
    // 1. 获取有效出生年
    int effectiveBirthYear = getEffectiveBirthYear(plate);

    // 2. 加上局数偏移 (虚岁体系: 出生即1岁，所以要减1)
    // 比如水二局(2岁起运)，2026出生 -> 2026(1岁), 2027(2岁/起运)
    // Start = 2026 + (2 - 1) = 2027
    return effectiveBirthYear + (plate.elementBureau.number - 1);
  }
}

class FlowYear extends FlowLimit {
  @override
  final GanZhi ganzhi;
  final int year;
  final PalaceRole role;
  FlowYear(this.ganzhi, this.year, this.role);
  factory FlowYear.createByYear(int year, ZiWeiPlate plate) {
    int placeIndex = ZiweiConsts.fixIndex(year + 8);
    TianGan stem = TianGan.values[((year + 6) % 10 + 10) % 10];
    DiZhi branch = DiZhi.values[placeIndex];
    PalaceRole r = plate.getRole(ZiweiScope.origin, placeIndex);
    return FlowYear(GanZhi(stem, branch), year, r);
  }
}

class FlowMonth extends FlowLimit {
  @override
  final GanZhi ganzhi;
  final int month; // 农历月份 (1-12)
  final PalaceRole role;

  FlowMonth(this.ganzhi, this.month, this.role);

  factory FlowMonth.create(int month, int year, ZiWeiPlate plate) {
    // 1. 获取流年参数
    // 流年命宫 (地支)
    int yearBranchIndex = ZiweiConsts.fixIndex(year + 8);
    // 流年天干 (用于五虎遁)
    int yearStemIndex = (year + 6) % 10;

    // 2. 计算【流年斗君】 (正月所在的宫位索引)
    // 规则：流年命宫起，逆数生月，顺数生时
    // (注意：这里用的是农历生月和生时索引)
    int birthMonth = plate.date.lunar.month;
    int birthTimeIndex = plate.date.lunar.timeIndex;

    // 逆数月: - (month - 1)
    // 顺数时: + (time - 0) -> 子时是0，如果不减1的话...
    // 口诀通常是：逆数到生月，再从生月那个位置顺数到生时。
    // 比如：流年命宫在子(0)，生月1，生时子(0) -> 0 - 0 + 0 = 0
    // 公式：Base - (m-1) + t
    int douJunIndex = yearBranchIndex - (birthMonth - 1) + birthTimeIndex;
    douJunIndex = ZiweiConsts.fixIndex(douJunIndex);

    // 3. 计算当前流月的宫位索引
    // 正月(1)在斗君，二月(2)在斗君+1...
    int targetPlaceIndex = ZiweiConsts.fixIndex(douJunIndex + (month - 1));

    // 4. 计算流月天干 (五虎遁)
    int startTigerStemIndex = (yearStemIndex % 5) * 2 + 2;
    int monthStemIndex = (startTigerStemIndex + (month - 1)) % 10;
    if (monthStemIndex < 0) monthStemIndex += 10;

    TianGan monthStem = TianGan.values[monthStemIndex];

    // ⚠️ 修正：必须使用【宫位地支】作为 GanZhi 的地支，否则 index 属性会指向错误的位置
    // 之前的代码用了 (month+1)%12 (时间地支)，这是不对的。
    DiZhi palaceBranch = DiZhi.values[targetPlaceIndex];

    // 5. 获取角色
    PalaceRole r = plate.getRole(ZiweiScope.origin, targetPlaceIndex);

    // 构造混合干支 (Hybrid GanZhi): 时间天干 + 宫位地支
    return FlowMonth(GanZhi(monthStem, palaceBranch), month, r);
  }
}

class SmallLimit extends FlowLimit {
  @override
  final GanZhi ganzhi;
  final int age; // 虚岁
  final PalaceRole role;

  SmallLimit(this.ganzhi, this.age, this.role);

  factory SmallLimit.create(int virtualAge, ZiWeiPlate plate) {
    // 1. 确定起跑点 (1岁位置)
    // 规则：三合局墓库的对冲位
    // 申(8)子(0)辰(4) -> 水局 -> 墓在辰(4) -> 冲位是戌(10)
    // 寅(2)午(6)戌(10) -> 火局 -> 墓在戌(10) -> 冲位是辰(4)
    // 亥(11)卯(3)未(7) -> 木局 -> 墓在未(7) -> 冲位是丑(1)
    // 巳(5)酉(9)丑(1) -> 金局 -> 墓在丑(1) -> 冲位是未(7)

    int birthBranchIndex = plate.date.bazi.year.zhi.index;
    int startPalaceIndex;

    // 模4余数分类:
    // 子(0)%4=0, 辰(4)%4=0, 申(8)%4=0 -> Group 0 -> Target 10
    // 丑(1)%4=1, 巳(5)%4=1, 酉(9)%4=1 -> Group 1 -> Target 7
    // 寅(2)%4=2, 午(6)%4=2, 戌(10)%4=2 -> Group 2 -> Target 4
    // 卯(3)%4=3, 未(7)%4=3, 亥(11)%4=3 -> Group 3 -> Target 1

    switch (birthBranchIndex % 4) {
      case 0:
        startPalaceIndex = 10; // 戌
        break;
      case 1:
        startPalaceIndex = 7; // 未
        break;
      case 2:
        startPalaceIndex = 4; // 辰
        break;
      case 3:
      default:
        startPalaceIndex = 1; // 丑
        break;
    }

    // 2. 确定顺逆 (主流：男顺女逆)
    // 这里的规则比较统一，通常就是死板的男顺女逆
    bool isClockwise = (plate.date.gender == Gender.male);

    // 3. 移动到当前岁数
    int steps = virtualAge - 1;
    int targetIndex;

    if (isClockwise) {
      targetIndex = ZiweiConsts.fixIndex(startPalaceIndex + steps);
    } else {
      targetIndex = ZiweiConsts.fixIndex(startPalaceIndex - steps);
    }

    // 4. 组装
    // 小限的天干通常也是借用宫干（原盘宫位的天干）
    Palace targetPalace = plate.palaces[targetIndex];
    PalaceRole r = plate.getRole(ZiweiScope.origin, targetIndex);

    // 注意：这里用的是 targetPalace.ganzhi，也就是原盘那个宫位的干支
    return SmallLimit(targetPalace.ganzhi, virtualAge, r);
  }
}

/// 流日 (Flow Day)
///
/// **定位逻辑**：
/// 1. 起点：以流月宫为初一。
/// 2. 移动：顺数到当日 (day - 1)。
///
/// **四化逻辑**：
/// 使用 **当日的天干** (通常由历法传入，因为日柱涉及到大小月/闰年，纯逻辑推算太复杂)。
class FlowDay extends FlowLimit {
  @override
  final GanZhi ganzhi;
  final int day; // 农历初几
  final PalaceRole role;

  FlowDay(this.ganzhi, this.day, this.role);

  factory FlowDay.create(
    int day,
    GanZhi dayGanZhi,
    FlowMonth flowMonth,
    ZiWeiPlate plate,
  ) {
    // 1. 确定流日宫位 (Location)
    // 规则：从流月宫位起初一，顺行
    int monthIndex = flowMonth.index;
    int targetIndex = ZiweiConsts.fixIndex(monthIndex + (day - 1));

    // 2. 获取角色
    PalaceRole r = plate.getRole(ZiweiScope.origin, targetIndex);

    // 3. 构造混合干支 (Hybrid GanZhi)
    // ⚠️ 关键点：
    // - 天干(Gan) 使用传入的【日干】 -> 用于四化 (Si Hua)
    // - 地支(Zhi) 使用算出的【宫位】 -> 用于定位 (Location/Index)
    // 如果直接用 dayGanZhi，那 index 就会变成“子丑寅卯”的日子索引，而不是宫位索引。
    DiZhi palaceBranch = DiZhi.values[targetIndex];
    GanZhi hybridGanZhi = GanZhi(dayGanZhi.gan, palaceBranch);

    return FlowDay(hybridGanZhi, day, r);
  }
}

/// 流时 (Flow Hour)
///
/// **定位逻辑**：
/// 1. 起点：以流日宫为子时。
/// 2. 移动：顺数到当时 (hourIndex)。
///
/// **四化逻辑**：
/// 使用 **五鼠遁 (Wu Zi Dun)** 根据日干推算时干。
class FlowHour extends FlowLimit {
  @override
  final GanZhi ganzhi;
  final int hourIndex; // 0=子, 1=丑...
  final PalaceRole role;

  FlowHour(this.ganzhi, this.hourIndex, this.role);

  factory FlowHour.create(int hourIndex, FlowDay flowDay, ZiWeiPlate plate) {
    // 1. 确定流时宫位 (Location)
    // 规则：从流日宫位起子时，顺行
    int dayIndex = flowDay.index;
    int targetIndex = ZiweiConsts.fixIndex(dayIndex + hourIndex);

    // 2. 确定流时天干 (五鼠遁)
    // 歌诀：甲己还加甲，乙庚丙作初...
    // 这里的 dayStemIndex 是 0-9
    int dayStemIndex = flowDay.ganzhi.gan.index;

    // 子时天干 = (日干idx % 5) * 2
    // 比如 甲(0) -> (0%5)*2 = 0(甲子)
    // 比如 乙(1) -> (1%5)*2 = 2(丙子)
    int startRatStemIndex = (dayStemIndex % 5) * 2;

    // 目标天干 (Time Stem)
    int targetStemIndex = (startRatStemIndex + hourIndex) % 10;

    TianGan hourStem = TianGan.values[targetStemIndex];
    DiZhi palaceBranch = DiZhi.values[targetIndex]; // ⚠️ 必须用宫位地支，不能用 hourIndex

    // 3. 获取角色
    PalaceRole r = plate.getRole(ZiweiScope.origin, targetIndex);

    return FlowHour(GanZhi(hourStem, palaceBranch), hourIndex, r);
  }
}

/// 时间切片上下文 (Time Slicing Context)
///
/// 这是一个“时间胶囊”，封装了从原盘到大限、流年、流月、流日、流时的所有状态。
/// Engine 会根据这个 Context 来计算星星的动态变化（四化、流曜）。
class LimitContext {
  /// 原始命盘 (Base Plate)
  final ZiWeiPlate plate;

  /// 大限 (Decade) - 10年运
  final Decade? decade;

  /// 小限 (Small Limit) - 1年运 (与流年互参)
  final SmallLimit? smallLimit;

  /// 流年 (Flow Year) - 1年运
  final FlowYear? year;

  /// 流月 (Flow Month) - 1月运
  final FlowMonth? month;

  /// 流日 (Flow Day) - 1日运
  final FlowDay? day;

  /// 流时 (Flow Hour) - 1时运
  final FlowHour? hour;

  const LimitContext({
    required this.plate,
    this.decade,
    this.smallLimit,
    this.year,
    this.month,
    this.day,
    this.hour,
  });

  /// 便捷构造：只看本命 (Original)
  factory LimitContext.original(ZiWeiPlate plate) {
    return LimitContext(plate: plate);
  }

  /// 检查是否包含某一层级
  bool get hasDecade => decade != null;
  bool get hasYear => year != null;
  bool get hasMonth => month != null;
  bool get hasDay => day != null;
  bool get hasHour => hour != null;

  /// 创建副本 (Copy With)
  /// 允许你只更新其中某一层，其他层保持不变 (复用)
  LimitContext copyWith({
    ZiWeiPlate? plate,
    Decade? decade,
    SmallLimit? smallLimit,
    FlowYear? year,
    FlowMonth? month,
    FlowDay? day,
    FlowHour? hour,
  }) {
    return LimitContext(
      plate: plate ?? this.plate,
      decade: decade ?? this.decade,
      smallLimit: smallLimit ?? this.smallLimit,
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      hour: hour ?? this.hour,
    );
  }

  /// 剥离某一层级 (Remove Layer)
  /// 返回一个新的 Context，其中指定的层级被移除 (置为 null)
  LimitContext remove(ZiweiScope scope) {
    if (scope == ZiweiScope.origin) {
      return LimitContext(plate: plate);
    }
    return LimitContext(
      plate: plate,
      decade: scope == ZiweiScope.decade ? null : decade,
      smallLimit: scope == ZiweiScope.smallLimit ? null : smallLimit,
      year: scope == ZiweiScope.year ? null : year,
      month: scope == ZiweiScope.month ? null : month,
      day: scope == ZiweiScope.day ? null : day,
      hour: scope == ZiweiScope.hour ? null : hour,
    );
  }

  @override
  String toString() {
    List<String> parts = [];
    if (decade != null) parts.add("大限: ${decade!.ganzhi}");
    if (year != null) parts.add("流年: ${year!.ganzhi} (${year!.year})");
    if (month != null) parts.add("流月: ${month!.ganzhi} (${month!.month}月)");
    if (day != null) parts.add("流日: ${day!.ganzhi} (${day!.day}日)");
    if (hour != null) parts.add("流时: ${hour!.ganzhi} (${hour!.hourIndex}时)");
    return parts.isEmpty ? "原盘状态" : parts.join(" | ");
  }
}

/// 时光机 (Time Machine)
///
/// 这是一个辅助工厂类，用于快速生成 [LimitContext]。
/// 它支持“不完整的时间”，比如只传入年份，就会只生成到流年层级。
class TimeMachine {
  /// 穿越到指定时间
  static LimitContext travel(
    ZiWeiPlate plate, {
    int? year,
    int? month,
    int? day,
    int? hourIndex,
    GanZhi? dayGanZhi, // 如果计算流日，必须传入当日干支
  }) {
    Decade? decade;
    SmallLimit? smallLimit;
    FlowYear? flowYear;
    FlowMonth? flowMonth;
    FlowDay? flowDay;
    FlowHour? flowHour;

    // 1. 如果有年份，计算大限、小限、流年
    if (year != null) {
      // 大限/童限 (内部会自动处理童限逻辑)
      decade = Decade.createByYear(year, plate);

      // 小限 (需计算虚岁)
      // ⚠️ 严谨算法：直接获取有效出生年 (不再需要倒推)
      int effectiveBirthYear = Decade.getEffectiveBirthYear(plate);

      int virtualAge = year - effectiveBirthYear + 1;
      smallLimit = SmallLimit.create(virtualAge, plate);

      // 流年
      flowYear = FlowYear.createByYear(year, plate);
    }

    // 2. 如果有月份 (且有流年)，计算流月
    if (year != null && month != null) {
      flowMonth = FlowMonth.create(month, year, plate);
    }

    // 3. 如果有日期 (且有流月)，计算流日
    // 注意：必须提供日干支 (dayGanZhi)，因为纯数字无法推算日干
    if (flowMonth != null && day != null && dayGanZhi != null) {
      flowDay = FlowDay.create(day, dayGanZhi, flowMonth, plate);
    }

    // 4. 如果有时辰 (且有流日)，计算流时
    if (flowDay != null && hourIndex != null) {
      flowHour = FlowHour.create(hourIndex, flowDay, plate);
    }

    return LimitContext(
      plate: plate,
      decade: decade,
      smallLimit: smallLimit,
      year: flowYear,
      month: flowMonth,
      day: flowDay,
      hour: flowHour,
    );
  }
}
