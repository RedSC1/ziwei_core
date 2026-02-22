import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

/// **紫微流运状态管理器 (Limit Manager)**
///
/// 封装了底层的 [ZiWeiPlate] 与 [LimitContext]，提供简洁且一致的 API 进行时间推演。
/// 核心思想：通过改变内部的 [ZiweiDate] 或大限索引，然后自动重新计算流年、流月、流日、流时上下文。
///
/// ---
/// ### 🌊 瀑布式层级清理机制
/// 每次变动**“大单位”**时间时，引擎会自动清除所有的**“小单位”**附着状态。
/// 例如：调用 `addMonth()` 切换流月，会自动清空 `day` 和 `hour` 的流运展示，防止旧时间的污染，保持盘面干净。
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

  /// 切入指定大限，重置流年流月
  ///
  /// - [index] 目标大限的绝对索引 (0:童限, 1:第一大限, ...)
  /// - [targetChildhoodYear] (可选) 若查看童限 (0)，需提供具体看哪一年的童限以推算流年
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

  /// 初始化进入某一个流年 (同时清空以下流月流日等)
  ///
  /// - [year] 目标物理属性年份 (如 `2024`)
  void setYear(int year) {
    _currentContext = TimeMachine.travel(_basePlate, year: year);
  }

  /// 按年份幅度跨越跳转 (同时清除流月、日、时)
  ///
  /// - [delta] 偏移跨幅，如 `1` 表示明年起运，`-2` 表示两年前
  void addYear(int delta) {
    if (!_currentContext.hasYear) {
      // 没有任何流年，无法加减。默认以现在的农历年为准也可，但按规范应当先 setYear
      return;
    }
    int newYear = _currentContext.year!.year + delta;
    setYear(newYear);
  }

  /// 绝对切入指定农历流月 (会清除流日、流时)
  ///
  /// - [month] 农历正向月份 (正月: `1`, 腊月: `12`)
  void setMonth(int month) {
    if (!_currentContext.hasYear) return;

    // 生成包含月份的 Context
    _currentContext = TimeMachine.travel(
      _basePlate,
      year: _currentContext.year!.year,
      month: month,
    );
  }

  /// 按照相对幅度切分月份 (如前两个月、后四个月)
  ///
  /// 💡 当前的简单进位逻辑会忽略真实的闰月物理跳跃，纯粹推演逻辑月。若要推算真实的物理历法跨越，请使用`addDuration()`
  /// - [delta] 月份漂移量 (正数往后，负数往前)
  void addMonth(int delta) {
    if (!_currentContext.hasMonth || !_currentContext.hasYear) return;

    // === 节气模式：跳到下/上一个节的物理日期 ===
    final isSolarBoundary =
        _basePlate.ruleset.calendarOptions.flowLimitBasedOn == Boundary.solar;
    if (isSolarBoundary && currentDate != null) {
      final solar = currentDate!.solar;
      var anchor = AstroDateTime(
        solar.year,
        solar.month,
        solar.day,
        solar.hour,
        solar.minute,
        solar.second,
      );
      // 逐个节跳转
      for (int i = 0; i < delta.abs(); i++) {
        if (delta > 0) {
          final nextJie = getNextJie(anchor);
          if (nextJie == null) break;
          // 落入下一个节后 1 小时，确保安全落地
          anchor = AstroDateTime(
            nextJie.dateTime.year,
            nextJie.dateTime.month,
            nextJie.dateTime.day,
            nextJie.dateTime.hour + 1,
            nextJie.dateTime.minute,
            0,
          );
        } else {
          final prevJie = getPrevJie(anchor);
          if (prevJie == null) break;
          // 落入上一个节前 1 小时，确保安全落地到前一个月
          anchor = AstroDateTime(
            prevJie.dateTime.year,
            prevJie.dateTime.month,
            prevJie.dateTime.day,
            prevJie.dateTime.hour - 1,
            prevJie.dateTime.minute,
            0,
          );
        }
      }
      setPhysicalDate(anchor.toDateTime()!);
      return;
    }

    // === 农历模式：简单数字进位 ===
    int currentMonth = _currentContext.month!.month;
    int targetMonth = currentMonth + delta;
    int targetYear = _currentContext.year!.year;

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

  /// 显式切入流日结构
  ///
  /// 这里要求显式提供这一天的日柱干支，因为农历大小月复杂，且本管理器逻辑链上不维护物理时钟。
  /// （若要更省心的日历跳转，请考虑使用 `setPhysicalDate()`）
  ///
  /// - [day] 农历物理初几
  /// - [dayGanZhi] 计算出来的真正物理当天的日柱干支
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

  /// 切入流时阶段
  ///
  /// - [hourIndex] 流时的硬装地支绝对索引 (0:子, 1:丑...)
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

  /// 核心魔法：以给定的绝对物理 DateTime 为基准，自动解析并重构出此时天地相交的完整流运切片
  ///
  /// 它会自动考虑原盘传承的所有“真太阳时配置、早晚子配置、地理经纬度偏差”。
  ///
  /// - [time] 需要推演探勘的当前地球时刻
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

  /// 基于当前停泊的物理时刻，做基于绝对真实物理的增量滑动推演。
  ///
  /// 相比基于数字的大限增减，这是完美无视历法盲区 (闰腊月等) 的“终极解决手段”。
  ///
  /// - [duration] 标准时间偏移量对象 (`Duration`)
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

  /// 以精准中心推演法则跨入下一个时辰
  ///
  /// 💡 防止出现晚子时（23:30）被简单相加推入下个错误时辰丑时（01:30）跳过早子时的历法特例：
  /// 该方法会强制回归当前时辰的“精准中轴点”，向下一跃两小时，直击靶心！
  void nextHour() {
    if (currentDate == null) return nextDay();
    _snapToTargetHourOffset(2);
  }

  /// 以精准中心推演法则归隐上一个时辰
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
    int effectiveYear = eLunar.lunarYear;
    int effectiveMonth = eLunar.month;
    if (effectiveMonth == 13) effectiveMonth = 12;
    int effectiveDay = eLunar.day;

    // === 节气(太阳)边界模式：用精确交节时刻判定月份和日期 ===
    final isSolarBoundary =
        _basePlate.ruleset.calendarOptions.flowLimitBasedOn == Boundary.solar;
    if (isSolarBoundary) {
      final solar = currentDate!.solar;
      final now = AstroDateTime(
        solar.year,
        solar.month,
        solar.day,
        solar.hour,
        solar.minute,
        solar.second,
      );
      final prevJie = getPrevJie(now);
      if (prevJie != null) {
        // 八字月份 = 上一个节所在的阳历月份映射
        // 立春(2月)→1, 惊蛰(3月)→2, ... 大雪(12月)→11, 小寒(1月)→12
        effectiveMonth = (prevJie.dateTime.month - 2 + 12) % 12 + 1;

        // 八字年以立春为界：小寒落在1月，说明还是上一年
        effectiveYear = prevJie.dateTime.month == 1
            ? prevJie.dateTime.year - 1
            : prevJie.dateTime.year;

        // 流日 = 节后第N天（底层 solarDay 已由 _getSolarDay 精确算过）
        effectiveDay = currentDate!.solarDay;
      }
    }

    _currentContext = TimeMachine.travel(
      _basePlate,
      year: effectiveYear,
      month: effectiveMonth,
      day: effectiveDay,
      dayGanZhi: bazi.day, // 😎 真正的降维打击！这里直接拿到物理正确的当日干支
      hourIndex: bazi.time.zhi.index, // 早晚子时的自动裁决
    );
  }
}
