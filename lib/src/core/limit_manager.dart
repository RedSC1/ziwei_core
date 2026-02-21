import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

/// 紫微流运状态管理器
///
/// 封装了底层的 [ZiWeiPlate] 与 [LimitContext]，提供简单的 API 进行时间推演。
/// 核心思想：通过改变内部的 [ZiweiDate] 或大限索引，然后自动重新计算上下文。
///
/// 每次变动“大单位”时，会自动清除“小单位”的状态。例如调用 [addMonth]，
/// 会清空 [day] 和 [hour] 的流运展示，防止旧时间的污染。
class ZiweiLimitManager {
  final ZiWeiPlate _basePlate;

  /// 基于“物理时间”步进时的流动时间锚点（如果要玩转 addDays 或 addHours）
  ZiweiDate? currentDate;

  /// 当前激活的 LimitContext，包含了正在生效的流年流月等流派。
  LimitContext _currentContext;

  ZiweiLimitManager(this._basePlate)
    : _currentContext = LimitContext.original(_basePlate);

  // --- Getters ---

  /// 获取当前状态下的动态盘（每次调用都会克隆一份新的，不污染原盘）
  ZiWeiPlate get dynamicPlate => ZiweiEngine.calculateDynamic(_currentContext);

  LimitContext get limitContext => _currentContext;

  ZiWeiPlate get basePlate => _basePlate;

  // --- 大限控制 (Decade) ---

  /// 切换到指定的大限索引（0:童限, 1:第一大限, ...）
  void setDecadeIndex(int index, {int? targetChildhoodYear}) {
    _currentContext = TimeMachine.travelByMacro(
      _basePlate,
      index,
      targetYear: targetChildhoodYear,
    );
  }

  /// 移除大限及其下属的所有流运
  void clearDecade() {
    _currentContext = _currentContext.remove(ZiweiScope.decade);
  }

  // --- 物理时间驱动推演 (Year, Month, Day, Hour) ---

  /// 初始化进入某一个流年
  void setYear(int year) {
    _currentContext = TimeMachine.travel(_basePlate, year: year);
  }

  /// 年份跳转 (会清除流月、日、时)
  void addYear(int delta) {
    if (!_currentContext.hasYear) {
      // 没有任何流年，无法加减。默认以现在的农历年为准也可，但按规范应当先 setYear
      return;
    }
    int newYear = _currentContext.year!.year + delta;
    setYear(newYear);
  }

  /// 进入/跳转流月 (1-12)。会清除流日、时。
  /// (传入的 month 是农历正月=1)
  void setMonth(int month) {
    if (!_currentContext.hasYear) return;

    // 生成包含月份的 Context
    _currentContext = TimeMachine.travel(
      _basePlate,
      year: _currentContext.year!.year,
      month: month,
    );
  }

  void addMonth(int delta) {
    if (!_currentContext.hasMonth || !_currentContext.hasYear) return;

    int currentMonth = _currentContext.month!.month;
    int targetMonth = currentMonth + delta;
    int targetYear = _currentContext.year!.year;

    // 简单进位逻辑 (忽略真实闰月情况，因为只是月份数字的加减。要涉及物理日期请用 addDays)
    while (targetMonth > 12) {
      targetMonth -= 12;
      targetYear++;
    }
    while (targetMonth < 1) {
      targetMonth += 12;
      targetYear--;
    }

    _currentContext = TimeMachine.travel(
      _basePlate,
      year: targetYear,
      month: targetMonth,
    );
  }

  /// 进入流日。这里要求提供这一天的日干支，因为农历大小月复杂，管理器本身不含有物理时钟。
  /// 如果使用者使用的是完整的 ZiweiDate API 进行时间迭代，请直接使用外部工具计算后传入。
  void setDay(int day, GanZhi dayGanZhi) {
    if (!_currentContext.hasMonth) return;

    _currentContext = TimeMachine.travel(
      _basePlate,
      year: _currentContext.year!.year,
      month: _currentContext.month!.month,
      day: day,
      dayGanZhi: dayGanZhi,
    );
  }

  /// 进入流时 (0=子, 1=丑).
  void setHour(int hourIndex) {
    if (!_currentContext.hasDay) return;

    _currentContext = TimeMachine.travel(
      _basePlate,
      year: _currentContext.year!.year,
      month: _currentContext.month!.month,
      day: _currentContext.day!.day,
      dayGanZhi: _currentContext.day!.ganzhi, // TimeMachine 用它提取天干
      hourIndex: hourIndex,
    );
  }

  /// 层层向上剥离清理
  void clearHour() => _currentContext = _currentContext.remove(ZiweiScope.hour);
  void clearDay() => _currentContext = _currentContext.remove(ZiweiScope.day);
  void clearMonth() =>
      _currentContext = _currentContext.remove(ZiweiScope.month);
  void clearYear() => _currentContext = _currentContext.remove(ZiweiScope.year);

  /// 彻底重置为原盘
  void reset() {
    _currentContext = LimitContext.original(_basePlate);
    currentDate = null;
  }

  // === 【高阶法术：基于绝对物理时间的步进】 ===
  // 就像用户指出的，依靠整数 +1 跨月、跨日、早晚子时切分会遇到历法逻辑死角。
  // 通过向底层 SolarTime 加入 Duration，重新过一遍八字引擎，能完美化解一切闰月/交截点！

  /// 以给定的 DateTime 为基准，自动解析包含年月日时的完整流运状态。
  void setPhysicalDate(DateTime time) {
    // 1. 利用引擎彻底解析这个时间点，自动处理早晚子时、真太阳时等
    currentDate = ZiweiDate.fromSolar(
      time,
      options: _basePlate.date.options, // 继承原盘的历法配置
      location: _basePlate.date.location,
      gender: _basePlate.date.gender,
    );

    // 2. 根据精准解析出来的 currentDate 重建 LimitContext
    _rebuildContextFromCurrentDate();
  }

  /// 物理时间前进或倒退（完美支持“下一个时辰”、“下一天”）
  void addDuration(Duration duration) {
    if (currentDate == null) {
      // 如果没有抛锚真实时间，默认从“现在”开始流动
      setPhysicalDate(DateTime.now());
    }

    // 在底层的物理时间上加上增量
    final nextTime = currentDate!.solar.toDateTime()!.add(duration);
    setPhysicalDate(nextTime);
  }

  /// 封装：下一天
  void nextDay() => addDuration(const Duration(days: 1));

  /// 封装：上一天
  void previousDay() => addDuration(const Duration(days: -1));

  /// 封装：下一个时辰 (绝对物理推演)
  /// 如果只简单加2小时，当处于 23:30 (晚子) 时加 2 小时会变成 01:30 (丑时)，直接跳过了 00:30 (早子时)！
  /// 为了绝对精准，我们将首先计算出目前的“时辰正中央时点”，然后再加 2 小时，绝对落在下一个时区的正中心。
  void nextHour() {
    if (currentDate == null) return nextDay();
    _snapToTargetHourOffset(2);
  }

  /// 封装：上一个时辰 (绝对物理推演)
  void previousHour() {
    if (currentDate == null) return previousDay();
    _snapToTargetHourOffset(-2);
  }

  void _snapToTargetHourOffset(int hoursDelta) {
    // 假设 currentDate != null
    // 我们想求出当前时辰的正中心时间 (Center of the Branch)
    // 地支索引：子(0), 丑(1), 寅(2)...
    // 子时中心是 00:00, 丑时中心是 02:00, 寅时中心是 04:00
    int branchIndex = currentDate!.bazi.time.zhi.index;

    // 当前时间的年月日
    final solar = currentDate!.solar;

    // 如果当前处于“晚子时”(23:00~24:00)，其实它属于昨天的末尾，但 date 已经算作“子时=0”了。
    // 为了找准正中心，我们以“当前的实际阳历日期”为基准，将时分秒强行对齐到该地支的正中心！
    int centerHour = branchIndex * 2;

    DateTime centerTime;
    if (branchIndex == 0 && solar.hour >= 23) {
      // 晚子时特例：它的正中心理论上是 24:00，但在 DateTime 里等于隔天的 00:00
      centerTime = DateTime(
        solar.year,
        solar.month,
        solar.day,
      ).add(const Duration(days: 1));
    } else {
      // 常规时辰中心：直接对其当天的 centerHour
      centerTime = DateTime(solar.year, solar.month, solar.day, centerHour);
    }

    // 此时 centerTime 是当前时辰的“绝对中心靶心”
    // 直接加上增量，确保稳稳落入下一个靶心，绝不跨区！
    final nextTargetCenter = centerTime.add(Duration(hours: hoursDelta));
    setPhysicalDate(nextTargetCenter);
  }

  void _rebuildContextFromCurrentDate() {
    if (currentDate == null) return;

    final eLunar = currentDate!.lunar;
    final bazi = currentDate!.bazi;

    // 获取绝对有效年（不包含干支逻辑，纯数字）用于计算大阴历差
    // 这里的年已经由 fromSolar 在底层处理过了闰腊月进位问题（详见 ZiweiDate getter）
    int effectiveYear = eLunar.lunarYear;
    // 双重保险：防 13 月
    int effectiveMonth = eLunar.month;
    if (effectiveMonth == 13) effectiveMonth = 12;

    _currentContext = TimeMachine.travel(
      _basePlate,
      year: effectiveYear,
      month: effectiveMonth,
      day: eLunar.day,
      dayGanZhi: bazi.day, // 😎 真正的降维打击！这里直接拿到物理正确的当日干支
      hourIndex: bazi.time.zhi.index, // 早晚子时的自动裁决
    );
  }
}
