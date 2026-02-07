// 一个“干支”对儿（比如“甲子”就是一个 GanZhi 对象）
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'time_adapter.dart';

class CalendarOptions {
  final bool splitRatHour; // 早晚子时
  final LeapMonthRule leapRule; // 闰月规则
  final Boundary wuHuDunBasedOn; //五虎遁按照农历还是节气

  const CalendarOptions({
    this.splitRatHour = false,
    //默认
    this.leapRule = LeapMonthRule.splitAt15,
    this.wuHuDunBasedOn = Boundary.lunar,
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
  final DateTime solar; // 阳历
  final LunarDate lunar; // 农历
  final BaZi bazi; // 八字
  final CalendarOptions options; // 历法选项

  const ZiweiDate({
    required this.solar,
    required this.lunar,
    required this.bazi,
    required this.options,
  });

  factory ZiweiDate.fromSolar(DateTime dt, {CalendarOptions? options}) {
    // 把 options 透传给 Adapter
    return TimeAdapter.fromSolar(dt, options: options);
  }
  // 2. Lunar 入口也改一下：
  factory ZiweiDate.fromLunar(
    int year,
    int month,
    int day,
    int hourIndex,
    bool isLeap, {
    CalendarOptions? options,
  }) {
    // 把 options 透传给 Adapter
    return TimeAdapter.fromLunar(
      year,
      month,
      day,
      hourIndex,
      isLeap,
      options: options,
    );
  }

  @override
  String toString() {
    return '阳: $solar\n阴: $lunar\n八: $bazi';
  }
}
