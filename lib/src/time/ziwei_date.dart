// 一个“干支”对儿（比如“甲子”就是一个 GanZhi 对象）
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/consts.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import 'time_adapter.dart';

class CalendarOptions {
  final bool splitRatHour; // 早晚子时
  final LeapMonthRule leapRule; // 闰月规则
  final Boundary wuHuDunBasedOn; //五虎遁按照农历还是节气
  final Boundary siHuaBasedOn; //四化按照农历还是节气
  // 童限规则：regular (一岁一宫顺行) vs special_skip (一命二财三疾厄...)
  final ChildhoodRole childhoodRule;
  final Boundary flowLimitBasedOn;
  final bool enableHistorical; // 是否启用特殊历法（建子月/建丑月等历史历法调整）

  const CalendarOptions({
    this.splitRatHour = false,
    //默认
    this.leapRule = LeapMonthRule.splitAt15,
    this.wuHuDunBasedOn = Boundary.lunar,
    this.siHuaBasedOn = Boundary.lunar,
    this.childhoodRule = ChildhoodRole.skip,
    this.flowLimitBasedOn = Boundary.lunar,
    this.enableHistorical = true, // 默认启用，与文墨天机一致
  });
}

class GanZhi {
  final TianGan gan;
  final DiZhi zhi;

  const GanZhi(this.gan, this.zhi);

  @override
  String toString() => "${gan.label}${zhi.label}";
}

class BaZi {
  //节气四柱八字
  final GanZhi year;
  final GanZhi month;
  final GanZhi day;
  final GanZhi time;

  const BaZi({
    required this.year,
    required this.month,
    required this.day,
    required this.time,
  });

  @override
  String toString() => "$year $month $day $time";
}

class LunarDate {
  //农历日期
  final int year;
  final int month;
  final int day;
  final int timeIndex; // 时辰索引 0-11
  final bool isLeap; // 是否闰月

  const LunarDate({
    required this.year,
    required this.month,
    required this.day,
    required this.timeIndex,
    this.isLeap = false,
  });

  @override
  String toString() => "$year年${isLeap ? "闰" : ""}$month月$day日";
}

class ZiweiDate {
  final AstroDateTime solar; // 阳历（支持公元前）
  final AstroDateTime? trueSolarTime; // 真太阳时（可选）
  final Location location; // 地理位置
  final LunarDate lunar; // 农历
  final BaZi bazi; // 八字
  final CalendarOptions options; // 历法选项
  final int solarDay; //上个节令后第几天
  final Gender gender; // ✅ 新增：性别

  const ZiweiDate({
    required this.solar,
    this.trueSolarTime,
    required this.location,
    required this.lunar,
    required this.bazi,
    required this.options,
    required this.solarDay,
    required this.gender,
  });

  /// 从阳历创建（支持 AstroDateTime 或 DateTime）。
  ///
  /// [dt] 输入时间。如果是 DateTime，会自动转为 AstroDateTime。
  /// [location] 地理位置。如果不传，默认为北京。
  factory ZiweiDate.fromSolar(
    Object dt, {
    CalendarOptions? options,
    Gender gender = Gender.male,
    Location? location,
  }) {
    AstroDateTime solar;
    if (dt is AstroDateTime) {
      solar = dt;
    } else if (dt is DateTime) {
      solar = AstroDateTime.fromDateTime(dt);
    } else {
      throw ArgumentError('dt must be AstroDateTime or DateTime');
    }

    return TimeAdapter.fromSolar(
      solar,
      gender,
      options: options,
      location: location,
    );
  }

  // 2. Lunar 入口也改一下：
  factory ZiweiDate.fromLunar(
    int year,
    int month,
    int day,
    int hourIndex,
    bool isLeap, {
    CalendarOptions? options,
    Gender gender = Gender.male,
    Location? location,
  }) {
    // 把 options 透传给 Adapter
    return TimeAdapter.fromLunar(
      year,
      month,
      day,
      hourIndex,
      isLeap,
      gender,
      options: options,
      location: location,
    );
  }

  @override
  String toString() {
    return '阳: $solar\n阴: $lunar\n八: $bazi';
  }

  GanZhi getGanZhi(ZiweiScope scope, {Boundary? b}) {
    Boundary boundary = b ?? options.siHuaBasedOn;
    TianGan stem;
    DiZhi branch;
    switch (scope) {
      case ZiweiScope.origin:
      case ZiweiScope.year:
        if (boundary == Boundary.lunar) {
          stem = TianGan.values[(lunar.year + 6) % 10];
          int idx = ZiweiConsts.fixIndex(lunar.year - 4);
          branch = DiZhi.values[idx];
          return GanZhi(stem, branch);
        } else {
          return bazi.year;
        }
      case ZiweiScope.month:
        if (boundary == Boundary.lunar) {
          int virtualMonth = lunar.month;
          if (lunar.isLeap) {
            switch (options.leapRule) {
              case LeapMonthRule.asNext:
                virtualMonth++;
              case LeapMonthRule.splitAt15:
                if (lunar.day > 15) {
                  virtualMonth++;
                }
              default:
                break;
            }
          }
          // 农历月干: 需要用“五虎遁”推算！
          // 1. 先算农历年干索引
          // 修正负数年份模运算
          int yearForGan = lunar.year;
          if (yearForGan < 0) {
            // 公元前年干推算？
            // 公元前1年(0)是庚申(57)。
            // 简单点：根据年干支推算。
            // 但这里是“农历年”，不是“八字年”。
            // 假设农历年干和八字年干一致（其实可能有偏差）。
            // 更好的做法是：直接用 bazi.year 的天干作为基准！
            // 但如果 boundary == lunar，我们要用农历年干。
            // 农历年干公式：(year - 4) % 10 ?
            // 4 AD 是甲子。
            // -1 AD (BC 2) -> -5 -> 5 (己)
            // 0 AD (BC 1) -> -4 -> 6 (庚)
            // 1 AD -> -3 -> 7 (辛)
            // 公式：(year - 4) % 10
          }

          int yIdx = (lunar.year - 4) % 10;
          if (yIdx < 0) yIdx += 10;

          // 2. 算出正月(寅)的天干: (年干%5)*2 + 2
          int startStem = (yIdx % 5) * 2 + 2;

          // 3. 推算当前月的天干: 起点 + (月-1)
          int mStemIdx = (startStem + (virtualMonth - 1)) % 10;

          int mZhiIdx = (virtualMonth + 1) % 12;
          return GanZhi(TianGan.values[mStemIdx], DiZhi.values[mZhiIdx]);
        } else {
          return bazi.month;
        }
      case ZiweiScope.day:
        return bazi.day;
      case ZiweiScope.hour:
        return bazi.time;
      case ZiweiScope.decade:
        throw ArgumentError('请使用getFlowGanZhi()!!!');
      case ZiweiScope.smallLimit:
        throw ArgumentError('小限没有独立的干支，请使用流年干支或原局干支！');
    }
  }
}
