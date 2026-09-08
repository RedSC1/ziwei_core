part of '../ziwei_core.dart';

class ZiweiLimitContext {
  const ZiweiLimitContext({
    this.decade,
    this.smallLimit,
    this.year,
    this.month,
    this.day,
    this.hour,
  });
  final DecadeLimit? decade;
  final SmallLimit? smallLimit;
  final FlowYearLimit? year;
  final FlowMonthLimit? month;
  final FlowDayLimit? day;
  final FlowHourLimit? hour;
  Map<String, Object> toJson() => {
    if (decade != null) 'decade': decade!.toJson(),
    if (smallLimit != null) 'smallLimit': smallLimit!.toJson(),
    if (year != null) 'year': year!.toJson(),
    if (month != null) 'month': month!.toJson(),
    if (day != null) 'day': day!.toJson(),
    if (hour != null) 'hour': hour!.toJson(),
  };
}

class ZiweiLimitManager {
  ZiweiLimitManager(this.baseChart)
    : timeline = ZiweiTimelineProvider(baseChart);
  final ZiweiChart baseChart;
  final ZiweiTimelineProvider timeline;
  ZiweiLimitContext _context = const ZiweiLimitContext();
  int? _timelineYear;
  ZiweiFlowTarget? _target;
  ResolvedZiweiFlow? _resolved;
  ZiweiLimitContext get context => _context;
  int? get timelineYear => _timelineYear;
  ZiweiFlowTarget? get currentTarget => _target;
  ResolvedZiweiFlow? get resolvedFlow => _resolved;
  int? get timelineDecadeIndex => _timelineYear == null
      ? _context.decade?.index
      : makeDecadeForYear(
          baseChart,
          getEffectiveBirthYear(baseChart),
          _timelineYear!,
        ).index;
  ZiweiDynamicChart get dynamicChart {
    final limits = [
          _context.decade?.limit,
          _context.year?.limit,
          _context.month?.limit,
          _context.day?.limit,
          _context.hour?.limit,
        ],
        layers = <ZiweiFlowLayer>[];
    for (var i = 0; i < 5; i++) {
      if (limits[i] == null) break;
      layers.add(
        makeFlowLayer(baseChart, FlowLevel.values[i], limits[i]!.coordinate),
      );
    }
    return ZiweiDynamicChart(
      baseChart,
      flowStack: layers,
      smallLimitLayer: _context.smallLimit == null
          ? null
          : makeSmallLimitLayer(baseChart, _context.smallLimit!.coordinate),
    );
  }

  TimelineManifest get manifest => timeline.getManifest(
    year: _timelineYear,
    decadeIndex: timelineDecadeIndex,
    month: _context.month?.month,
    isLeap: _context.month?.isLeap ?? false,
    effectiveMonth: _context.month?.effectiveMonth,
    effectiveYear: _context.month?.effectiveYear,
    day: _context.day?.day,
  );
  void _clearTarget() {
    _target = null;
    _resolved = null;
  }

  void reset() {
    _context = const ZiweiLimitContext();
    _timelineYear = null;
    _clearTarget();
  }

  void setDecadeIndex(int index, {int? targetChildhoodYear}) {
    final y = getEffectiveBirthYear(baseChart),
        d = index == 0
            ? makeChildhoodDecade(baseChart, y, targetChildhoodYear ?? y)
            : makeDecadeByIndex(baseChart, y, index);
    _context = ZiweiLimitContext(decade: d);
    _timelineYear = null;
    _clearTarget();
  }

  ZiweiLimitContext _yearContext(int year, {FlowMonthLimit? month}) {
    final y = getEffectiveBirthYear(baseChart);
    return ZiweiLimitContext(
      decade: makeDecadeForYear(baseChart, y, year),
      smallLimit: makeSmallLimit(
        baseChart,
        ganzhiBranch(baseChart.facts.solarTermPillars.year),
        year - y + 1,
      ),
      year: makeFlowYear(baseChart, year),
      month: month,
    );
  }

  void setYear(int year) {
    final c = _yearContext(year);
    _context = c;
    _timelineYear = year;
    _clearTarget();
  }

  void addYear(int delta) {
    if (_timelineYear != null) setYear(_timelineYear! + delta);
  }

  void selectMonth(MonthNode node) {
    if (_timelineYear == null) throw StateError('select a year first');
    final m = makeFlowMonthFromBuildingBranch(
      baseChart,
      node.lunarYear,
      node.month,
      node.sequence,
      node.isLeap,
      node.monthBuildingBranch,
      day: node.dayStart,
      effectiveMonthOverride: node.effectiveMonth,
      effectiveYearOverride: node.effectiveYear,
      monthName: node.monthName,
    );
    _context = _yearContext(node.effectiveYear, month: m);
    _timelineYear = node.effectiveYear;
    _clearTarget();
  }

  void setMonth(
    int month, {
    bool isLeap = false,
    int? effectiveMonth,
    int? effectiveYear,
  }) {
    if (_timelineYear == null) throw StateError('select a year first');
    final n = timeline
        .getMonths(_timelineYear!)
        .where(
          (v) =>
              v.month == month &&
              v.isLeap == isLeap &&
              (effectiveMonth == null || v.effectiveMonth == effectiveMonth) &&
              (effectiveYear == null || v.effectiveYear == effectiveYear),
        )
        .firstOrNull;
    if (n == null) throw RangeError('flow month absent');
    selectMonth(n);
  }

  void addMonth(int delta) {
    final current = _context.month;
    if (delta == 0 || current == null || _timelineYear == null) return;
    var year = _timelineYear!,
        months = timeline.getMonths(year),
        index = months.indexWhere(
          (n) =>
              n.month == current.month &&
              n.sequence == current.sequence &&
              n.isLeap == current.isLeap &&
              n.effectiveMonth == current.effectiveMonth &&
              n.effectiveYear == current.effectiveYear,
        );
    if (index < 0) throw StateError('month absent');
    for (var step = 0; step < delta.abs(); step++) {
      index += delta.sign;
      if (index >= months.length) {
        year++;
        months = timeline.getMonths(year);
        index = 0;
      } else if (index < 0) {
        year--;
        months = timeline.getMonths(year);
        index = months.length - 1;
      }
      if (months.isEmpty) throw StateError('no flow months');
    }
    // Validate the destination before changing the manager's current state.
    final n = months[index],
        m = makeFlowMonthFromBuildingBranch(
          baseChart,
          n.lunarYear,
          n.month,
          n.sequence,
          n.isLeap,
          n.monthBuildingBranch,
          day: n.dayStart,
          effectiveMonthOverride: n.effectiveMonth,
          effectiveYearOverride: n.effectiveYear,
          monthName: n.monthName,
        ),
        next = _yearContext(n.effectiveYear, month: m);
    _context = next;
    _timelineYear = year;
    _clearTarget();
  }

  void selectDay(DayNode node) {
    final m = _context.month;
    if (m == null) throw StateError('select a month first');
    final d = makeFlowDay(baseChart, m, node.day, node.stem);
    _context = ZiweiLimitContext(
      decade: _context.decade,
      smallLimit: _context.smallLimit,
      year: _context.year,
      month: m,
      day: d,
    );
    _clearTarget();
  }

  void setDay(int day) {
    final m = _context.month;
    if (m == null || _timelineYear == null) {
      throw StateError('select a month first');
    }
    final n = timeline
        .getDays(
          _timelineYear!,
          m.month,
          isLeap: m.isLeap,
          effectiveMonth: m.effectiveMonth,
          effectiveYear: m.effectiveYear,
        )
        .where((v) => v.day == day)
        .firstOrNull;
    if (n == null) throw RangeError('flow day absent');
    selectDay(n);
  }

  void selectHour(HourNode node) {
    final d = _context.day;
    if (d == null) throw StateError('select a day first');
    final segment = node.isEarlyRat
            ? RatHourSegment.early
            : node.isLateRat
            ? RatHourSegment.late
            : node.branchIndex == 0
            ? RatHourSegment.unified
            : RatHourSegment.none,
        h = makeFlowHourFromPillar(
          baseChart,
          d,
          makeGanzhi(node.stem, node.branchIndex),
          segment,
        );
    _context = ZiweiLimitContext(
      decade: _context.decade,
      smallLimit: _context.smallLimit,
      year: _context.year,
      month: _context.month,
      day: d,
      hour: h,
    );
    _clearTarget();
  }

  void setHour(int index) {
    final day = _context.day;
    if (day == null) throw StateError('select a day first');
    final s = day.limit.coordinate.stem,
        n = timeline
            .getHours(makeGanzhi(s, s & 1))
            .where((v) => v.hourIndex == index)
            .firstOrNull;
    if (n == null) throw RangeError('flow hour absent');
    selectHour(n);
  }

  void _install(ResolvedZiweiFlow f, FlowLevel depth) {
    _resolved = f;
    _timelineYear = f.year.year;
    _context = ZiweiLimitContext(
      decade: f.decade,
      smallLimit: f.smallLimit,
      year: depth.index >= 1 ? f.year : null,
      month: depth.index >= 2 ? f.month : null,
      day: depth.index >= 3 ? f.day : null,
      hour: depth.index >= 4 ? f.hour : null,
    );
  }

  void setPhysicalTime(
    ZonedTime target, {
    FlowLevel deepestLevel = FlowLevel.hour,
  }) {
    final flow = resolveZiweiFlow(baseChart, target);
    _install(flow, deepestLevel);
    _target = ZiweiFlowTarget(
      target.toJulianTime().jdUT1,
      resolveZiweiVirtualTime(target, baseChart.options),
      ratHourSegment: flow.targetRatHourSegment,
    );
  }

  void _step(int dir, bool hour) {
    if (_target == null) throw StateError('setPhysicalTime before stepping');
    final next = hour
            ? stepZiweiFlowHourTarget(
                _target!,
                baseChart.options.ratHourMode,
                dir,
                options: baseChart.options,
              )
            : stepZiweiFlowDayTarget(_target!, dir, options: baseChart.options),
        flow = resolveZiweiFlowFromInstant(
          baseChart,
          next.jdUT1,
          next.virtualTime,
        );
    _install(flow, FlowLevel.hour);
    _target = next;
  }

  void nextDay() => _step(1, false);
  void previousDay() => _step(-1, false);
  void nextHour() => _step(1, true);
  void previousHour() => _step(-1, true);
  void clear(FlowLevel level) {
    final n = level.index;
    if (n <= 1) _timelineYear = null;
    _context = ZiweiLimitContext(
      decade: n > 0 ? _context.decade : null,
      smallLimit: n > 1 ? _context.smallLimit : null,
      year: n > 1 ? _context.year : null,
      month: n > 2 ? _context.month : null,
      day: n > 3 ? _context.day : null,
      hour: null,
    );
    _clearTarget();
  }

  void clearDecade() => clear(FlowLevel.decade);
  void clearYear() => clear(FlowLevel.year);
  void clearMonth() {
    if (_timelineYear == null) {
      clear(FlowLevel.month);
    } else {
      setYear(_timelineYear!);
    }
  }

  void clearDay() => clear(FlowLevel.day);
  void clearHour() => clear(FlowLevel.hour);
}
