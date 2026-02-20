// 一个“干支”对儿（比如“甲子”就是一个 GanZhi 对象）
import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import 'time_adapter.dart';

export 'package:bazi_core/src/models/gan_zhi.dart';
export 'package:bazi_core/src/models/lunar_date.dart';

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

class ZiweiDate {
  final AstroDateTime solar; // 阳历（支持公元前）
  final AstroDateTime? trueSolarTime; // 真太阳时（可选）
  final Location location; // 地理位置
  final LunarDate lunar; // 农历
  final BaZi bazi; // 八字
  final CalendarOptions options; // 历法选项
  final int solarDay; //上个节令后第几天
  final Gender gender; // ✅ 新增：性别

  // 兼容旧版 getter：时辰索引
  int get timeIndex => bazi.time.zhi.index;

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
    int hour,
    int minute,
    int second,
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
      hour,
      minute,
      second,
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
    switch (scope) {
      case ZiweiScope.origin:
      case ZiweiScope.year:
        if (boundary == Boundary.lunar) {
          // 1. 计算年干 (Year Stem)
          // 公元4年是甲(0)，公式：(year - 4) % 10
          // 必须处理公元前(负数)的情况
          int stemIndex = (lunar.lunarYear - 4) % 10;
          if (stemIndex < 0) stemIndex += 10; // 核心修复：防止负数索引

          // 2. 计算年支 (Year Branch)
          // 公元4年是子(0)，公式：(year - 4) % 12
          int branchIndex = (lunar.lunarYear - 4) % 12;
          if (branchIndex < 0) branchIndex += 12; // 核心修复

          return GanZhi(TianGan.values[stemIndex], DiZhi.values[branchIndex]);
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
          int yIdx = (lunar.lunarYear - 4) % 10;
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
