part of '../ziwei_core.dart';

enum ZiweiClockMode { civil, meanSolar, trueSolar }

enum LeapMonthStrategy { asPrevious, asNext, splitAfterFifteenth }

enum PillarBoundary { solarTerm, lunar }

/// Immutable calendar, placement, rule and flow configuration.
class ZiweiOptions {
  ZiweiOptions({
    required this.gender,
    CalendarOptions? calendarOptions,
    this.ratHourMode = RatHourMode.nextDay,
    this.pillarHistoricalMode = PillarHistoricalMode.followCalendar,
    this.clockMode = ZiweiClockMode.civil,
    this.longitudeDeg,
    this.leapMonthStrategy = LeapMonthStrategy.splitAfterFifteenth,
    this.chartMode = ZiweiChartMode.tianPan,
    this.wuHuDunYearBoundary = PillarBoundary.lunar,
    this.sihuaYearBoundary = PillarBoundary.lunar,
    this.bodyMasterYearBoundary = PillarBoundary.lunar,
    this.flowLimitBoundary = PillarBoundary.lunar,
    this.flowMonthPalaceStrategy = FlowMonthPalaceStrategy.physicalSequence,
    this.childhoodStrategy = ChildhoodStrategy.skip,
    ZiweiRuleSelection? rules,
  }) : rules = rules ?? ZiweiRuleSelection(),
       calendarOptions = calendarOptions ?? CalendarOptions() {
    if (longitudeDeg != null &&
        (!longitudeDeg!.isFinite || longitudeDeg!.abs() > 180)) {
      throw RangeError('longitudeDeg must be within ±180 degrees');
    }
    if (clockMode != ZiweiClockMode.civil && longitudeDeg == null) {
      throw ArgumentError('longitudeDeg is required for a solar clock');
    }
  }
  ZiweiOptions copyWith({
    ZiweiGender? gender,
    CalendarOptions? calendarOptions,
    RatHourMode? ratHourMode,
    PillarHistoricalMode? pillarHistoricalMode,
    ZiweiClockMode? clockMode,
    double? longitudeDeg,
    bool clearLongitude = false,
    LeapMonthStrategy? leapMonthStrategy,
    ZiweiChartMode? chartMode,
    PillarBoundary? wuHuDunYearBoundary,
    PillarBoundary? sihuaYearBoundary,
    PillarBoundary? bodyMasterYearBoundary,
    PillarBoundary? flowLimitBoundary,
    FlowMonthPalaceStrategy? flowMonthPalaceStrategy,
    ChildhoodStrategy? childhoodStrategy,
    ZiweiRuleSelection? rules,
  }) => ZiweiOptions(
    gender: gender ?? this.gender,
    calendarOptions: calendarOptions ?? this.calendarOptions,
    ratHourMode: ratHourMode ?? this.ratHourMode,
    pillarHistoricalMode: pillarHistoricalMode ?? this.pillarHistoricalMode,
    clockMode: clockMode ?? this.clockMode,
    longitudeDeg: clearLongitude ? null : longitudeDeg ?? this.longitudeDeg,
    leapMonthStrategy: leapMonthStrategy ?? this.leapMonthStrategy,
    chartMode: chartMode ?? this.chartMode,
    wuHuDunYearBoundary: wuHuDunYearBoundary ?? this.wuHuDunYearBoundary,
    sihuaYearBoundary: sihuaYearBoundary ?? this.sihuaYearBoundary,
    bodyMasterYearBoundary:
        bodyMasterYearBoundary ?? this.bodyMasterYearBoundary,
    flowLimitBoundary: flowLimitBoundary ?? this.flowLimitBoundary,
    flowMonthPalaceStrategy:
        flowMonthPalaceStrategy ?? this.flowMonthPalaceStrategy,
    childhoodStrategy: childhoodStrategy ?? this.childhoodStrategy,
    rules: rules ?? this.rules,
  );
  final ZiweiGender gender;
  final CalendarOptions calendarOptions;
  final RatHourMode ratHourMode;
  final PillarHistoricalMode pillarHistoricalMode;
  final ZiweiClockMode clockMode;
  final double? longitudeDeg;
  final LeapMonthStrategy leapMonthStrategy;
  final ZiweiChartMode chartMode;
  final PillarBoundary wuHuDunYearBoundary,
      sihuaYearBoundary,
      bodyMasterYearBoundary,
      flowLimitBoundary;
  final FlowMonthPalaceStrategy flowMonthPalaceStrategy;
  final ChildhoodStrategy childhoodStrategy;
  final ZiweiRuleSelection rules;
  double get utcOffsetMinutes => calendarOptions.utcOffsetMinutes;
  Accuracy get eventAccuracy => calendarOptions.eventAccuracy;
  CalendarOptions toCalendarOptions() => calendarOptions;
  Map<String, Object?> toJson() => {
    'gender': gender.index,
    'mode': calendarOptions.mode.name,
    'eventAccuracy': eventAccuracy.name,
    'utcOffsetMinutes': utcOffsetMinutes,
    'ratHourMode': ratHourMode.name,
    'clockMode': clockMode.name,
    'longitudeDeg': longitudeDeg,
    'pillarHistoricalMode': pillarHistoricalMode.name,
    'dayBoundaryMode': calendarOptions.dayBoundaryMode.name,
    'meridianDeg': calendarOptions.meridianDeg,
    'leapMonthStrategy': leapMonthStrategy.index,
    'chartMode': chartMode.index,
    'wuHuDunYearBoundary': wuHuDunYearBoundary.index,
    'sihuaYearBoundary': sihuaYearBoundary.index,
    'bodyMasterYearBoundary': bodyMasterYearBoundary.index,
    'flowLimitBoundary': flowLimitBoundary.index,
    'flowMonthPalaceStrategy': flowMonthPalaceStrategy.index,
    'childhoodStrategy': childhoodStrategy.index,
    'rules': rules.toJson(),
  };
}

class ResolvedZiweiBirth {
  const ResolvedZiweiBirth({
    required this.clockTime,
    required this.virtualTime,
    required this.jdUT1,
    required this.lunarDate,
    required this.solarTermPillars,
    required this.lunarPillars,
    required this.effectiveLunarYear,
    required this.effectiveLunarMonth,
    required this.solarDayFromPreviousJie,
    required this.anchors,
    required this.options,
  });
  ZiweiGender get gender => options.gender;
  Map<String, Object> toJson() => _factsJson(this);
  final ZonedTime? clockTime;
  final CalendarDate virtualTime;
  final double jdUT1;
  final LunarCalendarDate lunarDate;
  final FourPillars solarTermPillars, lunarPillars;
  final int effectiveLunarYear, effectiveLunarMonth, solarDayFromPreviousJie;
  final PlacementAnchors anchors;
  final ZiweiOptions options;
}

double _jd(CalendarDate date) => julianDay(
  year: date.year,
  month: date.month,
  day: date.day,
  hour: date.hour,
  minute: date.minute,
  second: date.second,
);
double _logical(double jd, RatHourMode mode) =>
    jd +
    (mode == RatHourMode.nextDay && calendarDateFromJulianDay(jd).hour >= 23
        ? 1 / 24
        : 0);

ResolvedZiweiBirth resolveZiweiBirth(ZonedTime clock, ZiweiOptions options) {
  return resolveZiweiBirthFromInstant(
    clock.toJulianTime().jdUT1,
    resolveZiweiVirtualTime(clock, options),
    options,
    clockTime: clock,
  );
}

CalendarDate resolveZiweiVirtualTime(ZonedTime clock, ZiweiOptions options) =>
    switch (options.clockMode) {
      ZiweiClockMode.civil => clock,
      ZiweiClockMode.meanSolar => meanSolarTime(clock, options.longitudeDeg!),
      ZiweiClockMode.trueSolar => trueSolarTime(clock, options.longitudeDeg!),
    };
LunarCalendarDate resolveZiweiLogicalLunarDate(
  CalendarDate virtual,
  ZiweiOptions options,
) {
  final date = calendarDateFromJulianDay(
    _logical(_jd(virtual), options.ratHourMode),
  );
  return solarToLunar(
    CalendarDate(year: date.year, month: date.month, day: date.day),
    options: options.calendarOptions,
  );
}

ResolvedZiweiBirth resolveZiweiBirthFromInstant(
  double jd,
  CalendarDate virtualTime,
  ZiweiOptions options, {
  ZonedTime? clockTime,
}) {
  if (!jd.isFinite) throw ArgumentError.value(jd, 'jdUT1');
  final virtual = normalizeChartVirtualTime(virtualTime), vjd = _jd(virtual);
  final logical = calendarDateFromJulianDay(_logical(vjd, options.ratHourMode));
  final lunar = solarToLunar(
    CalendarDate(year: logical.year, month: logical.month, day: logical.day),
    options: options.calendarOptions,
  );
  var year = lunar.historicalYear, month = lunar.month == 13 ? 12 : lunar.month;
  if (lunar.isLeap &&
      (options.leapMonthStrategy == LeapMonthStrategy.asNext ||
          options.leapMonthStrategy == LeapMonthStrategy.splitAfterFifteenth &&
              lunar.day > 15)) {
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }
  final solar = calculateFourPillars(
    jd,
    virtual,
    options: options.calendarOptions,
    ratHourMode: options.ratHourMode,
    pillarHistoricalMode: options.pillarHistoricalMode,
  );
  final stem = (year + 6) % 10;
  final lunarPillars = FourPillars(
    year: makeGanzhi(stem, (year + 8) % 12),
    month: makeGanzhi((stem % 5 * 2 + 1 + month) % 10, (month + 1) % 12),
    day: solar.day,
    hour: solar.hour,
  );
  final previous = getPreviousJie(jd, options: options.calendarOptions);
  final jieVirtual = previous.time.jdUT1 + vjd - jd;
  final day =
      (_logical(vjd, options.ratHourMode) + 0.5).floor() -
      (_logical(jieVirtual, options.ratHourMode) + 0.5).floor() +
      1;
  if (day < 1 || day > 33) {
    throw StateError('invalid solar day from previous Jie: $day');
  }
  final yearPillar = options.wuHuDunYearBoundary == PillarBoundary.lunar
      ? lunarPillars.year
      : solar.year;
  final anchors = computePlacementAnchors(
    ZiweiPlacementInput(
      yearGanIndex: ganzhiStem(yearPillar),
      yearZhiIndex: ganzhiBranch(yearPillar),
      month: month,
      day: lunar.day,
      hourZhiIndex: ganzhiBranch(lunarPillars.hour),
    ),
    chartMode: options.chartMode,
  );
  return ResolvedZiweiBirth(
    clockTime: clockTime,
    virtualTime: virtual,
    jdUT1: jd,
    lunarDate: lunar,
    solarTermPillars: solar,
    lunarPillars: lunarPillars,
    effectiveLunarYear: year,
    effectiveLunarMonth: month,
    solarDayFromPreviousJie: day,
    anchors: anchors,
    options: options,
  );
}

/// Historical source year must be supplied by the caller for reform periods.
({int year, int month}) resolveEffectiveLunarMonth(
  LunarDate date,
  LeapMonthStrategy strategy,
) {
  _checked(date.month, 1, 13, 'month');
  _checked(date.day, 1, 30, 'day');
  var year = date.year, month = date.month == 13 ? 12 : date.month;
  if (date.isLeap &&
      (strategy == LeapMonthStrategy.asNext ||
          strategy == LeapMonthStrategy.splitAfterFifteenth && date.day > 15)) {
    month++;
    if (month > 12) {
      month = 1;
      year++;
    }
  }
  return (year: year, month: month);
}

int solarDayFromPreviousJie(
  double jdUT1,
  CalendarDate virtualTime,
  ZiweiOptions options,
) {
  final n = _solarLogical(jdUT1, virtualTime, options).toInt();
  return _checked(n, 1, 33, 'solarDayFromPreviousJie');
}

({ZiweiAnchors anchors, int bodyPalace}) computeZiweiAnchors(
  ResolvedZiweiBirth facts,
  ZiweiOptions options,
) {
  final year = options.wuHuDunYearBoundary == PillarBoundary.lunar
      ? facts.lunarPillars.year
      : facts.solarTermPillars.year;
  final a = computePlacementAnchors(
    ZiweiPlacementInput(
      yearGanIndex: ganzhiStem(year),
      yearZhiIndex: ganzhiBranch(year),
      month: facts.effectiveLunarMonth,
      day: facts.lunarDate.day,
      hourZhiIndex: ganzhiBranch(facts.lunarPillars.hour),
    ),
    chartMode: options.chartMode,
  );
  return (
    anchors: ZiweiAnchors(a, facts.solarTermPillars, facts.lunarPillars),
    bodyPalace: a.bodyPalace,
  );
}

List<int> flattenZiweiAnchors(ZiweiAnchors anchors) => List.unmodifiable([
  for (final p in [anchors.solarTerm, anchors.lunar])
    for (final value in p.toJson().values) ...[
      ganzhiStem(value),
      ganzhiBranch(value),
    ],
  anchors.bureau.index,
  anchors.ziwei,
  anchors.tianfu,
  ...anchors.palacePositions,
]);
