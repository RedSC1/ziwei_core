import 'package:bazi_core/bazi_core.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

class TimeAdapter {
  static ZiweiDate fromSolar(
    AstroDateTime solarDate,
    Gender gender, {
    CalendarOptions? options,
    Location? location,
    double timeZone = 8,
    bool? useTrueSolarTime = true,
  }) {


    final opt = options ?? const CalendarOptions();
    final loc = location ?? defaultLoc;//120N 30E
    final utst = useTrueSolarTime ?? true;

    // 1. 使用 bazi_core 的 TimePack 封装时间计算
    // TimePack 会自动处理真太阳时、UTC 等
    final timePack = TimePack.createBySolarTime(
      clockTime: solarDate,
      location: loc, // 经纬度
      timezone: timeZone, // 时区
      splitByRatHour: opt.splitRatHour, // 是否早晚子时
      useTrueSolarTime: utst, // 默认使用真太阳时
    );

    // 2. 使用 bazi_core 的 TimeAdaptor 计算八字
    final bazi = TimeAdaptor.fromSolar(
      timePack,
      splitRatHour: opt.splitRatHour,
    );

    // 3. 使用 bazi_core 的 LunarDate 计算农历
    final lunarDate = LunarDate.fromSolar(
      timePack.virtualTime, // 注意：农历基于排盘时间（可能因早晚子时调整）
      splitRatHour: opt.splitRatHour,
    );

    // 4. 计算 solarDay (上个节令后第几天)
    // 寻找 currentJ2k 之前的最近一个节令
    final solarDay = _getSolarDay(timePack, splitByRatHour: opt.splitRatHour);

    return ZiweiDate(
      solar: solarDate,
      trueSolarTime: timePack.solarTime.trueSolarTime,
      location: loc,
      lunar: lunarDate, // 使用 bazi_core 的 LunarDate
      bazi: bazi, // 使用 bazi_core 的 BaZi
      options: opt,
      solarDay: solarDay,
      gender: gender,
    );
  }

 static ZiweiDate fromLunar(
    int year,
    int month,
    int day,
    int hour,     // 🚀 核心：精准时
    int minute,   // 🚀 核心：精准分
    int second,   // 🚀 核心：精准秒
    bool isLeap,
    Gender gender,{
    CalendarOptions? options,
    Location? location,
    bool? useTrueSolarTime = true,
  }) {
    // 1. 构造 bazi_core 的 LunarDate 对象
    String monthName;
    
    if (month == 1) {
      monthName = "正";
    } else if (month == 11) {
      monthName = "冬";
    } else if (month == 12) {
      monthName = "腊";
    } else {
      const names = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三"];
      if (month > 0 && month < names.length) {
        monthName = names[month];
      } else {
        // 极端兜底
        monthName = month.toString();
      }
    }

    // 处理闰月与历史特殊历法
    if (isLeap) {
      // 如果开启了历史历法，且恰好是 9 月的闰月（秦/汉初的颛顼历岁末闰月）
      if (options?.enableHistorical == true && month == 9) {
        monthName = "后九"; 
      } else {
        monthName = "闰$monthName";
      }
    }

    final lunar = LunarDate.fromString(year, monthName, day);

    // 2. 转阳历 (拿到那一天的基准日期)
    final anchorTime = lunar.toSolar;

    // 3. 💥 拒绝时辰估算误差，直接注入精准时间！
    var solar = AstroDateTime(
      anchorTime.year,
      anchorTime.month,
      anchorTime.day,
      hour,    // 精准时
      minute,  // 精准分
      second,  // 精准秒
    );

    // 4. 递归调用 fromSolar，扔给底层算真太阳时
    return fromSolar(solar, gender, options: options, location: location, useTrueSolarTime: useTrueSolarTime);
  }


  static int _getSolarDay(TimePack timePack, {bool splitByRatHour = false}){
    // 1. 算出“排盘钟”和“北京钟”之间的物理差值
    // 这个差值已经包含了：时区差 + 经度差 + 均时差（如果开了真太阳）
    final double bjJd = timePack.bjClt.toJ2000();
    final double virtualJd = timePack.virtualTime.toJ2000();
    final double clockOffset = virtualJd - bjJd;

    // 2. 获取北京时间的节气 JD，并平移到“排盘钟”的参照系
    final double jieBjJd = getPrevJie(timePack.bjClt)!.dateTime.toJ2000();
    final double jieVirtualJd = jieBjJd + clockOffset; // 核心：让节气坐标与排盘时刻同频

    // 3. 处理早晚子时逻辑（确定“逻辑今天”）
    double currentLogicalJd = virtualJd;
    if (!splitByRatHour && timePack.virtualTime.hour >= 23) {
      // 如果不分早晚子且是晚子时，逻辑上这人已经活在“明天”了
      // 这里的 +1/24 是为了让 JD 跨过凌晨那个坎，从而改变 Day ID
      currentLogicalJd += (1.0 / 24.0); 
    }

    // 4. 用统一参照系下的两个 JD 算日子 ID
    int currentDayID = (currentLogicalJd + 0.5).floor();
    int jieDayID =  (jieVirtualJd + 0.5).floor();
    return (currentDayID - jieDayID) + 1;
  }
}
