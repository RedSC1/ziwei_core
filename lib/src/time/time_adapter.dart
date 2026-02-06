// lib/src/time/ziwei_date_adapter.dart

import 'package:lunar/calendar/Lunar.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

class TimeAdapter {
  static ZiweiDate fromSolar(DateTime date, {CalendarOptions? options}) {
    final opt = options ?? const CalendarOptions();
    // 1. 调用第三方库计算
    Lunar lunar = Lunar.fromDate(date);
    var eightChar = lunar.getEightChar();


    int splitOrNot = opt.splitRatHour ? 2 : 1;
    eightChar.setSect(splitOrNot); // 可选：设置子时流派

    // 2. 组装标准八字 (按节气算)
    var myBaZi = BaZi(
      year: GanZhi(
        TianGan.fromName(eightChar.getYearGan()), 
        DiZhi.fromName(eightChar.getYearZhi())
      ),
      month: GanZhi(
        TianGan.fromName(eightChar.getMonthGan()), 
        DiZhi.fromName(eightChar.getMonthZhi())
      ),
      day: GanZhi(
        TianGan.fromName(eightChar.getDayGan()), 
        DiZhi.fromName(eightChar.getDayZhi())
      ),
      time: GanZhi(
        TianGan.fromName(eightChar.getTimeGan()), 
        DiZhi.fromName(eightChar.getTimeZhi())
      ),
    );

    // 3. 组装紫微排盘用的农历日期
    int rawMonth = lunar.getMonth();
  
    var myLunar = LunarDate(
      year: lunar.getYear(),
      month: rawMonth.abs(), 
      day: lunar.getDay(),
      isLeap: rawMonth < 0,  // 核心：负数即为闰月 (如果不放心也可以 && lunar.isLeap())
      // 这里的 timeIndex 用地支转数字最稳 (子=0, 丑=1...)
      timeIndex: DiZhi.fromName(eightChar.getTimeZhi()).index,
    );

    // 4. 返回完整对象
    return ZiweiDate(
      solar: date,
      lunar: myLunar,
      bazi: myBaZi,
      options: opt,
    );
  }
  
  /// 这里的 hourIndex 是 0-11 的数字
  /// 0=子时, 1=丑时 ... 11=亥时
  static ZiweiDate fromLunar(int year, int month, int day, int hourIndex, bool isLeap, {CalendarOptions? options}) {
    // 1. 处理闰月：Lunar库规定闰月一般用负数表示
    // 如果 isLeap 是 true，就把月份变成负的 (比如 -4 表示闰四月)
    int targetMonth = isLeap ? -month.abs() : month.abs();

    // 2. 处理时辰：把 0-11 的地支索引，转成大概的小时数
    // 子时(0) -> 0点, 丑时(1) -> 2点, 寅时(2) -> 4点 ...
    // 3. 召唤第三方库，创建 Lunar 对象
    // fromYmdHms(年, 月, 日, 时, 分, 秒)
    // 注意：如果这天不存在（比如闰月错了），这里会报错，正好被外面捕获
    Lunar lunarObj = Lunar.fromYmdHms(year, targetMonth, day, hourIndex * 2, 0, 0);

    // 4. 拿到对应的阳历
    // solar.toString() 居然返回的是 "2024-02-10" 这种字符串
    var solarObj = lunarObj.getSolar();
    
    // 5. 转成 Dart 的 DateTime
    DateTime dt = DateTime(
      solarObj.getYear(), 
      solarObj.getMonth(), 
      solarObj.getDay(), 
      hourIndex * 2, // 时
      0 // 分
    );

    // 6. 只要有了阳历，剩下的事就交给上面的 fromSolar 办！
    return fromSolar(dt, options: options);
  }

}