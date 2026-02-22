// 一个“干支”对儿（比如“甲子”就是一个 GanZhi 对象）
import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import 'time_adapter.dart';

export 'package:bazi_core/src/models/gan_zhi.dart';
export 'package:bazi_core/src/models/lunar_date.dart';

/// **历法选项 (Calendar Options)**
///
/// 控制排盘引擎对历法的核心裁定规则，如早晚子时、闰月拆分、节气还是纯农历等。
///
/// ---
/// ### ⚙️ 历法行为配置
/// - [splitRatHour] 是否拆分早晚子时 (true:拆分, false:不拆分, 默认: false)
/// - [leapRule] 闰月处理规则 默认: splitAt15 (十五前作上月，十五后作下月)
/// - [wuHuDunBasedOn] 五虎遁按照农历(lunar)还是节气(solar)推算 默认: lunar
/// - [siHuaBasedOn] 四化按照农历(lunar)还是节气(solar)推算 默认: lunar
/// - [childhoodRule] 童限规则：regular(一岁一宫顺行) 或 special_skip(一命二财三疾厄) 默认: special_skip
/// - [flowLimitBasedOn] 流运盘是以农历(lunar)还是节气(solar)为分界 默认: lunar
/// - [enableHistorical] 是否启用特殊历史历法兼容（颛顼历后九月等） 默认: true
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
    this.enableHistorical = true, // 默认启用
  });

  Map<String, dynamic> toJson() {
    return {
      'splitRatHour': splitRatHour,
      'leapRule': leapRule.name,
      'wuHuDunBasedOn': wuHuDunBasedOn.name,
      'siHuaBasedOn': siHuaBasedOn.name,
      'childhoodRule': childhoodRule.name,
      'flowLimitBasedOn': flowLimitBasedOn.name,
      'enableHistorical': enableHistorical,
    };
  }
}

/// **紫微基底日期对象 (Ziwei Date)**
///
/// 命盘中实际携带和流转的核心时间体。包含了八字、阳历、农历等多重时间维度的全息倒影。
///
/// ---
/// ### 📦 核心时间锚点
/// - [solar] 高精度阳历（支持纪元前计算）
/// - [trueSolarTime] 真太阳时（可选，若开启则由底层引擎经过经纬计算后注入）
/// - [location] 排盘所使用的地理观测点
/// - [lunar] 对应的农历表示模型（不含时辰）
/// - [bazi] 对应的绝密八字结构
/// - [options] 挂载的引擎历法选项
/// - [solarDay] 上个节令交接点后经过的天数
/// - [gender] 命造性别
/// - [timeZone] 时区，默认 UTC+8 (北京时间)
class ZiweiDate {
  final AstroDateTime solar; // 阳历（支持公元前）
  final AstroDateTime? trueSolarTime; // 真太阳时（可选）
  final Location location; // 地理位置
  final LunarDate lunar; // 农历
  final BaZi bazi; // 八字
  final CalendarOptions options; // 历法选项
  final int solarDay; //上个节令后第几天
  final Gender gender; // 性别
  final double timeZone; // 时区

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
    required this.timeZone,
  });

  /// 从阳历创建本命基底构造（支持 AstroDateTime 或原生 DateTime）。
  ///
  /// - [dt] 输入生辰时间。若为 `DateTime` 会被自动映射到 `AstroDateTime`
  /// - [location] 地理观测点。如果不传，默认为 `120E 30N`
  /// - [gender] 性别。默认男
  /// - [options] 历法选项。
  /// - [timeZone] 基础参考时区。默认 `utc+8` 北京时间
  factory ZiweiDate.fromSolar(
    Object dt, {
    CalendarOptions? options,
    Gender gender = Gender.male,
    Location? location,
    double timeZone = 8,
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
      timeZone: timeZone,
    );
  }

  /// 从农历结构创建本命基底构造。
  ///
  /// - [year] 农历物理年份
  /// - [month] 农历月份索引
  /// - [day] 农历初几
  /// - [hour] 物理整点小时（并非紫微时辰，支持 0-23）
  /// - [minute] 生辰分
  /// - [second] 生辰秒
  /// - [isLeap] 本次输入的月份是否显式宣称为闰月
  /// - [gender] 性别。默认男
  /// - [options] 历法选项。
  /// - [location] 地理观测点。如果不传，默认为 `120E 30N`
  /// - [timeZone] 基础参考时区。默认 `utc+8` 北京时间
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
    double timeZone = 8,
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
      timeZone: timeZone,
    );
  }

  @override
  String toString() {
    return '阳: $solar\n阴: $lunar\n八: $bazi';
  }

  /// 序列化基底排盘时刻结构
  ///
  /// 将时间包、八字结构、地理坐标降维打击为通用 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'solar': {
        'year': solar.year,
        'month': solar.month,
        'day': solar.day,
        'hour': solar.hour,
        'minute': solar.minute,
        'second': solar.second,
      },
      'lunar': {
        'year': lunar.lunarYear, // lunarYear 不是 solar year
        'month': lunar.month,
        'day': lunar.day,
        'isLeap': lunar.isLeap,
      },
      'bazi': {
        'year': bazi.year.toString(),
        'month': bazi.month.toString(),
        'day': bazi.day.toString(),
        'time': bazi.time.toString(),
      },
      'location': {
        'longitude': location.longitude,
        'latitude': location.latitude,
      },
      'gender': gender.name,
      'timeZone': timeZone,
      'options': options.toJson(),
    };
  }

  /// 🛡️ 核心基石：获取排盘的“绝对有效年月” (包含跨年进位逻辑)
  /// 使用 Dart 3 Record 语法同时返回年份和月份
  ({int year, int month}) get _effectiveLunar {
    int eYear = lunar.lunarYear;
    int eMonth = lunar.month;

    // 1. 终极归一化：防 13 月核弹
    if (eMonth == 13) {
      eMonth = 12;
    }

    // 2. 闰月处理
    if (lunar.isLeap) {
      bool shouldAsNext = false;
      switch (options.leapRule) {
        case LeapMonthRule.asNext:
          shouldAsNext = true;
          break;
        case LeapMonthRule.splitAt15:
          shouldAsNext = lunar.day > 15;
          break;
        case LeapMonthRule.asPrevious:
          //default:
          shouldAsNext = false;
          break;
      }

      // 3. 触发进位与跨年
      if (shouldAsNext) {
        eMonth++;
        if (eMonth > 12) {
          eMonth = 1;
          eYear++;
        }
      }
    }
    return (year: eYear, month: eMonth);
  }

  /// 🔥核心业务：获取当前排盘逻辑链的底层干支。
  ///
  /// 可根据具体的历法设定来决定返回由“节气推算（八字）” 还是 “物理农历流转”的干支模型。
  ///
  /// - [scope] 求索干支的领域：年柱、月柱、日柱、时柱
  /// - [b] 强制指定使用哪种法则 (`Boundary.lunar` / `Boundary.solar`)；若留空则自动应用默认的 `options.siHuaBasedOn` 配置。
  GanZhi getGanZhi(ZiweiScope scope, {Boundary? b}) {
    Boundary boundary = b ?? options.siHuaBasedOn;

    // 💥 关键点：拿到洗干净的绝对真理！
    final effective = _effectiveLunar;

    switch (scope) {
      case ZiweiScope.origin:
      case ZiweiScope.year:
        if (boundary == Boundary.lunar) {
          int stemIndex = (effective.year - 4) % 10;
          if (stemIndex < 0) stemIndex += 10;

          int branchIndex = (effective.year - 4) % 12;
          if (branchIndex < 0) branchIndex += 12;

          return GanZhi(TianGan.values[stemIndex], DiZhi.values[branchIndex]);
        } else {
          return bazi.year;
        }

      case ZiweiScope.month:
        if (boundary == Boundary.lunar) {
          // 无脑使用 effective 属性，之前的 switch 垃圾代码全删了！
          int eMonth = effective.month;
          int eYear = effective.year;

          // 农历月干: 需要用“五虎遁”推算！
          // 1. 先算有效年干索引 (同样必须用 eYear，保证跨年时五虎遁不出错)
          int yIdx = (eYear - 4) % 10;
          if (yIdx < 0) yIdx += 10;

          // 2. 算出正月(寅)的天干: (年干%5)*2 + 2
          int startStem = (yIdx % 5) * 2 + 2;

          // 3. 推算当前月的天干: 起点 + (月-1)
          int mStemIdx = (startStem + (eMonth - 1)) % 10;

          // 4. 地支永远是 (月 + 1) % 12 (正月=寅=2)
          int mZhiIdx = (eMonth + 1) % 12;

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
