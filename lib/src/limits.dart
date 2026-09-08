part of '../ziwei_core.dart';

enum FlowLevel { decade, year, month, day, hour }

enum RatHourSegment { none, unified, early, late }

enum ChildhoodStrategy { skip, sequential }

enum FlowMonthPalaceStrategy { physicalSequence, effectiveMonth }

class FlowCoordinate {
  FlowCoordinate({required int stem, required int branch})
    : stem = _checked(stem, 0, 9, 'stem'),
      branch = _checked(branch, 0, 11, 'branch');
  final int stem, branch;
  Map<String, int> toJson() => {'stem': stem, 'branch': branch};
}

class LimitCoordinate {
  const LimitCoordinate(this.level, this.coordinate, this.natalPalaceId);
  final FlowLevel level;
  final FlowCoordinate coordinate;
  final int natalPalaceId;
  Map<String, Object> toJson() => {
    'level': level.index,
    'coordinate': coordinate.toJson(),
    'natalPalaceId': natalPalaceId,
  };
}

class DecadeLimit {
  const DecadeLimit(
    this.limit,
    this.index,
    this.startAge,
    this.endAge,
    this.startYear,
    this.endYear,
    this.isChildhood,
  );
  final LimitCoordinate limit;
  final int index, startAge, endAge, startYear, endYear;
  final bool isChildhood;
  Map<String, Object> toJson() => {
    'limit': limit.toJson(),
    'index': index,
    'startAge': startAge,
    'endAge': endAge,
    'startYear': startYear,
    'endYear': endYear,
    'isChildhood': isChildhood,
  };
}

class SmallLimit {
  const SmallLimit(this.coordinate, this.natalPalaceId, this.virtualAge);
  final FlowCoordinate coordinate;
  final int natalPalaceId, virtualAge;
  Map<String, Object> toJson() => {
    'coordinate': coordinate.toJson(),
    'natalPalaceId': natalPalaceId,
    'virtualAge': virtualAge,
  };
}

class FlowYearLimit {
  const FlowYearLimit(this.limit, this.year);
  final LimitCoordinate limit;
  final int year;
  Map<String, Object> toJson() => {'limit': limit.toJson(), 'year': year};
}

class FlowMonthLimit {
  const FlowMonthLimit(
    this.limit,
    this.year,
    this.month,
    this.sequence,
    this.effectiveMonth,
    this.effectiveYear,
    this.isLeap,
    this.monthBuildingBranch,
    this.palaceMonthIndex,
    this.doujun,
  );
  final LimitCoordinate limit;
  final int year,
      month,
      sequence,
      effectiveMonth,
      effectiveYear,
      monthBuildingBranch,
      palaceMonthIndex,
      doujun;
  final bool isLeap;
  Map<String, Object> toJson() => {
    'limit': limit.toJson(),
    'year': year,
    'month': month,
    'sequence': sequence,
    'effectiveMonth': effectiveMonth,
    'effectiveYear': effectiveYear,
    'isLeap': isLeap,
    'monthBuildingBranch': monthBuildingBranch,
    'palaceMonthIndex': palaceMonthIndex,
    'doujun': doujun,
  };
}

class FlowDayLimit {
  const FlowDayLimit(this.limit, this.day);
  final LimitCoordinate limit;
  final int day;
  Map<String, Object> toJson() => {'limit': limit.toJson(), 'day': day};
}

class FlowHourLimit {
  const FlowHourLimit(this.limit, this.hourIndex, this.ratHourSegment);
  final LimitCoordinate limit;
  final int hourIndex;
  final RatHourSegment ratHourSegment;
  Map<String, Object> toJson() => {
    'limit': limit.toJson(),
    'hourIndex': hourIndex,
    'ratHourSegment': ratHourSegment.index,
  };
}

int _yearStem(int y) => (y + 6) % 10;
int _yearBranch(int y) => (y + 8) % 12;
FlowCoordinate _palaceCoordinate(ZiweiChart chart, int b) =>
    FlowCoordinate(stem: chart.palaceStems[b], branch: b);
LimitCoordinate _limit(ZiweiChart chart, FlowLevel level, FlowCoordinate c) =>
    LimitCoordinate(level, c, chart.palaces[c.branch].palaceId);
int getEffectiveBirthYear(ZiweiChart chart, {PillarBoundary? boundary}) {
  if ((boundary ?? chart.options.flowLimitBoundary) == PillarBoundary.lunar) {
    return chart.facts.effectiveLunarYear;
  }
  final y = chart.facts.virtualTime.year,
      s = ganzhiStem(chart.facts.solarTermPillars.year);
  if (_yearStem(y) == s) return y;
  if (_yearStem(y - 1) == s) return y - 1;
  throw StateError('inconsistent birth year');
}

int getStartDecadeYear(ZiweiChart chart, {int? effectiveBirthYear}) =>
    (effectiveBirthYear ?? getEffectiveBirthYear(chart)) +
    chart.anchors.bureau.number -
    1;
DecadeLimit makeDecadeByIndex(
  ZiweiChart chart,
  int effectiveBirthYear,
  int index,
) {
  if (index < 1) throw RangeError('decade index must be >= 1');
  final offset = index - 1,
      start = chart.anchors.bureau.number,
      b =
          (chart.anchors.palacePositions[0] +
              (isForward(_yearStem(effectiveBirthYear), chart.options.gender)
                  ? offset
                  : -offset)) %
          12,
      y = effectiveBirthYear + start - 1 + offset * 10;
  return DecadeLimit(
    _limit(chart, FlowLevel.decade, _palaceCoordinate(chart, b)),
    index,
    start + offset * 10,
    start + offset * 10 + 9,
    y,
    y + 9,
    false,
  );
}

DecadeLimit makeChildhoodDecade(
  ZiweiChart chart,
  int effectiveBirthYear,
  int targetYear, {
  ChildhoodStrategy? strategy,
}) {
  final age = targetYear - effectiveBirthYear + 1;
  _checked(age, 1, chart.anchors.bureau.number - 1, 'childhood age');
  final step =
      (strategy ?? chart.options.childhoodStrategy) == ChildhoodStrategy.skip
      ? -[0, 4, 5, 2, 10, 8][age - 1]
      : (age - 1) *
            (isForward(_yearStem(effectiveBirthYear), chart.options.gender)
                ? 1
                : -1);
  final b = (chart.anchors.palacePositions[0] + step) % 12;
  return DecadeLimit(
    _limit(chart, FlowLevel.decade, _palaceCoordinate(chart, b)),
    0,
    age,
    age,
    targetYear,
    targetYear,
    true,
  );
}

DecadeLimit makeDecadeForYear(
  ZiweiChart chart,
  int effectiveBirthYear,
  int targetYear, {
  ChildhoodStrategy? strategy,
}) {
  if (targetYear < effectiveBirthYear) {
    throw RangeError('target precedes birth');
  }
  final start = getStartDecadeYear(
    chart,
    effectiveBirthYear: effectiveBirthYear,
  );
  return targetYear < start
      ? makeChildhoodDecade(
          chart,
          effectiveBirthYear,
          targetYear,
          strategy: strategy,
        )
      : makeDecadeByIndex(
          chart,
          effectiveBirthYear,
          (targetYear - start) ~/ 10 + 1,
        );
}

SmallLimit makeSmallLimit(
  ZiweiChart chart,
  int birthSolarYearBranch,
  int virtualAge,
) {
  _checked(birthSolarYearBranch, 0, 11, 'birthSolarYearBranch');
  if (virtualAge < 1) throw RangeError('virtualAge must be positive');
  final b =
      ([10, 7, 4, 1][birthSolarYearBranch % 4] +
          (virtualAge - 1) *
              (chart.options.gender == ZiweiGender.male ? 1 : -1)) %
      12;
  return SmallLimit(
    _palaceCoordinate(chart, b),
    chart.palaces[b].palaceId,
    virtualAge,
  );
}

FlowYearLimit makeFlowYear(ZiweiChart chart, int year) => FlowYearLimit(
  _limit(
    chart,
    FlowLevel.year,
    FlowCoordinate(stem: _yearStem(year), branch: _yearBranch(year)),
  ),
  year,
);
FlowMonthLimit _flowMonth(
  ZiweiChart chart,
  int year,
  int month,
  int sequence,
  bool leap,
  int stemOffset,
  int building,
  int effectiveYear,
  int effectiveMonth,
  int palaceIndex,
) {
  _checked(month, 1, 12, 'month');
  _checked(sequence, 1, 15, 'sequence');
  _checked(palaceIndex, 1, 15, 'palaceMonthIndex');
  final doujun =
          (_yearBranch(effectiveYear) -
              (chart.facts.effectiveLunarMonth - 1) +
              ganzhiBranch(chart.facts.solarTermPillars.hour)) %
          12,
      c = FlowCoordinate(
        stem: (_yearStem(effectiveYear) % 5 * 2 + 2 + stemOffset) % 10,
        branch: (doujun + palaceIndex - 1) % 12,
      );
  return FlowMonthLimit(
    _limit(chart, FlowLevel.month, c),
    year,
    month,
    sequence,
    effectiveMonth,
    effectiveYear,
    leap,
    building,
    palaceIndex,
    doujun,
  );
}

FlowMonthLimit makeFlowMonth(
  ZiweiChart chart,
  int year,
  int logicalMonth, {
  int? sequence,
  bool isLeap = false,
}) {
  final seq = sequence ?? logicalMonth;
  return _flowMonth(
    chart,
    year,
    logicalMonth,
    seq,
    isLeap,
    seq - 1,
    (seq + 1) % 12,
    year,
    logicalMonth,
    seq,
  );
}

FlowMonthLimit makeFlowMonthFromBuildingBranch(
  ZiweiChart chart,
  int lunarYear,
  int logicalMonth,
  int sequence,
  bool isLeap,
  int monthBuildingBranch, {
  int day = 1,
  int? effectiveMonthOverride,
  int? effectiveYearOverride,
  MonthName monthName = MonthName.normal,
  int? effectiveBaseYear,
}) {
  _checked(monthBuildingBranch, 0, 11, 'monthBuildingBranch');
  final advance =
      isLeap &&
      (chart.options.leapMonthStrategy == LeapMonthStrategy.asNext ||
          chart.options.leapMonthStrategy ==
                  LeapMonthStrategy.splitAfterFifteenth &&
              day > 15);
  final laterNine = monthName == MonthName.laterNine,
      m =
          effectiveMonthOverride ??
          (advance ? (laterNine ? 10 : logicalMonth % 12 + 1) : logicalMonth),
      y =
          effectiveYearOverride ??
          ((effectiveBaseYear ?? lunarYear) +
              (advance && (logicalMonth == 12 || laterNine) ? 1 : 0));
  _checked(m, 1, 12, 'effectiveMonth');
  return _flowMonth(
    chart,
    lunarYear,
    logicalMonth,
    sequence,
    isLeap,
    isLeap ? m - 1 : (monthBuildingBranch - 2) % 12,
    monthBuildingBranch,
    y,
    m,
    chart.options.flowMonthPalaceStrategy ==
            FlowMonthPalaceStrategy.effectiveMonth
        ? m
        : sequence,
  );
}

FlowDayLimit makeFlowDay(
  ZiweiChart chart,
  FlowMonthLimit month,
  int day,
  int physicalDayStem,
) {
  _checked(day, 1, 33, 'day');
  return FlowDayLimit(
    _limit(
      chart,
      FlowLevel.day,
      FlowCoordinate(
        stem: physicalDayStem,
        branch: (month.limit.coordinate.branch + day - 1) % 12,
      ),
    ),
    day,
  );
}

FlowHourLimit makeFlowHourFromPillar(
  ZiweiChart chart,
  FlowDayLimit day,
  int physicalHour,
  RatHourSegment segment,
) {
  final h = ganzhiBranch(physicalHour);
  if ((h == 0) == (segment == RatHourSegment.none)) {
    throw ArgumentError('rat hour segment mismatch');
  }
  return FlowHourLimit(
    _limit(
      chart,
      FlowLevel.hour,
      FlowCoordinate(
        stem: ganzhiStem(physicalHour),
        branch: (day.limit.coordinate.branch + h) % 12,
      ),
    ),
    h,
    segment,
  );
}

FlowHourLimit makeFlowHour(ZiweiChart chart, FlowDayLimit day, int hourIndex) {
  _checked(hourIndex, 0, 11, 'hourIndex');
  return FlowHourLimit(
    _limit(
      chart,
      FlowLevel.hour,
      FlowCoordinate(
        stem: (day.limit.coordinate.stem % 5 * 2 + hourIndex) % 10,
        branch: (day.limit.coordinate.branch + hourIndex) % 12,
      ),
    ),
    hourIndex,
    hourIndex == 0 ? RatHourSegment.unified : RatHourSegment.none,
  );
}
