part of '../ziwei_core.dart';

const _queryStars = {
  'lucunBranch': 'lucun',
  'hongluanBranch': 'hongluan',
  'zuofuBranch': 'zuofu',
  'youbiBranch': 'youbi',
  'wenchangBranch': 'wenchang',
  'wenquBranch': 'wenqu',
  'santaiBranch': 'santai',
  'bazuoBranch': 'bazuo',
  'ziweiBranch': 'ziwei',
};

class ZiweiTier1ReverseQuery {
  ZiweiTier1ReverseQuery({
    int? lucunBranch,
    int? hongluanBranch,
    int? zuofuBranch,
    int? youbiBranch,
    int? wenchangBranch,
    int? wenquBranch,
    int? santaiBranch,
    int? bazuoBranch,
    int? ziweiBranch,
  }) : values = Map.unmodifiable(
         {
           'lucunBranch': lucunBranch,
           'hongluanBranch': hongluanBranch,
           'zuofuBranch': zuofuBranch,
           'youbiBranch': youbiBranch,
           'wenchangBranch': wenchangBranch,
           'wenquBranch': wenquBranch,
           'santaiBranch': santaiBranch,
           'bazuoBranch': bazuoBranch,
           'ziweiBranch': ziweiBranch,
         }..removeWhere((k, v) => v == null),
       ) {
    if (values.isEmpty) {
      throw ArgumentError('at least one constraint is required');
    }
    for (final e in values.entries) {
      _checked(e.value!, 0, 11, e.key);
    }
  }
  final Map<String, int?> values;
  bool matches(ZiweiChart chart) => values.entries.every(
    (e) => chart.starPositions[requireStarId(_queryStars[e.key]!)] == e.value,
  );
}

class ZiweiReverseCandidate {
  const ZiweiReverseCandidate(
    this.jdUT1,
    this.chartTime,
    this.lunarDate,
    this.hourBranch,
    this.ratHourSegment,
    this.chart,
  );
  final double jdUT1;
  final CalendarDate chartTime;
  @Deprecated('Use chartTime.')
  CalendarDate get virtualTime => chartTime;
  final LunarCalendarDate lunarDate;
  final int hourBranch;
  final RatHourSegment ratHourSegment;
  final ZiweiChart chart;
}

ZiweiFlowTarget _targetFromVirtual(CalendarDate v, ZiweiOptions o) {
  final virtualJd = _jd(v);
  final jd = switch (o.clockMode) {
    ZiweiClockMode.civil => virtualJd - o.utcOffsetMinutes / 1440,
    ZiweiClockMode.meanSolar => virtualJd - o.longitudeDeg! / 360,
    ZiweiClockMode.trueSolar =>
      localApparentToMeanSolarTime(virtualJd, o.longitudeDeg!) -
          o.longitudeDeg! / 360,
  };
  return ZiweiFlowTarget(
    jd,
    resolveZiweiChartTime(
      JulianTime.fromUT1(jd).toZonedTime(o.utcOffsetMinutes.toInt()),
      o,
    ),
  );
}

List<ZiweiReverseCandidate> reverseLookupZiweiTier1({
  required ZonedTime start,
  required ZonedTime end,
  required ZiweiOptions options,
  required ZiweiTier1ReverseQuery query,
  int? maxCandidatesToExamine,
}) {
  final startJd = start.toJulianTime().jdUT1, endJd = end.toJulianTime().jdUT1;
  if (endJd < startJd) throw RangeError('end precedes start');
  if (maxCandidatesToExamine != null && maxCandidatesToExamine < 1) {
    throw RangeError('candidate ceiling must be positive');
  }
  final q = query.values;
  final direct =
      q['lucunBranch'] != null &&
      q['hongluanBranch'] != null &&
      (q['zuofuBranch'] != null || q['youbiBranch'] != null) &&
      (q['wenchangBranch'] != null || q['wenquBranch'] != null) &&
      (q['santaiBranch'] != null || q['bazuoBranch'] != null) &&
      options.rules.placementDefault == 'option1' &&
      options.rules.ruleset.modules.every(
        (m) => !_object(m.patch['natalPlacements'] ?? {}).keys.any(
          (k) => [
            'lucun',
            'hongluan',
            'zuofu',
            'youbi',
            'wenchang',
            'wenqu',
            'santai',
            'bazuo',
          ].contains(k),
        ),
      ) &&
      [
        'lucun',
        'hongluan',
        'zuofu',
        'youbi',
        'wenchang',
        'wenqu',
        'santai',
        'bazuo',
      ].every(
        (k) =>
            options.rules.placement[k] == null ||
            options.rules.placement[k] == 'option1',
      );
  final results = <ZiweiReverseCandidate>[], seen = <String>{};
  var examined = 0;
  String? previousState;
  void inspect(
    ZiweiFlowTarget target,
    int ceiling, {
    bool insideHourProbe = false,
  }) {
    if (examined++ >= ceiling) {
      throw RangeError('reverse lookup candidate ceiling exceeded');
    }
    if (target.jdUT1 < startJd - 1e-12 || target.jdUT1 > endJd + 1e-12) return;
    final chart = ZiweiChart.fromResolvedBirth(
      resolveZiweiBirthFromInstant(target.jdUT1, target.chartTime, options),
    );
    final placementAnchors = chart.anchors.toJson()
      ..remove('solarTerm')
      ..remove('lunar');
    final state = jsonEncode([
      placementAnchors,
      chart.bodyPalace,
      chart.lifeMaster,
      chart.bodyMaster,
      chart.palaceStems,
      chart.starPositions,
      chart.birthYearTransformations,
    ]);
    final duplicate = insideHourProbe && state == previousState;
    previousState = state;
    if (duplicate || !query.matches(chart)) return;
    final h = ganzhiBranch(chart.facts.solarTermPillars.hour),
        key = '${target.jdUT1.toStringAsFixed(10)}:$h';
    if (!seen.add(key)) return;
    results.add(
      ZiweiReverseCandidate(
        target.jdUT1,
        target.chartTime,
        chart.facts.lunarDate,
        h,
        _segment(target.chartTime, options.ratHourMode, h),
        chart,
      ),
    );
  }

  if (direct) {
    final stems = [
          for (var i = 0; i < 10; i++)
            if ([2, 3, 5, 6, 5, 6, 8, 9, 11, 0][i] == q['lucunBranch']) i,
        ],
        branch = (3 - q['hongluanBranch']!) % 12;
    List<int> intersection(List<int?> list) {
      final values = list.whereType<int>().toList();
      return values.isEmpty || !values.every((v) => v == values.first)
          ? []
          : [values.first];
    }

    final months = intersection([
          q['zuofuBranch'] == null ? null : (q['zuofuBranch']! - 4) % 12 + 1,
          q['youbiBranch'] == null ? null : (10 - q['youbiBranch']!) % 12 + 1,
        ]),
        hours = intersection([
          q['wenchangBranch'] == null ? null : (10 - q['wenchangBranch']!) % 12,
          q['wenquBranch'] == null ? null : (q['wenquBranch']! - 4) % 12,
        ]);
    if (months.isEmpty || hours.isEmpty || stems.isEmpty) return const [];
    for (var y = start.year - 2; y <= end.year + 2; y++) {
      if (!stems.contains(_yearStem(y)) || _yearBranch(y) != branch) continue;
      final pool = <int, LunarMonth>{};
      for (final py in [y - 1, y, y + 1]) {
        for (final probe in [
          CalendarDate(year: py, month: 7, day: 1, hour: 12),
          CalendarDate(year: py + 1, month: 1, day: 15, hour: 12),
        ]) {
          for (final m in calculateChineseCalendarYear(
            _jd(probe),
            options: options.calendarOptions,
          ).months) {
            pool[m.firstCivilDayNumber] = m;
          }
        }
      }
      final ordered = pool.values.toList()
        ..sort(
          (a, b) => a.firstCivilDayNumber.compareTo(b.firstCivilDayNumber),
        );
      for (final m in ordered) {
        for (var day = 1; day <= m.dayCount; day++) {
          var ey = m.historicalYear, em = m.month == 13 ? 12 : m.month;
          final advance =
              m.isLeap &&
              (options.leapMonthStrategy == LeapMonthStrategy.asNext ||
                  options.leapMonthStrategy ==
                          LeapMonthStrategy.splitAfterFifteenth &&
                      day > 15);
          if (advance) {
            if (m.monthName == MonthName.laterNine) ey++;
            em++;
            if (em > 12) {
              em = 1;
              ey++;
            }
          }
          if (ey != y ||
              !months.contains(em) ||
              q['santaiBranch'] != null &&
                  (4 + em - 1 + day - 1) % 12 != q['santaiBranch'] ||
              q['bazuoBranch'] != null &&
                  (10 - (em - 1) - (day - 1)) % 12 != q['bazuoBranch']) {
            continue;
          }
          final solar = lunarToSolar(
            LunarDate(
              year: m.lunarYear,
              month: m.month,
              day: day,
              isLeap: m.isLeap,
              monthName: m.monthName,
            ),
            options: options.calendarOptions,
          );
          for (final h in hours) {
            for (final hour
                in h == 0 && options.ratHourMode != RatHourMode.nextDay
                    ? [0, 23]
                    : [h * 2]) {
              var target = _targetFromVirtual(
                CalendarDate(
                  year: solar.year,
                  month: solar.month,
                  day: solar.day,
                  hour: hour,
                ),
                options,
              );
              final split = options.ratHourMode != RatHourMode.nextDay;
              final lo = hour == 0
                  ? (split ? 0 : -1)
                  : hour == 23
                  ? 23
                  : hour - 1;
              final hi = hour == 0
                  ? 1
                  : hour == 23
                  ? 24
                  : hour + 1;
              CalendarDate boundary(int h) {
                final date = calendarDateFromJulianDay(
                  julianDay(
                        year: solar.year,
                        month: solar.month,
                        day: solar.day,
                        hour: 12,
                      ) +
                      (h / 24).floor(),
                );
                return CalendarDate(
                  year: date.year,
                  month: date.month,
                  day: date.day,
                  hour: h % 24,
                );
              }

              if (chartTimeToUt1(boundary(lo), options) > endJd ||
                  chartTimeToUt1(boundary(hi), options) <= startJd) {
                continue;
              }
              // A representative outside the interval may still describe an
              // overlapping segment. Clamp, then verify with the forward engine.
              if (target.jdUT1 < startJd || target.jdUT1 > endJd) {
                final jd = target.jdUT1.clamp(startJd, endJd);
                target = ZiweiFlowTarget(
                  jd,
                  resolveZiweiChartTime(
                    JulianTime.fromUT1(
                      jd,
                    ).toZonedTime(options.utcOffsetMinutes.toInt()),
                    options,
                  ),
                );
              }
              inspect(target, maxCandidatesToExamine ?? 9007199254740991);
            }
          }
        }
      }
    }
  } else {
    var target = ZiweiFlowTarget(
      startJd,
      resolveZiweiChartTime(start, options),
    );
    final ceiling =
        maxCandidatesToExamine ??
        ((endJd - startJd) * 13).ceil() + ((endJd - startJd) / 10).ceil() + 3;
    var nextJie = _nextPillarJieBoundary(startJd, options);
    var insideHourProbe = false;
    while (target.jdUT1 <= endJd + 1e-12) {
      inspect(target, ceiling, insideHourProbe: insideHourProbe);
      // Search every segment boundary; interactive stepping intentionally
      // preserves the minute offset and is not suitable for interval scans.
      final v = target.chartTime;
      final nextHour =
          options.ratHourMode != RatHourMode.nextDay && v.hour == 23
          ? 24
          : ((v.hour + 1) ~/ 2) * 2 + 1;
      final date = calendarDateFromJulianDay(
        julianDay(year: v.year, month: v.month, day: v.day, hour: 12) +
            nextHour ~/ 24,
      );
      final boundary = CalendarDate(
        year: date.year,
        month: date.month,
        day: date.day,
        hour: nextHour % 24,
      );
      final physical = _targetFromVirtual(boundary, options);
      var next = ZiweiFlowTarget(physical.jdUT1, boundary);
      // Solar rule inputs can change inside a Chinese-hour segment.
      insideHourProbe = nextJie < next.jdUT1;
      if (nextJie <= next.jdUT1) {
        next = ZiweiFlowTarget(
          nextJie,
          resolveZiweiChartTime(
            JulianTime.fromUT1(
              nextJie,
            ).toZonedTime(options.utcOffsetMinutes.toInt()),
            options,
          ),
        );
        nextJie = _nextPillarJieBoundary(nextJie, options);
      }
      if (next.jdUT1 <= target.jdUT1) {
        throw StateError('stepping did not advance');
      }
      target = next;
    }
  }
  results.sort((a, b) => a.jdUT1.compareTo(b.jdUT1));
  return List.unmodifiable(results);
}
