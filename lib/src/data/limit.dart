import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/consts.dart';
import 'package:ziwei_core/src/enums/scope.dart';

abstract class FlowLimit {
  GanZhi get ganzhi;
  int get index {
    return ganzhi.zhi.index;
  }
}

class Decade extends FlowLimit {
  @override
  final GanZhi ganzhi;
  final int startTime; // 起始岁数 (如 2 岁)
  final int endTime; // 结束岁数 (如 11 岁)
  final PalaceRole role;

  static List<int> childHoodDecadeOffsetTable = [0, 4, 5, 2, 10, 8];

  Decade(this.ganzhi, this.startTime, this.endTime, this.role);

  /// 🚀 index 1 就是第一大限
  factory Decade.fromIndex(int index, ZiWeiPlate plate) {
    if (index <= 0) {
      throw ArgumentError("大限索引必须从 1 开始。如果要看童限，请使用 Decade.childhood()");
    }

    // 内部计算时，自动把 1-based 转回 0-based 偏移量
    final int offset = index - 1;

    final birthYear = getEffectiveBirthYear(plate);
    final mingIndex = plate.originMingIndex;
    final bureauNum = plate.elementBureau.number;

    // 计算顺逆
    int stemIndex = (birthYear - 4) % 10;
    if (stemIndex < 0) stemIndex += 10;
    bool isClockwise = (stemIndex.isEven == (plate.date.gender == Gender.male));

    // 计算区间与宫位
    int startAge = bureauNum + (offset * 10);
    int endAge = startAge + 9;
    int targetPalaceIndex = isClockwise
        ? ZiweiConsts.fixIndex(mingIndex + offset)
        : ZiweiConsts.fixIndex(mingIndex - offset);

    return Decade(
      plate.palaces[targetPalaceIndex].ganzhi,
      startAge,
      endAge,
      plate.getRole(ZiweiScope.origin, targetPalaceIndex),
    );
  }

  /// 🔍 [路由层] 找到包含该年份的大限或童限
  factory Decade.createByYear(int year, ZiWeiPlate plate) {
    int startDecadeYear = getStartDecadeYear(plate);

    // 1. 逻辑分流：是否尚未起运 (进入童限)
    if (year < startDecadeYear) {
      // 这里的 index 绑定为 0
      int virtualAge = year - Decade.getEffectiveBirthYear(plate) + 1;
      return Decade.createChildhood(virtualAge, plate);
    }
    // 加上 1，确保起运后的第一个十年对应 Index 1
    int decadeIndex = ((year - startDecadeYear) ~/ 10) + 1;

    // 此时 decadeIndex 的范围是 1 ~ 12
    return Decade.fromIndex(decadeIndex, plate);
  }

  // --- 辅助私有方法与静态工具 ---

  /// 👶 专门处理“未起运”前的童限逻辑
  static Decade createChildhood(int year, ZiWeiPlate plate) {
    int birthYear = getEffectiveBirthYear(plate);
    int virtualAge = year - birthYear + 1;
    int mingIndex = plate.originMingIndex;

    // 计算顺逆
    int stemIndex = (birthYear - 4) % 10;
    if (stemIndex < 0) stemIndex += 10;
    bool isClockwise = (stemIndex.isEven == (plate.date.gender == Gender.male));

    int targetPalaceIndex;
    ChildhoodRole rule = plate.date.options.childhoodRule;

    if (rule == ChildhoodRole.skip) {
      // 口诀跳跃派
      int offset =
          (virtualAge >= 1 && virtualAge <= childHoodDecadeOffsetTable.length)
          ? childHoodDecadeOffsetTable[virtualAge - 1]
          : 0;
      targetPalaceIndex = ZiweiConsts.fixIndex(mingIndex - offset);
    } else {
      // 常规顺延派 (一年一格)
      int steps = virtualAge - 1;
      targetPalaceIndex = isClockwise
          ? ZiweiConsts.fixIndex(mingIndex + steps)
          : ZiweiConsts.fixIndex(mingIndex - steps);
    }

    Palace targetPalace = plate.palaces[targetPalaceIndex];
    PalaceRole role = plate.getRole(ZiweiScope.origin, targetPalaceIndex);

    // 童限的 startTime/endTime 直接用虚岁表示
    return Decade(targetPalace.ganzhi, virtualAge, virtualAge, role);
  }

  /// 获取“有效出生年” (用于计算虚岁与阴阳)
  static int getEffectiveBirthYear(ZiWeiPlate plate) {
    // 这里复用你之前写的带逻辑年判断的代码
    if (plate.date.options.flowLimitBasedOn == Boundary.lunar) {
      return plate.effective_year;
    } else {
      // 节气派逻辑... (此处略，保持你原有的逻辑即可)
      return plate.date.solar.year; // 示例占位
    }
  }

  /// 获取起运的物理年份 (如 2026年出生，2岁起运，则 2027 年起大限)
  static int getStartDecadeYear(ZiWeiPlate plate) {
    return getEffectiveBirthYear(plate) + (plate.elementBureau.number - 1);
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
    int birthMonth = plate.effective_month;
    int birthTimeIndex = plate.date.timeIndex;

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
    switch (scope) {
      case ZiweiScope.origin:
        // 彻底重置，只留原局
        return LimitContext(plate: plate);

      case ZiweiScope.decade:
        // 删了大限，后面所有流层全部清空
        return copyWith(
          decade: null,
          year: null,
          month: null,
          day: null,
          hour: null,
        );

      case ZiweiScope.year:
        // 删了流年，月、日、时跟着一起消失（小限通常也一起消失，看你设计）
        return copyWith(
          year: null,
          smallLimit: null,
          month: null,
          day: null,
          hour: null,
        );

      case ZiweiScope.month:
        // 删了月，日、时也保不住
        return copyWith(month: null, day: null, hour: null);

      case ZiweiScope.day:
        // 删了日，时也就没了
        return copyWith(day: null, hour: null);

      case ZiweiScope.hour:
        // 只删时辰，不影响上级
        return copyWith(hour: null);

      case ZiweiScope.smallLimit:
        // 小限通常是独立的开关，可以单独删
        return copyWith(smallLimit: null);
    }
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

  /// 场景：当用户在 UI 的大限列表里点选了某一个大限（0-11）
  /// 🛰️0=童限, 1=第一大限, 2=第二大限...
  /// [index] 索引
  /// [targetYear] 可选：如果是看童限(0)，需要知道具体哪一年的童限
  static LimitContext travelByMacro(
    ZiWeiPlate plate,
    int index, {
    int? targetYear,
  }) {
    Decade decade;

    if (index == 0) {
      // 🌟 绑定：索引 0 指向童限
      // 如果没传 targetYear，默认看 1 岁
      int vAge = 1;
      if (targetYear != null) {
        vAge = targetYear - Decade.getEffectiveBirthYear(plate) + 1;
      }
      decade = Decade.createChildhood(vAge, plate);
    } else {
      // 🌟 绑定：1 就是第一大限
      decade = Decade.fromIndex(index, plate);
    }

    return LimitContext(
      plate: plate,
      decade: decade,
      // 切换大周期时，清空具体的流年/流月/流日等微观状态
      smallLimit: null,
      year: null,
      month: null,
      day: null,
      hour: null,
    );
  }
}
