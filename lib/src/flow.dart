part of '../ziwei_core.dart';

class ZiweiFlowLayer {
  ZiweiFlowLayer(
    this.level,
    this.coordinate,
    Map<String, int> transforms,
    List<int> positions,
  ) : transforms = Map.unmodifiable(transforms),
      starPositions = List.unmodifiable(positions),
      starBitsets = List.unmodifiable(
        List.generate(
          12,
          (b) => List.generate(positions.length, (i) => i)
              .where((i) => positions[i] == b)
              .fold(BigInt.zero, (v, i) => v | (BigInt.one << i)),
        ),
      );
  final FlowLevel? level;
  final FlowCoordinate coordinate;
  final Map<String, int> transforms;
  final List<int> starPositions;
  final List<BigInt> starBitsets;
  int get lifePalace => coordinate.branch;
  Map<String, Object> toJson() => {
    if (level != null) 'level': level!.index,
    'lifePalace': lifePalace,
    'coordinate': coordinate.toJson(),
    'transforms': transforms,
    'starPositions': starPositions,
  };
}

typedef ZiweiSmallLimitLayer = ZiweiFlowLayer;
ZiweiFlowLayer _layer(ZiweiChart chart, FlowLevel? level, FlowCoordinate c) {
  final r = chart._rules, positions = List<int>.filled(r.catalog.length, -1);
  final values = {
    'anchor.bureau': chart.anchors.bureau.index,
    'anchor.ziwei': chart.anchors.ziwei,
    'anchor.tianfu': chart.anchors.tianfu,
    'anchor.life': chart.anchors.palacePositions[0],
    'anchor.body': chart.bodyPalace,
    'birth.gender': chart.options.gender.index,
    'lunar.year_stem': c.stem,
    'solar.year_stem': c.stem,
    'lunar.year_branch': c.branch,
    'solar.year_branch': c.branch,
  };
  for (final rule in r.flowPlacements) {
    positions[rule.starId] = rule.evaluate((s) => values[s]);
  }
  return ZiweiFlowLayer(level, c, r.sihua[c.stem], positions);
}

ZiweiFlowLayer makeFlowLayer(
  ZiweiChart chart,
  FlowLevel level,
  FlowCoordinate coordinate,
) => _layer(chart, level, coordinate);
ZiweiSmallLimitLayer makeSmallLimitLayer(
  ZiweiChart chart,
  FlowCoordinate coordinate,
) => _layer(chart, null, coordinate);

class ZiweiDynamicChart {
  ZiweiDynamicChart(
    this.natal, {
    List<ZiweiFlowLayer> flowStack = const [],
    this.smallLimitLayer,
  }) : flowStack = List.unmodifiable(flowStack) {
    if (flowStack.length > 5) throw ArgumentError('too many layers');
    for (var i = 0; i < flowStack.length; i++) {
      if (flowStack[i].level?.index != i) {
        throw ArgumentError('layers must be contiguous');
      }
    }
  }
  final ZiweiChart natal;
  final List<ZiweiFlowLayer> flowStack;
  final ZiweiSmallLimitLayer? smallLimitLayer;
  ZiweiDynamicChart push(ZiweiFlowLayer layer) => ZiweiDynamicChart(
    natal,
    flowStack: [...flowStack, layer],
    smallLimitLayer: smallLimitLayer,
  );
  ZiweiDynamicChart truncate(FlowLevel firstRemoved) => ZiweiDynamicChart(
    natal,
    flowStack: flowStack.take(firstRemoved.index).toList(),
    smallLimitLayer: smallLimitLayer,
  );
  ZiweiDynamicChart withSmallLimit(ZiweiSmallLimitLayer? layer) =>
      ZiweiDynamicChart(natal, flowStack: flowStack, smallLimitLayer: layer);
  ZiweiFlowLayer? layer(FlowLevel level) =>
      level.index < flowStack.length ? flowStack[level.index] : null;
  ZiweiFlowLayer? _at(FlowLevel? level) => level == null
      ? (flowStack.isEmpty ? null : flowStack.last)
      : layer(level);
  int? getFlowStarPosition(int id, {FlowLevel? level}) {
    final p = _at(level)?.starPositions;
    return p == null || id < 0 || id >= p.length || p[id] < 0 ? null : p[id];
  }

  List<int> getFlowStarIdsAtBranch(int branch, {FlowLevel? level}) {
    _checked(branch, 0, 11, 'branch');
    final p = _at(level)?.starPositions;
    if (p == null) return const [];
    return List.unmodifiable(
      List.generate(p.length, (i) => i).where((i) => p[i] == branch),
    );
  }

  ZiweiStarPlacement? _star(int id, ZiweiFlowLayer? layer) {
    if (layer == null ||
        id < 0 ||
        id >= layer.starPositions.length ||
        layer.starPositions[id] < 0) {
      return null;
    }
    final b = layer.starPositions[id];
    return ZiweiStarPlacement(
      natal.getStarInfo(id),
      b,
      (layer.lifePalace - b) % 12,
      brightnessAt(natal._rules, id, b),
      0,
    );
  }

  ZiweiStarPlacement? getFlowStar(int id, {FlowLevel? level}) =>
      _star(id, _at(level));
  ZiweiStarPlacement? getSmallLimitStar(int id) => _star(id, smallLimitLayer);
  int _life(FlowLevel? level, bool smallLimit) {
    if (!smallLimit && level == null) return natal.anchors.palacePositions[0];
    return (smallLimit ? smallLimitLayer : layer(level!))?.lifePalace ??
        (throw StateError('requested layer absent'));
  }

  int getRoleAtBranch(
    int branch, {
    FlowLevel? level,
    bool smallLimit = false,
  }) => (_life(level, smallLimit) - _checked(branch, 0, 11, 'branch')) % 12;
  int getBranchForRole(int role, {FlowLevel? level, bool smallLimit = false}) =>
      (_life(level, smallLimit) - _checked(role, 0, 11, 'role')) % 12;
  Map<String, Object?> toJson() => {
    'natal': natal.toJson(),
    'flowStack': flowStack.map((s) => s.toJson()).toList(),
    'smallLimit': smallLimitLayer?.toJson(),
  };
}

class ResolvedFlowMonthMetadata {
  const ResolvedFlowMonthMetadata(
    this.effectiveBaseYear,
    this.logicalMonth,
    this.sequence,
    this.isLeap,
    this.monthName,
    this.monthBuildingBranch,
    this.firstCivilDayNumber,
    this.dayCount,
  );
  final int effectiveBaseYear,
      logicalMonth,
      sequence,
      monthBuildingBranch,
      firstCivilDayNumber,
      dayCount;
  final bool isLeap;
  final MonthName monthName;
}

ResolvedFlowMonthMetadata resolveLunarFlowMonthMetadata(
  ZiweiChart chart,
  double targetJdUT1,
  LunarDate lunar,
) {
  final first = lunarToSolar(
        LunarDate(
          year: lunar.year,
          month: lunar.month,
          day: 1,
          isLeap: lunar.isLeap,
          monthName: lunar.monthName,
        ),
        options: chart.options.calendarOptions,
      ),
      firstDay = (_jd(first) + 0.5).floor();
  bool same(LunarMonth m) =>
      m.lunarYear == lunar.year &&
      m.month == lunar.month &&
      m.isLeap == lunar.isLeap &&
      m.monthName == lunar.monthName;
  final byDay = <int, LunarMonth>{};
  for (final offset in [0, -220, 220]) {
    for (final m in calculateChineseCalendarYear(
      targetJdUT1 + offset,
      options: chart.options.calendarOptions,
    ).months) {
      final prior = byDay[m.firstCivilDayNumber];
      if (prior == null || !same(prior) && same(m)) {
        byDay[m.firstCivilDayNumber] = m;
      }
    }
  }
  final months = byDay.values.toList()
    ..sort((a, b) => a.firstCivilDayNumber.compareTo(b.firstCivilDayNumber));
  final target = months
      .where((m) => m.firstCivilDayNumber == firstDay && same(m))
      .firstOrNull;
  if (target == null) {
    throw StateError('lunar month absent from nearby windows');
  }
  final historic = months
          .where((m) => m.historicalYear == target.historicalYear)
          .toList(),
      seq = historic.indexWhere((m) => m.firstCivilDayNumber == firstDay) + 1;
  return ResolvedFlowMonthMetadata(
    target.historicalYear,
    lunar.month == 13 ? 12 : lunar.month,
    seq,
    lunar.isLeap,
    lunar.monthName,
    target.monthBuildingBranch,
    firstDay,
    target.dayCount,
  );
}

class ResolvedZiweiFlow {
  const ResolvedZiweiFlow(
    this.effectiveBirthYear,
    this.effectiveTargetYear,
    this.targetMonth,
    this.targetMonthSequence,
    this.targetMonthBuildingBranch,
    this.targetDay,
    this.targetHourIndex,
    this.targetRatHourSegment,
    this.targetMonthIsLeap,
    this.decade,
    this.smallLimit,
    this.year,
    this.month,
    this.day,
    this.hour,
  );
  final int effectiveBirthYear,
      effectiveTargetYear,
      targetMonth,
      targetMonthSequence,
      targetMonthBuildingBranch,
      targetDay,
      targetHourIndex;
  final RatHourSegment targetRatHourSegment;
  final bool targetMonthIsLeap;
  final DecadeLimit decade;
  final SmallLimit smallLimit;
  final FlowYearLimit year;
  final FlowMonthLimit month;
  final FlowDayLimit day;
  final FlowHourLimit hour;
  Map<String, Object> toJson() => {
    'effectiveBirthYear': effectiveBirthYear,
    'effectiveTargetYear': effectiveTargetYear,
    'targetMonth': targetMonth,
    'targetMonthSequence': targetMonthSequence,
    'targetMonthBuildingBranch': targetMonthBuildingBranch,
    'targetDay': targetDay,
    'targetHourIndex': targetHourIndex,
    'targetRatHourSegment': targetRatHourSegment.index,
    'targetMonthIsLeap': targetMonthIsLeap,
    'decade': decade.toJson(),
    'smallLimit': smallLimit.toJson(),
    'year': year.toJson(),
    'month': month.toJson(),
    'day': day.toJson(),
    'hour': hour.toJson(),
  };
}

RatHourSegment _segment(CalendarDate v, RatHourMode mode, int branch) =>
    branch != 0
    ? RatHourSegment.none
    : mode == RatHourMode.nextDay
    ? RatHourSegment.unified
    : v.hour >= 23
    ? RatHourSegment.late
    : RatHourSegment.early;
double _solarLogical(double jd, CalendarDate v, ZiweiOptions o) {
  final previous = getPreviousJie(jd, options: o.calendarOptions),
      jv = _jd(
        resolveZiweiVirtualTime(
          previous.time.toZonedTime(o.utcOffsetMinutes.toInt()),
          o,
        ),
      );
  return (_logical(_jd(v), o.ratHourMode) + 0.5).floorToDouble() -
      (_logical(jv, o.ratHourMode) + 0.5).floor() +
      1;
}

ResolvedZiweiFlow resolveZiweiFlowFromInstant(
  ZiweiChart chart,
  double jdUT1,
  CalendarDate targetVirtualTime, {
  PillarBoundary? boundary,
}) {
  if (!jdUT1.isFinite || jdUT1 < chart.facts.jdUT1) {
    throw RangeError('target precedes birth or is non-finite');
  }
  final o = chart.options,
      b = boundary ?? o.flowLimitBoundary,
      v = normalizeChartVirtualTime(targetVirtualTime),
      p = calculateFourPillars(
        jdUT1,
        v,
        options: o.calendarOptions,
        ratHourMode: o.ratHourMode,
        pillarHistoricalMode: o.pillarHistoricalMode,
      ),
      birthYear = getEffectiveBirthYear(chart, boundary: b);
  late FlowMonthLimit month;
  late int day;
  if (b == PillarBoundary.lunar) {
    final lunar = resolveZiweiLogicalLunarDate(v, o),
        m = resolveLunarFlowMonthMetadata(chart, jdUT1, lunar);
    day = lunar.day;
    month = makeFlowMonthFromBuildingBranch(
      chart,
      lunar.year,
      m.logicalMonth,
      m.sequence,
      m.isLeap,
      m.monthBuildingBranch,
      day: day,
      monthName: m.monthName,
      effectiveBaseYear: m.effectiveBaseYear,
    );
  } else {
    final branch = ganzhiBranch(p.year),
        year = _yearBranch(v.year) == branch
            ? v.year
            : _yearBranch(v.year - 1) == branch
            ? v.year - 1
            : throw StateError('inconsistent target year');
    final m = (ganzhiBranch(p.month) - 2) % 12 + 1;
    day = _solarLogical(jdUT1, v, o).toInt();
    month = makeFlowMonth(chart, year, m);
  }
  final effectiveYear = month.effectiveYear,
      age = effectiveYear - birthYear + 1;
  if (age < 1) throw RangeError('target precedes effective birth year');
  final decade = makeDecadeForYear(chart, birthYear, effectiveYear),
      small = makeSmallLimit(
        chart,
        ganzhiBranch(chart.facts.solarTermPillars.year),
        age,
      ),
      year = makeFlowYear(chart, effectiveYear),
      d = makeFlowDay(chart, month, day, ganzhiStem(p.day)),
      segment = _segment(v, o.ratHourMode, ganzhiBranch(p.hour)),
      h = makeFlowHourFromPillar(chart, d, p.hour, segment);
  return ResolvedZiweiFlow(
    birthYear,
    effectiveYear,
    month.month,
    month.sequence,
    month.monthBuildingBranch,
    day,
    h.hourIndex,
    segment,
    month.isLeap,
    decade,
    small,
    year,
    month,
    d,
    h,
  );
}

ResolvedZiweiFlow resolveZiweiFlow(
  ZiweiChart chart,
  ZonedTime target, {
  PillarBoundary? boundary,
}) => resolveZiweiFlowFromInstant(
  chart,
  target.toJulianTime().jdUT1,
  resolveZiweiVirtualTime(target, chart.options),
  boundary: boundary,
);
ZiweiDynamicChart dynamicChartFromResolvedFlow(
  ZiweiChart chart,
  ResolvedZiweiFlow flow, {
  FlowLevel deepestLevel = FlowLevel.hour,
}) {
  final coords = [
    flow.decade.limit.coordinate,
    flow.year.limit.coordinate,
    flow.month.limit.coordinate,
    flow.day.limit.coordinate,
    flow.hour.limit.coordinate,
  ];
  return ZiweiDynamicChart(
    chart,
    flowStack: [
      for (var i = 0; i <= deepestLevel.index; i++)
        makeFlowLayer(chart, FlowLevel.values[i], coords[i]),
    ],
    smallLimitLayer: makeSmallLimitLayer(chart, flow.smallLimit.coordinate),
  );
}

({ZiweiDynamicChart chart, ResolvedZiweiFlow flow}) dynamicChartForTime(
  ZiweiChart chart,
  ZonedTime target, {
  FlowLevel deepestLevel = FlowLevel.hour,
}) {
  final flow = resolveZiweiFlow(chart, target);
  return (
    chart: dynamicChartFromResolvedFlow(
      chart,
      flow,
      deepestLevel: deepestLevel,
    ),
    flow: flow,
  );
}

class ZiweiFlowTarget {
  const ZiweiFlowTarget(
    this.jdUT1,
    this.virtualTime, {
    this.ratHourSegment = RatHourSegment.none,
  });
  final double jdUT1;
  final CalendarDate virtualTime;
  final RatHourSegment ratHourSegment;
}

/// Preserve the virtual clock position; pass [options] for solar-clock inversion.
/// The limit manager supplies its chart options automatically.
ZiweiFlowTarget stepZiweiFlowHourTarget(
  ZiweiFlowTarget current,
  RatHourMode mode,
  int direction, {
  ZiweiOptions? options,
}) {
  if (direction != 1 && direction != -1) {
    throw ArgumentError('direction must be ±1');
  }
  final v = normalizeChartVirtualTime(current.virtualTime),
      split = mode != RatHourMode.nextDay,
      one =
          split &&
          (direction > 0
              ? v.hour >= 22 || v.hour < 1
              : v.hour >= 23 || v.hour < 2),
      step = direction * (one ? 1 : 2),
      hour = v.hour + step;
  final date = calendarDateFromJulianDay(
        julianDay(year: v.year, month: v.month, day: v.day, hour: 12) +
            (hour / 24).floor(),
      ),
      virtual = CalendarDate(
        year: date.year,
        month: date.month,
        day: date.day,
        hour: hour % 24,
        minute: v.minute,
        second: v.second,
      );
  return ZiweiFlowTarget(
    options == null
        ? current.jdUT1 + step / 24
        : _virtualToUt1(virtual, options),
    virtual,
    ratHourSegment: _segment(virtual, mode, ((virtual.hour + 1) ~/ 2) % 12),
  );
}

/// Preserve virtual time of day. Pass [options] for true/mean solar clocks.
ZiweiFlowTarget stepZiweiFlowDayTarget(
  ZiweiFlowTarget current,
  int direction, {
  ZiweiOptions? options,
}) {
  if (direction != 1 && direction != -1) {
    throw ArgumentError('direction must be ±1');
  }
  final v = normalizeChartVirtualTime(current.virtualTime),
      date = calendarDateFromJulianDay(
        julianDay(year: v.year, month: v.month, day: v.day, hour: 12) +
            direction,
      );
  final virtual = CalendarDate(
    year: date.year,
    month: date.month,
    day: date.day,
    hour: v.hour,
    minute: v.minute,
    second: v.second,
  );
  return ZiweiFlowTarget(
    options == null
        ? current.jdUT1 + direction
        : _virtualToUt1(virtual, options),
    virtual,
    ratHourSegment: options == null
        ? current.ratHourSegment
        : _segment(
            virtual,
            options.ratHourMode,
            ((virtual.hour + 1) ~/ 2) % 12,
          ),
  );
}
