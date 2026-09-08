part of '../ziwei_core.dart';

class ChildhoodNode {
  const ChildhoodNode({
    required this.age,
    required this.year,
    required this.stem,
    required this.branch,
  });
  final int age;
  final int year;
  final int stem;
  final int branch;
  Map<String, Object> toJson() => {
    'age': age,
    'year': year,
    'stem': stem,
    'branch': branch,
  };
}

class DecadeNode {
  const DecadeNode({
    required this.index,
    required this.startAge,
    required this.endAge,
    required this.startYear,
    required this.endYear,
    required this.stem,
    required this.branch,
  });
  final int index;
  final int startAge;
  final int endAge;
  final int startYear;
  final int endYear;
  final int stem;
  final int branch;
  Map<String, Object> toJson() => {
    'index': index,
    'startAge': startAge,
    'endAge': endAge,
    'startYear': startYear,
    'endYear': endYear,
    'stem': stem,
    'branch': branch,
  };
}

class YearNode {
  const YearNode({
    required this.year,
    required this.stem,
    required this.branch,
  });
  final int year;
  final int stem;
  final int branch;
  Map<String, Object> toJson() => {
    'year': year,
    'stem': stem,
    'branch': branch,
  };
}

class MonthNode {
  const MonthNode({
    required this.lunarYear,
    required this.month,
    required this.sequence,
    required this.effectiveMonth,
    required this.effectiveYear,
    required this.dayStart,
    required this.dayEnd,
    required this.monthBuildingBranch,
    required this.stem,
    required this.branch,
    required this.displayBranch,
    required this.firstCivilDayNumber,
    required this.dayCount,
    required this.monthName,
    required this.displayLabel,
    required this.isLeap,
    required this.solarStartJd,
    required this.solarEndJdExclusive,
  });
  final int lunarYear;
  final int month;
  final int sequence;
  final int effectiveMonth;
  final int effectiveYear;
  final int dayStart;
  final int dayEnd;
  final int monthBuildingBranch;
  final int stem;
  final int branch;
  final int displayBranch;
  final int firstCivilDayNumber;
  final int dayCount;
  final MonthName monthName;
  final String displayLabel;
  final bool isLeap;
  final double solarStartJd;
  final double solarEndJdExclusive;
  Map<String, Object> toJson() => {
    'lunarYear': lunarYear,
    'month': month,
    'sequence': sequence,
    'effectiveMonth': effectiveMonth,
    'effectiveYear': effectiveYear,
    'dayStart': dayStart,
    'dayEnd': dayEnd,
    'monthBuildingBranch': monthBuildingBranch,
    'stem': stem,
    'branch': branch,
    'displayBranch': displayBranch,
    'firstCivilDayNumber': firstCivilDayNumber,
    'dayCount': dayCount,
    'monthName': monthName.index,
    'displayLabel': displayLabel,
    'isLeap': isLeap,
    'solarStartJd': solarStartJd,
    'solarEndJdExclusive': solarEndJdExclusive,
  };
}

class DayNode {
  const DayNode({
    required this.day,
    required this.stem,
    required this.branch,
    required this.solarDate,
  });
  final int day;
  final int stem;
  final int branch;
  final CalendarDate solarDate;
  Map<String, Object> toJson() => {
    'day': day,
    'stem': stem,
    'branch': branch,
    'solarDate': {
      'year': solarDate.year,
      'month': solarDate.month,
      'day': solarDate.day,
    },
  };
}

class HourNode {
  const HourNode({
    required this.hourIndex,
    required this.branchIndex,
    required this.stem,
    required this.branch,
    required this.label,
    required this.isEarlyRat,
    required this.isLateRat,
  });
  final int hourIndex;
  final int branchIndex;
  final int stem;
  final int branch;
  final String label;
  final bool isEarlyRat;
  final bool isLateRat;
  Map<String, Object> toJson() => {
    'hourIndex': hourIndex,
    'branchIndex': branchIndex,
    'stem': stem,
    'branch': branch,
    'label': label,
    'isEarlyRat': isEarlyRat,
    'isLateRat': isLateRat,
  };
}

class TimelineManifest {
  TimelineManifest({
    required this.childhoods,
    required this.decades,
    this.currentDecadeYears,
    this.currentYearMonths,
    this.currentMonthDays,
    this.currentDayHours,
  });
  final List<ChildhoodNode> childhoods;
  final List<DecadeNode> decades;
  final List<YearNode>? currentDecadeYears;
  final List<MonthNode>? currentYearMonths;
  final List<DayNode>? currentMonthDays;
  final List<HourNode>? currentDayHours;
  Map<String, Object> toJson() => {
    'childhoods': childhoods.map((v) => v.toJson()).toList(),
    'decades': decades.map((v) => v.toJson()).toList(),
    if (currentDecadeYears != null)
      'currentDecadeYears': currentDecadeYears!.map((v) => v.toJson()).toList(),
    if (currentYearMonths != null)
      'currentYearMonths': currentYearMonths!.map((v) => v.toJson()).toList(),
    if (currentMonthDays != null)
      'currentMonthDays': currentMonthDays!.map((v) => v.toJson()).toList(),
    if (currentDayHours != null)
      'currentDayHours': currentDayHours!.map((v) => v.toJson()).toList(),
  };
}

const _monthLabels = [
  '正',
  '二',
  '三',
  '四',
  '五',
  '六',
  '七',
  '八',
  '九',
  '十',
  '冬',
  '腊',
];
String _monthLabel(int m, MonthName name, bool leap) => switch (name) {
  MonthName.thirteen => '十三月',
  MonthName.laterNine => '后九月',
  MonthName.altTwelve => '拾贰月',
  MonthName.altOne => '一月',
  MonthName.laterSameName =>
    '${['正', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'][m - 1]}月',
  _ => '${leap ? '闰' : ''}${m <= 12 ? _monthLabels[m - 1] : m}月',
};
List<({int year, int month, int start, int end})> _monthSegments(
  ZiweiChart chart,
  LunarMonth m,
) {
  final logical = m.month == 13 ? 12 : m.month,
      y = m.historicalYear,
      n = m.dayCount;
  if (!m.isLeap) return [(year: y, month: logical, start: 1, end: n)];
  final later = m.monthName == MonthName.laterNine,
      next = later ? 10 : logical % 12 + 1,
      ny = y + (logical == 12 || later ? 1 : 0);
  if (chart.options.leapMonthStrategy == LeapMonthStrategy.asNext) {
    return [(year: ny, month: next, start: 1, end: n)];
  }
  if (chart.options.leapMonthStrategy ==
          LeapMonthStrategy.splitAfterFifteenth &&
      n > 15) {
    return [
      (year: y, month: logical, start: 1, end: 15),
      (year: ny, month: next, start: 16, end: n),
    ];
  }
  return [(year: y, month: logical, start: 1, end: n)];
}

List<LunarMonth> _collectLunarYearMonths(ZiweiChart chart, int year) {
  final byDay = <int, LunarMonth>{};
  for (final y in [year - 1, year, year + 1]) {
    for (final m in calculateChineseCalendarYear(
      julianDay(year: y, month: 6, day: 1, hour: 12),
      options: chart.options.calendarOptions,
    ).months) {
      if (m.lunarYear == year) byDay[m.firstCivilDayNumber] = m;
    }
  }
  return byDay.values.toList()
    ..sort((a, b) => a.firstCivilDayNumber.compareTo(b.firstCivilDayNumber));
}

class ZiweiTimelineProvider {
  const ZiweiTimelineProvider(this.chart);
  final ZiweiChart chart;
  List<DecadeNode> getDecades({int count = 12}) {
    if (count < 0) throw RangeError('negative count');
    return List.unmodifiable(
      List.generate(count, (i) {
        final d = makeDecadeByIndex(chart, getEffectiveBirthYear(chart), i + 1),
            c = d.limit.coordinate;
        return DecadeNode(
          index: d.index,
          startAge: d.startAge,
          endAge: d.endAge,
          startYear: d.startYear,
          endYear: d.endYear,
          stem: c.stem,
          branch: c.branch,
        );
      }),
    );
  }

  List<ChildhoodNode> getChildhood() {
    final y = getEffectiveBirthYear(chart),
        count = getStartDecadeYear(chart) - y;
    return List.unmodifiable(
      List.generate(count, (i) {
        final c = makeChildhoodDecade(chart, y, y + i).limit.coordinate;
        return ChildhoodNode(
          age: i + 1,
          year: y + i,
          stem: c.stem,
          branch: c.branch,
        );
      }),
    );
  }

  List<YearNode> getYears(int decadeIndex) {
    if (decadeIndex < 1) throw RangeError('decade index must be positive');
    final start = getStartDecadeYear(chart) + (decadeIndex - 1) * 10;
    return List.unmodifiable(
      List.generate(
        10,
        (i) => YearNode(
          year: start + i,
          stem: _yearStem(start + i),
          branch: _yearBranch(start + i),
        ),
      ),
    );
  }

  List<MonthNode> getMonths(int targetYear) {
    if (chart.options.flowLimitBoundary == PillarBoundary.solarTerm) {
      return _solarMonths(targetYear);
    }
    final byDay = <int, LunarMonth>{};
    for (final y in [targetYear - 2, targetYear - 1, targetYear]) {
      try {
        for (final m in _collectLunarYearMonths(chart, y)) {
          byDay.putIfAbsent(m.firstCivilDayNumber, () => m);
        }
      } catch (e) {
        if (y == targetYear) rethrow;
      }
    }
    final raw = byDay.values.toList()
          ..sort(
            (a, b) => a.firstCivilDayNumber.compareTo(b.firstCivilDayNumber),
          ),
        counts = <int, int>{},
        result = <MonthNode>[];
    for (final m in raw) {
      final sequence = (counts[m.historicalYear] ?? 0) + 1;
      counts[m.historicalYear] = sequence;
      final logical = m.month == 13 ? 12 : m.month;
      for (final seg in _monthSegments(chart, m)) {
        if (seg.year != targetYear) continue;
        final flow = makeFlowMonthFromBuildingBranch(
              chart,
              m.lunarYear,
              logical,
              sequence,
              m.isLeap,
              m.monthBuildingBranch,
              day: seg.start,
              effectiveMonthOverride: seg.month,
              effectiveYearOverride: seg.year,
              monthName: m.monthName,
            ),
            first = m.firstCivilDayNumber + seg.start - 1,
            n = seg.end - seg.start + 1,
            c = flow.limit.coordinate;
        result.add(
          MonthNode(
            lunarYear: m.lunarYear,
            month: logical,
            sequence: sequence,
            effectiveMonth: flow.effectiveMonth,
            effectiveYear: flow.effectiveYear,
            dayStart: seg.start,
            dayEnd: seg.end,
            monthName: m.monthName,
            displayLabel: _monthLabel(m.month, m.monthName, m.isLeap),
            isLeap: m.isLeap,
            monthBuildingBranch: m.monthBuildingBranch,
            stem: c.stem,
            branch: c.branch,
            displayBranch: (flow.effectiveMonth + 1) % 12,
            solarStartJd: first - 0.5,
            solarEndJdExclusive: first + n - 0.5,
            firstCivilDayNumber: first,
            dayCount: n,
          ),
        );
      }
    }
    return List.unmodifiable(
      result..sort(
        (a, b) => a.firstCivilDayNumber.compareTo(b.firstCivilDayNumber),
      ),
    );
  }

  List<MonthNode> _solarMonths(int year) {
    var cursor = julianDay(year: year - 1, month: 11, day: 1, hour: 12);
    double? lichun;
    for (var i = 0; i < 40; i++) {
      final next = getNextJie(cursor, options: chart.options.calendarOptions);
      if (next.indexFromWinterSolstice == 3) {
        lichun = next.time.jdUT1;
        break;
      }
      cursor = next.time.jdUT1 + 2;
    }
    if (lichun == null) throw StateError('Li Chun not found');
    final starts = [lichun];
    for (var i = 0; i < 12; i++) {
      starts.add(
        getNextJie(
          starts.last + 2,
          options: chart.options.calendarOptions,
        ).time.jdUT1,
      );
    }
    double logicalJd(double jd) {
      final v = resolveZiweiVirtualTime(
        JulianTime.fromUT1(
          jd,
        ).toZonedTime(chart.options.utcOffsetMinutes.toInt()),
        chart.options,
      );
      return _jd(v) +
          (chart.options.ratHourMode == RatHourMode.nextDay ? 1 / 24 : 0);
    }

    return List.unmodifiable(
      List.generate(12, (i) {
        final m = i + 1,
            flow = makeFlowMonth(chart, year, m),
            start = (logicalJd(starts[i]) + 0.5).floor(),
            // A partial final civil date belongs to this month too.
            end = (logicalJd(starts[i + 1]) + 0.5)
                .ceil(),
            c = flow.limit.coordinate;
        return MonthNode(
          lunarYear: year,
          month: m,
          sequence: m,
          effectiveMonth: flow.effectiveMonth,
          effectiveYear: flow.effectiveYear,
          dayStart: 1,
          dayEnd: end - start,
          monthName: MonthName.normal,
          displayLabel: '${_monthLabels[i]}月',
          isLeap: false,
          monthBuildingBranch: (m + 1) % 12,
          stem: c.stem,
          branch: c.branch,
          displayBranch: (flow.effectiveMonth + 1) % 12,
          solarStartJd: starts[i],
          solarEndJdExclusive: starts[i + 1],
          firstCivilDayNumber: start,
          dayCount: end - start,
        );
      }),
    );
  }

  List<DayNode> getDays(
    int year,
    int month, {
    bool isLeap = false,
    int? effectiveMonth,
    int? effectiveYear,
  }) {
    final node = getMonths(year)
        .where(
          (v) =>
              v.month == month &&
              v.isLeap == isLeap &&
              (effectiveMonth == null || v.effectiveMonth == effectiveMonth) &&
              (effectiveYear == null || v.effectiveYear == effectiveYear),
        )
        .firstOrNull;
    if (node == null) return const [];
    return List.unmodifiable(
      List.generate(node.dayCount, (i) {
        final v = calendarDateFromJulianDay(node.firstCivilDayNumber - 0.5 + i),
            date = CalendarDate(year: v.year, month: v.month, day: v.day),
            p = calculateDayPillar(date);
        return DayNode(
          day: node.dayStart + i,
          stem: ganzhiStem(p),
          branch: ganzhiBranch(p),
          solarDate: date,
        );
      }),
    );
  }

  List<HourNode> getHours(int dayPillar) {
    final split = chart.options.ratHourMode != RatHourMode.nextDay,
        result = <HourNode>[],
        stem = ganzhiStem(dayPillar);
    HourNode node(
      int index,
      int branch,
      int s, {
      bool early = false,
      bool late = false,
    }) => HourNode(
      hourIndex: index,
      branchIndex: branch,
      label: early
          ? '早子'
          : late
          ? '晚子'
          : earthlyBranches[branch],
      stem: ganzhiStem(getHourGanzhi(s, branch)),
      branch: branch,
      isEarlyRat: early,
      isLateRat: late,
    );
    if (split) result.add(node(0, 0, stem, early: true));
    for (var b = split ? 1 : 0; b < 12; b++) {
      result.add(node(b, b, stem));
    }
    if (split) {
      result.add(
        node(
          12,
          0,
          chart.options.ratHourMode == RatHourMode.currentDayTomorrowStem
              ? (stem + 1) % 10
              : stem,
          late: true,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  TimelineManifest getManifest({
    int? year,
    int? decadeIndex,
    int? month,
    bool isLeap = false,
    int? effectiveMonth,
    int? effectiveYear,
    int? day,
  }) {
    final index =
        decadeIndex ??
        (year == null
            ? null
            : makeDecadeForYear(
                chart,
                getEffectiveBirthYear(chart),
                year,
              ).index);
    final years = index == null
        ? null
        : index == 0
        ? (year == null
              ? getChildhood()
                    .map(
                      (v) => YearNode(
                        year: v.year,
                        stem: v.stem,
                        branch: v.branch,
                      ),
                    )
                    .toList()
              : [
                  YearNode(
                    year: year,
                    stem: _yearStem(year),
                    branch: _yearBranch(year),
                  ),
                ])
        : getYears(index);
    final months = year == null ? null : getMonths(year),
        days = year == null || month == null
            ? null
            : getDays(
                year,
                month,
                isLeap: isLeap,
                effectiveMonth: effectiveMonth,
                effectiveYear: effectiveYear,
              ),
        target = days?.where((v) => v.day == day).firstOrNull;
    return TimelineManifest(
      childhoods: getChildhood(),
      decades: getDecades(),
      currentDecadeYears: years,
      currentYearMonths: months,
      currentMonthDays: days,
      currentDayHours: target == null
          ? null
          : getHours(calculateDayPillar(target.solarDate)),
    );
  }
}
