import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';
import 'package:ephemeris_lite/ephemeris_lite.dart' as eph;

ZonedTime time(int y, [int m = 1, int d = 1, int h = 12, int minute = 0]) =>
    ZonedTime(
      year: y,
      month: m,
      day: d,
      hour: h,
      minute: minute,
      offsetMinutes: 480,
    );
void main() {
  final defaultOptions = ZiweiOptions(gender: ZiweiGender.male);
  ZiweiChart natal([ZiweiOptions? o]) =>
      ZiweiChart.fromZonedTime(time(2000), o ?? defaultOptions);

  test('review: previous Jie uses its own apparent-solar offset', () {
    final o = defaultOptions.copyWith(
      clockMode: ZiweiClockMode.trueSolar,
      longitudeDeg: 153.07804249718785,
      ratHourMode: RatHourMode.currentDay,
    );
    final target = time(2026, 3, 20, 20),
        jd = target.toJulianTime().jdUT1,
        v = resolveZiweiVirtualTime(target, o);
    final jie = eph.getPreviousJie(jd, options: o.calendarOptions).time;
    final jv = resolveZiweiVirtualTime(jie.toZonedTime(480), o);
    double vjd(eph.CalendarDate v) => eph.julianDay(
      year: v.year,
      month: v.month,
      day: v.day,
      hour: v.hour,
      minute: v.minute,
      second: v.second,
    );
    final expected = (vjd(v) + 0.5).floor() - (vjd(jv) + 0.5).floor() + 1;
    expect(expected, 16);
    expect(solarDayFromPreviousJie(jd, v, o), expected);
    expect(
      ZiweiChart.fromZonedTime(target, o).facts.solarDayFromPreviousJie,
      expected,
    );
    expect(
      resolveZiweiFlow(
        natal(o),
        target,
        boundary: PillarBoundary.solarTerm,
      ).targetDay,
      expected,
    );
  });
  test(
    'review: historical later-nine birth agrees with flow effective year',
    () {
      for (final strategy in [
        LeapMonthStrategy.asNext,
        LeapMonthStrategy.splitAfterFifteenth,
      ]) {
        final o = defaultOptions.copyWith(leapMonthStrategy: strategy);
        final target = time(-217, 11, 1),
            birth = ZiweiChart.fromZonedTime(target, o);
        expect(birth.facts.lunarDate.monthName, MonthName.laterNine);
        expect(birth.facts.effectiveLunarYear, -216);
        final earlier = ZiweiChart.fromZonedTime(time(-230), o);
        expect(
          resolveZiweiFlow(earlier, target).effectiveTargetYear,
          birth.facts.effectiveLunarYear,
        );
      }
    },
  );
  test('review: direct reverse includes a partial matching segment', () {
    final c = ZiweiChart.fromZonedTime(time(2026, 3, 1, 2), defaultOptions);
    int b(String k) => c.starPositions[requireStarId(k)];
    final q = ZiweiTier1ReverseQuery(
      lucunBranch: b('lucun'),
      hongluanBranch: b('hongluan'),
      zuofuBranch: b('zuofu'),
      wenchangBranch: b('wenchang'),
      santaiBranch: b('santai'),
    );
    for (final r in [
      [1, 10, 30],
      [2, 30, 45],
    ]) {
      expect(
        reverseLookupZiweiTier1(
          start: time(2026, 3, 1, r[0], r[1]),
          end: time(2026, 3, 1, r[0], r[2]),
          options: defaultOptions,
          query: q,
        ),
        hasLength(1),
      );
    }
  });
  test('review: later-nine advance changes effective year', () {
    for (final strategy in [
      LeapMonthStrategy.asNext,
      LeapMonthStrategy.splitAfterFifteenth,
    ]) {
      expect(
        resolveEffectiveLunarMonth(
          eph.LunarDate(
            year: -200,
            month: 9,
            day: 16,
            isLeap: true,
            monthName: MonthName.laterNine,
          ),
          strategy,
        ),
        (year: -199, month: 10),
      );
    }
  });
  test(
    'review: physical steps retain true-solar conversion and rat metadata',
    () {
      final o = defaultOptions.copyWith(
        clockMode: ZiweiClockMode.trueSolar,
        longitudeDeg: 116.4,
        ratHourMode: RatHourMode.currentDay,
      );
      final m = natal(o).createLimitManager();
      m.setPhysicalTime(time(2026, 3, 1, 23, 40));
      expect(
        m.currentTarget!.ratHourSegment,
        m.resolvedFlow!.targetRatHourSegment,
      );
      for (final action in [
        m.nextDay,
        m.nextHour,
        m.previousHour,
        m.previousDay,
      ]) {
        action();
        final t = m.currentTarget!,
            actual = resolveZiweiVirtualTime(
              eph.JulianTime.fromUT1(t.jdUT1).toZonedTime(480),
              o,
            );
        double jd(eph.CalendarDate v) => eph.julianDay(
          year: v.year,
          month: v.month,
          day: v.day,
          hour: v.hour,
          minute: v.minute,
          second: v.second,
        );
        expect((jd(actual) - jd(t.virtualTime)).abs() * 86400, lessThan(0.001));
        expect(t.ratHourSegment, m.resolvedFlow!.targetRatHourSegment);
      }
    },
  );
  test('review: selecting a month from another year synchronizes timeline', () {
    final c = natal(), m = c.createLimitManager();
    m.setYear(2023);
    m.selectMonth(c.timeline().getMonths(2024).first);
    expect(m.timelineYear, 2024);
    expect(m.manifest.currentMonthDays!, isNotEmpty);
    expect(m.manifest.currentMonthDays!.first.solarDate.year, 2024);
  });
  test('review: flow JSON rejects unavailable month input', () {
    expect(
      () => ZiweiConfigLoader.compileJson(
        label: 'invalid-flow',
        flowJson:
            '[{"key":"flow_lucun","rule":{"type":"anchor_offset","anchor":"month","offset":0}}]',
      ),
      throwsArgumentError,
    );
  });
  test('reverse fallback includes partially overlapping hour segments', () {
    for (final mode in RatHourMode.values) {
      final options = defaultOptions.copyWith(ratHourMode: mode);
      final expected = ZiweiChart.fromZonedTime(time(2026, 3, 1, 1), options);
      final rows = reverseLookupZiweiTier1(
        start: time(2026, 3, 1, 0, 30),
        end: time(2026, 3, 1, 1, 30),
        options: options,
        query: ZiweiTier1ReverseQuery(
          wenchangBranch: expected.starPositions[requireStarId('wenchang')],
        ),
      );
      expect(rows, hasLength(1), reason: mode.name);
      expect(rows.single.virtualTime.hour, 1);
      expect(rows.single.virtualTime.minute, 0);
      final midnight = reverseLookupZiweiTier1(
        start: time(2026, 3, 1, 23, 30),
        end: time(2026, 3, 2, 0, 30),
        options: options,
        query: ZiweiTier1ReverseQuery(
          lucunBranch: expected.starPositions[requireStarId('lucun')],
        ),
      );
      expect(
        midnight.map((r) => r.virtualTime.hour).toList(),
        mode == RatHourMode.nextDay ? [23] : [23, 0],
      );
      final endpoint = reverseLookupZiweiTier1(
        start: time(2026, 3, 1, 0, 30),
        end: time(2026, 3, 1, 1),
        options: options,
        query: ZiweiTier1ReverseQuery(
          wenchangBranch: expected.starPositions[requireStarId('wenchang')],
        ),
      );
      expect(endpoint, hasLength(1));
    }
  });
  test('solar month timeline contains both sides of a Jie civil date', () {
    final chart = natal(
      defaultOptions.copyWith(flowLimitBoundary: PillarBoundary.solarTerm),
    );
    final timeline = chart.timeline();
    for (final month in timeline.getMonths(2026)) {
      for (final delta in [-1 / 86400, 1 / 86400]) {
        final instant = eph.JulianTime.fromUT1(
          month.solarEndJdExclusive + delta,
        ).toZonedTime(480);
        final flow = resolveZiweiFlow(chart, instant);
        final logical = eph.calendarDateFromJulianDay(
          instant.toJulianTime().jdUT1 + 480 / 1440 + 1 / 24,
        );
        final days = timeline.getDays(
          flow.effectiveTargetYear,
          flow.targetMonth,
        );
        expect(
          days.any(
            (d) =>
                d.day == flow.targetDay &&
                d.solarDate.year == logical.year &&
                d.solarDate.month == logical.month &&
                d.solarDate.day == logical.day,
          ),
          isTrue,
          reason: 'month ${month.month}, delta $delta',
        );
      }
    }
  });
  test('lunar entry matches solar and preserves original lunar input', () {
    final solar = natal(), lunar = eph.solarToLunar(time(2000));
    final c = ZiweiChart.fromLunar(lunar, defaultOptions, hour: 12);
    expect(c.starPositions, solar.starPositions);
    expect(c.anchors.toJson(), solar.anchors.toJson());
    expect(c.lunarInput!['month'], lunar.month);
  });
  test(
    'options and nested rule selections copy without mutating prior values',
    () {
      final original = ZiweiOptions(
        gender: ZiweiGender.female,
        rules: ZiweiRuleSelection(
          placement: {'ziwei': 'option1'},
          brightness: {'taiyang': 'option1'},
        ),
      );
      final changed = original.copyWith(
        rules: original.rules.copyWith(longevity: 'option2'),
      );
      expect(changed.rules.placement, original.rules.placement);
      expect(original.rules.longevity, 'option1');
      expect(changed.rules.longevity, 'option2');
      expect(
        () => changed.rules.placement['ziwei'] = 'option2',
        throwsUnsupportedError,
      );
      expect(
        () => natal(
          defaultOptions.copyWith(
            rules: ZiweiRuleSelection(brightnessDefault: 'option2'),
          ),
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'partial builtin module does not overwrite an earlier unrelated patch',
    () {
      final first = ZiweiConfigLoader.overrideWith(
        ZiweiRuleset(),
        label: 'custom',
        starsJson:
            '[{"key":"ziwei","type":"major","rule":{"type":"constant","value":5}}]',
      );
      final next = ZiweiConfigLoader.withOptions(
        first,
        label: 'cycle',
        longevity: 'option2',
      );
      final c = natal(
        defaultOptions.copyWith(rules: ZiweiRuleSelection(ruleset: next)),
      );
      expect(c.starPositions[requireStarId('ziwei')], 5);
      expect(() => next.withModule(next.modules.first), throwsArgumentError);
      expect(
        () => ZiweiConfigLoader.withOptions(
          first,
          label: 'bad',
          placement: {'missing': 'option1'},
        ),
        throwsArgumentError,
      );
    },
  );
  test('compiled JSON lookup offsets, pipelines, domains and limits', () {
    final anchor = compileZiweiJsonPlacement({
      'type': 'anchor_offset',
      'anchor': 'month',
      'offset': 4,
      'direction': -1,
    });
    expect(anchor.evaluate((s) => 2), 2);
    final lookup = compileZiweiJsonPlacement({
      'type': 'lookup_offset',
      'anchor': 'year_stem',
      'table': {
        for (final k in [
          'jia',
          'yi',
          'bing',
          'ding',
          'wu',
          'ji',
          'geng',
          'xin',
          'ren',
          'gui',
        ])
          k: 5,
      },
      'shift_anchor': 'hour',
      'direction': 'ni',
      'offset': 1,
    });
    expect(lookup.evaluate((s) => s.endsWith('hour_branch') ? 3 : 0), 3);
    expect(
      () => compileZiweiJsonPlacement({
        'type': 'lookup',
        'anchor': 'year_stem',
        'table': {},
      }),
      throwsArgumentError,
    );
    expect(
      () => compileZiweiJsonPlacement({'type': 'constant', 'value': 1.2}),
      throwsArgumentError,
    );
    expect(
      () => ZiweiCompiledPlacement(inputs: ['x'], shape: [12], positions: [1]),
      throwsArgumentError,
    );
    expect(() => ZiweiRuleModule(label: ' ', patch: {}), throwsArgumentError);
    expect(
      () => ZiweiRuleModule(
        label: 'bad',
        patch: {
          'brightness': {
            'ziwei': [1, 2],
          },
        },
      ),
      throwsArgumentError,
    );
    Object deep = {'type': 'constant', 'value': 0};
    for (var i = 0; i < 130; i++) {
      deep = {
        'type': 'pipeline',
        'steps': [deep],
      };
    }
    expect(() => compileZiweiJsonPlacement(deep), throwsArgumentError);
  });
  test('custom star ids must be symbolic in dependent references', () {
    final p = {
      'stars': [
        {'key': 'newstar', 'natal': true},
      ],
      'natalPlacements': {
        'newstar': {
          'inputs': [],
          'shape': [],
          'positions': [2],
        },
      },
      'sihua': {
        'jia': {'lu': 159},
      },
    };
    final rules = ZiweiRuleSelection(
      ruleset: ZiweiRuleset([ZiweiRuleModule(label: 'bad', patch: p)]),
    );
    expect(() => selectZiweiRules(rules), throwsArgumentError);
    final source = <String, dynamic>{
      'natalPlacements': {
        'ziwei': {
          'inputs': [],
          'shape': [],
          'positions': [2],
        },
      },
    };
    final module = ZiweiRuleModule(label: 'immutable', patch: source);
    (source['natalPlacements']['ziwei']['positions'] as List)[0] = 7;
    expect(module.patch['natalPlacements']['ziwei']['positions'], [2]);
  });
  test('cast random rejection sampling, index replay and malformed source', () {
    var calls = 0;
    final c = ZiweiCastingChart.random(
      defaultOptions,
      randomUint32: () => calls++ == 0 ? 0xffffffff : 123456,
    );
    expect(calls, 2);
    expect(c.casting['index'], 123456);
    expect(
      c.starPositions,
      ZiweiCastingChart.fromIndex(123456, defaultOptions).starPositions,
    );
    expect(
      () => ZiweiCastingChart.random(
        defaultOptions,
        randomUint32: () => 0xffffffff,
      ),
      throwsStateError,
    );
    expect(
      () => ZiweiCastingChart.random(defaultOptions, randomUint32: () => -1),
      throwsRangeError,
    );
    expect(
      () => ZiweiCastingChart.fromNumber('-1', defaultOptions),
      throwsArgumentError,
    );
    expect(
      () => ZiweiCastingChart.fromIndex(259200, defaultOptions),
      throwsRangeError,
    );
    expect(
      ZiweiCastingChart.fromNumber(
        '000123',
        defaultOptions,
      ).placementInput.toJson(),
      ZiweiCastingChart.fromNumber(
        BigInt.from(123),
        defaultOptions,
      ).placementInput.toJson(),
    );
    for (var y = 0; y < 60; y++) {
      final c = ZiweiCastingChart.fromIndex(y * 4320, defaultOptions);
      expect(
        [
          c.placementInput.yearGanIndex,
          c.placementInput.yearZhiIndex,
          c.placementInput.month,
          c.placementInput.day,
          c.placementInput.hourZhiIndex,
        ],
        [y % 10, y % 12, 1, 1, 0],
      );
    }
  });
  test('manager childhood is selectable before selecting a year', () {
    final c = natal(), m = c.createLimitManager();
    m.setDecadeIndex(0);
    expect(m.context.decade!.isChildhood, isTrue);
    expect(m.manifest.currentDecadeYears, isNotEmpty);
    expect(m.dynamicChart.flowStack.length, 1);
    final y = getEffectiveBirthYear(c);
    m.setYear(y);
    m.setMonth(m.manifest.currentYearMonths!.last.month);
    m.clearMonth();
    expect(m.context.month, isNull);
    expect(m.context.year!.year, y);
    m.clearDecade();
    expect(m.context.toJson(), isEmpty);
  });
  test('manager month/day/hour cascades and leap split navigation', () {
    final m = natal().createLimitManager();
    m.setYear(2023);
    m.setMonth(2, isLeap: true, effectiveMonth: 2);
    expect(m.context.month!.effectiveMonth, 2);
    m.addMonth(1);
    expect(m.context.month!.isLeap, isTrue);
    expect(m.context.month!.effectiveMonth, 3);
    m.setDay(16);
    m.setHour(0);
    expect(m.dynamicChart.flowStack.length, 5);
    m.addMonth(-1);
    expect(m.context.month!.effectiveMonth, 2);
    expect(m.context.day, isNull);
    expect(m.context.hour, isNull);
    m.clearDay();
    expect(m.context.month, isNotNull);
    m.clearYear();
    expect(m.timelineYear, isNull);
    expect(m.context.smallLimit, isNull);
    m.reset();
    expect(m.dynamicChart.flowStack, isEmpty);
  });
  test('split rat-hour stepping preserves minute and steps reversibly', () {
    for (final mode in RatHourMode.values) {
      final c = natal(defaultOptions.copyWith(ratHourMode: mode)),
          m = c.createLimitManager(),
          hours = c.timeline().getHours(c.facts.solarTermPillars.day);
      expect(hours.length, mode == RatHourMode.nextDay ? 12 : 13);
      if (mode == RatHourMode.currentDay) {
        expect(hours.first.stem, hours.last.stem);
      }
      if (mode == RatHourMode.currentDayTomorrowStem) {
        expect(hours.first.stem, isNot(hours.last.stem));
      }
      m.setPhysicalTime(time(2023, 5, 1, 22, 15));
      m.nextHour();
      expect(
        m.currentTarget!.virtualTime.hour,
        mode == RatHourMode.nextDay ? 0 : 23,
      );
      expect(m.currentTarget!.virtualTime.minute, 15);
      if (mode != RatHourMode.nextDay) {
        expect(m.context.hour!.ratHourSegment, RatHourSegment.late);
        m.nextHour();
        expect(m.context.hour!.ratHourSegment, RatHourSegment.early);
        m.previousHour();
        expect(m.currentTarget!.virtualTime.hour, 23);
      }
      m.nextDay();
      m.previousDay();
      expect(m.currentTarget!.virtualTime.minute, 15);
    }
  });
  test('failed physical step preserves prior manager state', () {
    final c = natal(), m = c.createLimitManager();
    m.setPhysicalTime(time(2000));
    final old = m.currentTarget;
    expect(m.previousHour, throwsRangeError);
    expect(identical(m.currentTarget, old), isTrue);
  });
  test(
    'reverse lookup forward-verifies finite search and direct century inversion',
    () {
      final c = natal();
      int b(String key) => c.starPositions[requireStarId(key)];
      final direct = reverseLookupZiweiTier1(
        start: time(1950, 1, 1, 0),
        end: time(2050, 12, 31, 23),
        options: defaultOptions,
        query: ZiweiTier1ReverseQuery(
          lucunBranch: b('lucun'),
          hongluanBranch: b('hongluan'),
          zuofuBranch: b('zuofu'),
          wenchangBranch: b('wenchang'),
          santaiBranch: b('santai'),
        ),
      );
      expect(direct.any((v) => (v.jdUT1 - c.facts.jdUT1).abs() < 1e-7), isTrue);
      final query = ZiweiTier1ReverseQuery(lucunBranch: b('lucun')),
          short = reverseLookupZiweiTier1(
            start: time(2000),
            end: time(2000, 1, 1, 14),
            options: defaultOptions,
            query: query,
          );
      expect(short, isNotEmpty);
      for (final v in short) {
        expect(query.matches(v.chart), isTrue);
      }
      expect(
        () => reverseLookupZiweiTier1(
          start: time(2000),
          end: time(2000, 1, 1, 14),
          options: defaultOptions,
          query: query,
          maxCandidatesToExamine: 1,
        ),
        throwsRangeError,
      );
      expect(() => ZiweiTier1ReverseQuery(), throwsArgumentError);
    },
  );
  test('solar day 33 and 1582 stepping survive edge calendars', () {
    expect(
      ZiweiChart.fromZonedTime(
        time(1999, 8, 8, 0),
        defaultOptions,
      ).facts.solarDayFromPreviousJie,
      33,
    );
    final t = ZiweiFlowTarget(
      time(1582, 10, 4).toJulianTime().jdUT1,
      time(1582, 10, 4),
    );
    expect(stepZiweiFlowDayTarget(t, 1).virtualTime.day, 15);
  });
  test('plate accessors, bitsets and dynamic layers validate state', () {
    final c = natal();
    expect(flattenZiweiAnchors(c.anchors).length, 31);
    for (final p in c.palaces) {
      for (final id in p.starIds) {
        expect((p.starBitset & (BigInt.one << id)) != BigInt.zero, isTrue);
        expect(c.getStarPosition(id)!.branch, p.branch);
      }
    }
    final d = ZiweiDynamicChart(c);
    expect(d.getFlowStarPosition(115), isNull);
    expect(
      () => d.push(
        makeFlowLayer(c, FlowLevel.month, FlowCoordinate(stem: 0, branch: 0)),
      ),
      throwsArgumentError,
    );
    expect(() => d.getRoleAtBranch(0, level: FlowLevel.year), throwsStateError);
    expect(() => c.getPalace(12), throwsRangeError);
    expect(() => c.starPositions[0] = 3, throwsUnsupportedError);
  });

  test(
    'JSON integral doubles and legacy numeric brightness preserve JS semantics',
    () {
      final rule = compileZiweiJsonPlacement({
        'type': 'constant',
        'value': 4.0,
      });
      expect(rule.positions, [4]);
      final ruleset = ZiweiConfigLoader.overrideWith(
        ZiweiRuleset(),
        label: 'numeric',
        brightnessJson: '{"ziwei":["6",6.0,6,6,6,6,6,6,6,6,6,6]}',
      );
      final c = natal(
        defaultOptions.copyWith(rules: ZiweiRuleSelection(ruleset: ruleset)),
      );
      expect(c.getStarPosition(requireStarId('ziwei'))!.brightness, 6);
    },
  );
}
