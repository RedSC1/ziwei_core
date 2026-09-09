import 'dart:convert';
import 'dart:io';
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

  test('legacy star declarations validate raw fields before projection', () {
    final rule = {'type': 'constant', 'value': 4};
    for (final isNatal in [true, false]) {
      ZiweiRuleModule compile(Map<String, dynamic> star) =>
          ZiweiConfigLoader.compileJson(
            label: 'raw-star-schema',
            starsJson: isNatal ? jsonEncode([star]) : null,
            flowJson: isNatal ? null : jsonEncode([star]),
          );
      for (final typo in ['brighness', 'tyep', 'catgory', 'natel', 'rulle']) {
        expect(
          () => compile({'key': 'extra', 'rule': rule, typo: 0}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('unknown JSON'),
            ),
          ),
        );
      }
      for (final categoryKey in ['type', 'category']) {
        final patch = compile({
          'key': 'extra',
          'rule': rule,
          categoryKey: 'minor',
          '_comment': 'supported metadata',
          if (!isNatal) 'brightness': List.filled(12, 6),
        }).patch;
        expect(patch['stars'], [
          {'key': 'extra', 'category': 'minor', 'natal': isNatal},
        ]);
        expect(
          patch[isNatal
              ? 'natalPlacements'
              : 'flowPlacements']['extra']['positions'],
          [4],
        );
        if (!isNatal) expect(patch['brightness']['extra'], List.filled(12, 6));
      }
      if (isNatal) {
        expect(
          () => compile({
            'key': 'extra',
            'rule': rule,
            'brightness': List.filled(12, 6),
          }),
          throwsArgumentError,
        );
      } else {
        expect(
          () => compile({'key': 'extra', 'rule': rule, 'brightness': null}),
          throwsA(isA<TypeError>()),
        );
      }
    }
  });

  test(
    'lookup tables reject keys outside their anchor domain, including nested rules',
    () {
      final stems = [
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
      ];
      final branches = [
        'zi',
        'chou',
        'yin',
        'mao',
        'chen',
        'si',
        'wu',
        'wei',
        'shen',
        'you',
        'xu',
        'hai',
      ];
      for (final (anchor, boundary, keys) in [
        ('year_stem', 'lunar', stems),
        ('month_stem', 'solar', stems),
        ('year_branch', 'lunar', branches),
        ('ming', 'lunar', branches),
        ('wuxingjv', 'lunar', ['water2', 'wood3', 'metal4', 'earth5', 'fire6']),
        ('month', 'lunar', List.generate(12, (i) => '$i')),
        ('day', 'lunar', List.generate(30, (i) => '$i')),
        ('day', 'solar', List.generate(33, (i) => '$i')),
      ]) {
        final table = {for (var i = 0; i < keys.length; i++) keys[i]: i % 12};
        for (final type in ['lookup', 'lookup_offset']) {
          final rule = {
            'type': type,
            'anchor': anchor,
            'boundary': boundary,
            'table': table,
            if (type == 'lookup_offset') 'shift_anchor': 'hour',
          };
          expect(compileZiweiJsonPlacement(rule).positions, isNotEmpty);
          final invalid = {
            ...rule,
            'table': {...table, 'jiaa': 0},
          };
          final error = throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('table field: jiaa'),
            ),
          );
          expect(() => compileZiweiJsonPlacement(invalid), error);
          expect(
            () => compileZiweiJsonPlacement({
              'type': 'pipeline',
              'steps': [invalid],
            }),
            error,
          );
          if (anchor == 'day') {
            expect(
              () => compileZiweiJsonPlacement({
                ...rule,
                'table': {...table, '${keys.length}': 0},
              }),
              throwsArgumentError,
            );
            final inherited = {...rule}..remove('boundary');
            expect(
              compileZiweiJsonPlacement({
                'type': 'pipeline',
                'boundary': boundary,
                'steps': [inherited],
              }).positions,
              compileZiweiJsonPlacement(rule).positions,
            );
          }
          final missing = {...table}..remove(keys.first);
          expect(
            () => compileZiweiJsonPlacement({...rule, 'table': missing}),
            throwsArgumentError,
          );
        }
      }
    },
  );

  test(
    'complete legacy natal and flow star configuration remains loadable',
    () {
      final fixture = jsonDecode(
        File('test/fixtures/legacy-stars.json').readAsStringSync(),
      );
      final ruleset = ZiweiConfigLoader.overrideWith(
        ZiweiRuleset(),
        label: 'legacy-complete',
        starsJson: jsonEncode(fixture['stars']),
        flowJson: jsonEncode(fixture['flow']),
      );
      final selected = selectZiweiRules(ZiweiRuleSelection(ruleset: ruleset));
      expect(selected.catalog.length, 159);
      for (final raw in fixture['stars'] as List) {
        if (raw['type'] == 'bad') {
          expect(
            selected.catalog.firstWhere((s) => s.key == raw['key']).category,
            'malefic',
          );
        }
      }
      final chart = ZiweiChart.fromZonedTime(
        time(2003, 3, 13, 14),
        defaultOptions.copyWith(
          rules: defaultOptions.rules.copyWith(ruleset: ruleset),
        ),
      );
      final dynamic = dynamicChartForTime(chart, time(2033, 12, 22)).chart;
      for (final raw in fixture['flow'] as List) {
        final star = dynamic.getFlowStar(findStarId(raw['key'])!)!;
        expect(star.branch, inInclusiveRange(0, 11));
        if (raw['brightness'] != null) {
          expect(star.brightness, raw['brightness'][star.branch]);
        }
      }
    },
  );

  test(
    'historical Jie boundaries agree across reverse, flow days and timeline',
    () {
      final module = ZiweiRuleModule(
        label: 'historical-probe',
        patch: {
          'natalPlacements': {
            'wenchang': {
              'inputs': ['solar.month_branch'],
              'shape': [12],
              'positions': List.generate(12, (i) => i),
            },
          },
        },
      );
      for (final probeMonth in [1, 9]) {
        for (final mode in PillarHistoricalMode.values) {
          for (final offset in [480, 0]) {
            final options = ZiweiOptions(
              gender: ZiweiGender.male,
              pillarHistoricalMode: mode,
              calendarOptions: CalendarOptions(
                utcOffsetMinutes: offset.toDouble(),
              ),
              flowLimitBoundary: PillarBoundary.solarTerm,
              rules: ZiweiRuleSelection(ruleset: ZiweiRuleset([module])),
            );
            final term = eph.getNextJie(
              time(100, probeMonth, 1).toJulianTime().jdUT1,
              options: options.calendarOptions,
            );
            final boundary = mode == PillarHistoricalMode.off
                ? term.time.jdUT1
                : eph.historicalEventCivilDay(
                        eph.HistoricalEventKind.solarTerm,
                        term.time.jdUT1,
                      )! -
                      0.5 -
                      480 / 1440;
            ZonedTime at(int seconds) => eph.JulianTime.fromUT1(
              boundary + seconds / 86400,
            ).toZonedTime(offset);
            final chart = ZiweiChart.fromZonedTime(time(99, 1, 1), options);
            final pre = ZiweiChart.fromZonedTime(at(-1800), options),
                post = ZiweiChart.fromZonedTime(at(1800), options),
                id = findStarId('wenchang')!;
            expect(pre.starPositions[id], isNot(post.starPositions[id]));
            final rows = reverseLookupZiweiTier1(
              start: at(-1800),
              end: at(1800),
              options: options,
              query: ZiweiTier1ReverseQuery(
                wenchangBranch: post.starPositions[id],
              ),
            );
            expect(rows.any((r) => (r.jdUT1 - boundary).abs() < 1e-8), isTrue);
            final months = chart.timeline().getMonths(
              probeMonth == 1 ? 99 : 100,
            );
            expect(
              months
                  .firstWhere((m) => m.month == (probeMonth == 1 ? 12 : 8))
                  .solarStartJd,
              closeTo(boundary, 1e-8),
            );
            for (final seconds in [-1800, 1800]) {
              final instant = at(seconds),
                  flow = resolveZiweiFlow(chart, instant),
                  jd = instant.toJulianTime().jdUT1;
              final row = months.firstWhere(
                (m) => m.solarStartJd <= jd && m.solarEndJdExclusive > jd,
              );
              expect(row.month, flow.targetMonth);
              expect(
                chart
                    .timeline()
                    .getDays(flow.effectiveTargetYear, flow.targetMonth)
                    .any((d) => d.day == flow.targetDay),
                isTrue,
              );
            }
            expect(post.facts.solarDayFromPreviousJie, 1);
          }
        }
      }
    },
  );
  test('fractional configured offsets are rejected before chart creation', () {
    for (final offset in [480.5, -0.5]) {
      expect(
        () => ZiweiOptions(
          gender: ZiweiGender.male,
          calendarOptions: CalendarOptions(utcOffsetMinutes: offset),
        ),
        throwsArgumentError,
      );
    }
    for (final offset in [-840.0, 0.0, 840.0]) {
      expect(
        ZiweiOptions(
          gender: ZiweiGender.male,
          calendarOptions: CalendarOptions(utcOffsetMinutes: offset),
        ).utcOffsetMinutes,
        offset,
      );
    }
  });

  test('legacy JSON rule typos cannot fall through to optional defaults', () {
    for (final rule in [
      {'type': 'anchor_offset', 'anchor': 'month', 'offest': 2},
      {'type': 'constant', 'vaule': 4},
      {
        'type': 'pipeline',
        'steps': [
          {'type': 'constant', 'value': 2, 'vaule': 4},
        ],
      },
    ]) {
      expect(() => compileZiweiJsonPlacement(rule), throwsArgumentError);
    }
    expect(
      compileZiweiJsonPlacement({
        'type': 'constant',
        'value': 4,
        '_comment': 'note',
      }).positions,
      [4],
    );
  });
  test(
    'fixed rule schemas reject unknown fields instead of silently ignoring them',
    () {
      expect(
        () => ZiweiCompiledPlacement.fromJson({
          'inputs': [],
          'shape': [],
          'positions': [0],
          'positons': [1],
        }),
        throwsArgumentError,
      );
      final compiled = ZiweiCompiledPlacement.fromJson({
        'inputs': [],
        'shape': [],
        'positions': [4],
        'starId': 7,
      });
      expect(compiled.positions, [4]);
      expect(compiled.starId, 7);
      expect(ZiweiCompiledPlacement.fromJson(compiled.toJson()).positions, [4]);
      final master = {
        'input': 'anchor.life',
        'stars': List.filled(12, 'ziwei'),
      };
      for (final patch in <Map<String, dynamic>>[
        {
          'masters': {'bdy': master},
        },
        {
          'masters': {'life': master, 'bdy': master},
        },
        {
          'mastrs': {'life': master},
        },
        {
          'masters': {
            'body': {...master, 'inpt': 'anchor.life'},
          },
        },
        {
          'stars': [
            {'key': 'custom', 'natal': true, 'natel': true},
          ],
        },
        {
          'natalPlacements': {
            'wenchang': {
              'inputs': [],
              'shape': [],
              'positions': [0],
              'positons': [1],
            },
          },
        },
      ]) {
        expect(
          () => ZiweiRuleModule(label: 'invalid-schema', patch: patch),
          throwsArgumentError,
        );
      }
      final table = {for (var i = 0; i < 12; i++) '$i': 'ziwei'};
      for (final raw in [
        {
          'shen_zh': {'table': table},
        },
        {
          'shen_zhu': {'table': table, 'boundry': 'solar'},
        },
        {
          'shen_zhu': {
            'table': {...table, '12': 'ziwei'},
          },
        },
      ]) {
        expect(
          () => ZiweiConfigLoader.compileJson(
            label: 'invalid-schema',
            mastersJson: jsonEncode(raw),
          ),
          throwsArgumentError,
        );
      }
      expect(
        ZiweiRuleModule(
          label: 'valid',
          patch: {
            'masters': {'life': master, 'body': master},
          },
        ).patch['masters'],
        isNotEmpty,
      );
      expect(
        ZiweiConfigLoader.compileJson(
          label: 'valid',
          mastersJson: jsonEncode({
            '_comment': 'note',
            'shen_zhu': {'table': table, '_comment': 'note'},
          }),
        ).patch['masters'],
        isNotEmpty,
      );
    },
  );
  test('sihua rejects unknown transformation keys at both entry points', () {
    for (final row in [
      {'kua': 'ziwei'},
      {'lu': 'ziwei', 'kua': 'tianji'},
    ]) {
      expect(
        () => ZiweiRuleModule(
          label: 'bad',
          patch: {
            'sihua': {'jia': row},
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => ZiweiConfigLoader.compileJson(
          label: 'bad',
          sihuaJson: jsonEncode({'jia': row}),
        ),
        throwsArgumentError,
      );
    }
    expect(
      ZiweiRuleModule(
        label: 'valid',
        patch: {
          'sihua': {
            'jia': {'quan': 'ziwei'},
          },
        },
      ).patch['sihua'],
      isNotEmpty,
    );
  });
  test('historical repeated months retain identity through day selection', () {
    final c = ZiweiChart.fromZonedTime(time(1), defaultOptions),
        t = c.timeline(),
        m = c.createLimitManager();
    final months = t
        .getMonths(23)
        .where((v) => v.month == 12 && !v.isLeap)
        .toList();
    expect(months.map((v) => v.sequence), [12, 13]);
    m.setYear(23);
    for (final n in months) {
      m.selectMonth(n);
      final expected = eph.calendarDateFromJulianDay(
        n.firstCivilDayNumber - 0.5,
      );
      final days = t.getDays(
        23,
        12,
        effectiveMonth: 12,
        effectiveYear: 23,
        sequence: n.sequence,
      );
      expect(days.first.solarDate.day, expected.day);
      expect(m.manifest.currentMonthDays!.first.solarDate.day, expected.day);
      m.setDay(1);
      expect(m.context.day!.limit.coordinate.stem, days.first.stem);
    }
    m.addMonth(-1);
    expect(m.manifest.currentMonthDays!.first.solarDate.day, 2);
    m.addMonth(1);
    expect(m.manifest.currentMonthDays!.first.solarDate.day, 31);
    m.setMonth(12, sequence: 13);
    expect(m.context.month!.sequence, 13);
    m.setPhysicalTime(time(23, 12, 31));
    expect(m.manifest.currentMonthDays!.first.solarDate.day, 31);
  });
  test(
    'natal modules reject unknown inputs and invalid domains at construction',
    () {
      for (final input in [
        'unknown',
        'constructor',
        'lunar.year_branch',
        'lunar.day_index',
        'solar.day_index',
      ]) {
        expect(
          () => ZiweiRuleModule(
            label: 'bad-natal',
            patch: {
              'natalPlacements': {
                'wenchang': {
                  'inputs': [input],
                  'shape': [1],
                  'positions': [0],
                },
              },
            },
          ),
          throwsArgumentError,
        );
      }
      for (final e in {
        'lunar.year_branch': 12,
        'lunar.day_index': 30,
        'solar.day_index': 33,
        'anchor.bureau': 5,
        'birth.gender': 2,
      }.entries) {
        final module = ZiweiRuleModule(
          label: 'valid-natal',
          patch: {
            'natalPlacements': {
              'wenchang': {
                'inputs': [e.key],
                'shape': [e.value],
                'positions': List.generate(e.value, (i) => i % 12),
              },
            },
          },
        );
        final c = natal(
          defaultOptions.copyWith(
            rules: ZiweiRuleSelection(ruleset: ZiweiRuleset([module])),
          ),
        );
        expect(
          c.starPositions[requireStarId('wenchang')],
          inInclusiveRange(0, 11),
        );
      }
    },
  );
  test('month selection rejects forged nodes and preserves physical state', () {
    final c = natal(), m = c.createLimitManager();
    m.setPhysicalTime(time(2026, 4, 20));
    final node = c.timeline().getMonths(2026).first,
        before = m.context,
        target = m.currentTarget;
    final forged = MonthNode(
      lunarYear: node.lunarYear,
      month: node.month,
      sequence: node.sequence,
      effectiveMonth: node.effectiveMonth,
      effectiveYear: node.effectiveYear,
      dayStart: node.dayStart,
      dayEnd: node.dayEnd,
      monthBuildingBranch: (node.monthBuildingBranch + 1) % 12,
      stem: node.stem,
      branch: node.branch,
      displayBranch: node.displayBranch,
      firstCivilDayNumber: node.firstCivilDayNumber,
      dayCount: node.dayCount,
      monthName: node.monthName,
      displayLabel: node.displayLabel,
      isLeap: node.isLeap,
      solarStartJd: node.solarStartJd,
      solarEndJdExclusive: node.solarEndJdExclusive,
    );
    expect(() => m.selectMonth(forged), throwsRangeError);
    expect(identical(m.context, before), isTrue);
    expect(identical(m.currentTarget, target), isTrue);
    m.selectMonth(node);
    expect(m.context.month!.month, node.month);
  });
  test('direct flow modules validate supported inputs and domains', () {
    for (final input in ['lunar.month_index', 'solar.day_index', 'unknown']) {
      expect(
        () => ZiweiRuleModule(
          label: 'bad-flow',
          patch: {
            'flowPlacements': {
              'flow_lucun': {
                'inputs': [input],
                'shape': [12],
                'positions': List.filled(12, 0),
              },
            },
          },
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => ZiweiRuleModule(
        label: 'short-flow',
        patch: {
          'flowPlacements': {
            'flow_lucun': {
              'inputs': ['lunar.year_branch'],
              'shape': [1],
              'positions': [0],
            },
          },
        },
      ),
      throwsArgumentError,
    );
    final module = ZiweiRuleModule(
      label: 'valid-flow',
      patch: {
        'flowPlacements': {
          'flow_lucun': {
            'inputs': ['lunar.year_branch'],
            'shape': [12],
            'positions': List.generate(12, (i) => i),
          },
        },
      },
    );
    expect(module.patch['flowPlacements'], isNotEmpty);
  });
  test('hour selection rejects stale and incompatible nodes atomically', () {
    for (final mode in RatHourMode.values) {
      final m = natal(
        defaultOptions.copyWith(ratHourMode: mode),
      ).createLimitManager();
      m.setYear(2026);
      m.setMonth(1);
      m.setDay(1);
      final old = m.manifest.currentDayHours!.first;
      m.setDay(2);
      m.setHour(0);
      final before = m.context;
      expect(() => m.selectHour(old), throwsRangeError);
      expect(identical(m.context, before), isTrue);
      final fresh = m.manifest.currentDayHours!.first;
      m.selectHour(
        HourNode(
          hourIndex: fresh.hourIndex,
          branchIndex: fresh.branchIndex,
          stem: fresh.stem,
          branch: fresh.branch,
          label: fresh.label,
          isEarlyRat: fresh.isEarlyRat,
          isLateRat: fresh.isLateRat,
        ),
      );
      final now = m.context;
      expect(
        () => m.selectHour(
          HourNode(
            hourIndex: fresh.hourIndex,
            branchIndex: fresh.branchIndex,
            stem: fresh.stem,
            branch: fresh.branch,
            label: fresh.label,
            isEarlyRat: !fresh.isEarlyRat,
            isLateRat: fresh.isLateRat,
          ),
        ),
        throwsRangeError,
      );
      expect(identical(m.context, now), isTrue);
    }
  });
  test('selected day rejects stale nodes without mutating state', () {
    final m = natal().createLimitManager();
    m.setYear(2026);
    m.setMonth(1);
    final old = m.manifest.currentMonthDays!.first;
    m.setMonth(3);
    m.setDay(1);
    final before = m.context;
    expect(() => m.selectDay(old), throwsRangeError);
    expect(identical(m.context, before), isTrue);
    final fresh = m.manifest.currentMonthDays!.first;
    m.selectDay(
      DayNode(
        day: fresh.day,
        stem: fresh.stem,
        branch: fresh.branch,
        solarDate: fresh.solarDate,
      ),
    );
    expect(m.context.day!.limit.coordinate.stem, fresh.stem);
    final unchanged = m.context;
    expect(
      () => m.selectDay(
        DayNode(
          day: fresh.day,
          stem: (fresh.stem + 1) % 10,
          branch: fresh.branch,
          solarDate: fresh.solarDate,
        ),
      ),
      throwsRangeError,
    );
    expect(identical(m.context, unchanged), isTrue);
  });
  test(
    'master boundary rejects invalid supplied values and preserves defaults',
    () {
      for (final key in ['ming_zhu', 'shen_zhu']) {
        ZiweiRuleModule compile(Map<String, dynamic> extra) =>
            ZiweiConfigLoader.compileJson(
              label: 'master-boundary',
              mastersJson: jsonEncode({
                key: {
                  'table': {for (var i = 0; i < 12; i++) '$i': 'ziwei'},
                  ...extra,
                },
              }),
            );
        final name = key == 'ming_zhu' ? 'life' : 'body';
        expect(
          (compile({}).patch['masters'] as Map)[name]['input'],
          key == 'ming_zhu' ? 'anchor.life' : 'master.year_branch',
        );
        for (final valid in ['lunar', 'solar']) {
          expect(
            (compile({'boundary': valid}).patch['masters']
                as Map)[name]['input'],
            '$valid.year_branch',
          );
        }
        for (final invalid in ['solr', '', null, 0, true]) {
          expect(() => compile({'boundary': invalid}), throwsArgumentError);
        }
      }
    },
  );
  test(
    'review3: civil clock normalizes input offset without changing instant',
    () {
      final utc = ZonedTime(
        year: 2026,
        month: 3,
        day: 20,
        hour: 18,
        offsetMinutes: 0,
      );
      final local = utc.toJulianTime().toZonedTime(480);
      final a = ZiweiChart.fromZonedTime(utc, defaultOptions),
          b = ZiweiChart.fromZonedTime(local, defaultOptions);
      expect(a.facts.virtualTime.hour, b.facts.virtualTime.hour);
      expect(a.facts.virtualTime.day, b.facts.virtualTime.day);
      expect(a.facts.solarDayFromPreviousJie, b.facts.solarDayFromPreviousJie);
      expect(a.starPositions, b.starPositions);
    },
  );
  test('review3: late Zi selectable index round trips physical flow', () {
    for (final mode in [
      RatHourMode.currentDay,
      RatHourMode.currentDayTomorrowStem,
    ]) {
      final c = natal(defaultOptions.copyWith(ratHourMode: mode)),
          m = c.createLimitManager();
      m.setPhysicalTime(time(2026, 3, 20, 23, 30));
      final f = m.resolvedFlow!, old = f.hour.limit.coordinate;
      expect(f.targetHourIndex, 12);
      m.setHour(f.targetHourIndex);
      expect(m.context.hour!.ratHourSegment, RatHourSegment.late);
      expect(m.context.hour!.limit.coordinate.toJson(), old.toJson());
    }
  });
  test('review3: custom solar placement reverse detects mid-hour Jie', () {
    final module = ZiweiRuleModule(
      label: 'solar-month',
      patch: {
        'natalPlacements': {
          'wenchang': {
            'inputs': ['solar.month_branch'],
            'shape': [12],
            'positions': List.generate(12, (i) => i),
          },
        },
      },
    );
    final o = defaultOptions.copyWith(
      rules: ZiweiRuleSelection(ruleset: ZiweiRuleset([module])),
    );
    final jie = eph
        .getNextJie(
          time(2026, 3, 1).toJulianTime().jdUT1,
          options: o.calendarOptions,
        )
        .time
        .jdUT1;
    ZonedTime at(double delta) =>
        eph.JulianTime.fromUT1(jie + delta / 86400).toZonedTime(480);
    final post = ZiweiChart.fromZonedTime(at(30), o),
        pre = ZiweiChart.fromZonedTime(at(-30), o),
        id = requireStarId('wenchang');
    expect(pre.starPositions[id], isNot(post.starPositions[id]));
    final rows = reverseLookupZiweiTier1(
      start: at(-30),
      end: at(30),
      options: o,
      query: ZiweiTier1ReverseQuery(wenchangBranch: post.starPositions[id]),
    );
    expect(rows, isNotEmpty);
    expect(rows.first.jdUT1, closeTo(jie, 1e-8));
  });
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
  test(
    'makeFlowHour round-trips every timeline slot in all rat-hour modes',
    () {
      for (final mode in RatHourMode.values) {
        final chart = natal(defaultOptions.copyWith(ratHourMode: mode));
        final month = makeFlowMonth(chart, 2023, 5, sequence: 5);
        for (var pillar = 0; pillar < 60; pillar++) {
          final day = makeFlowDay(chart, month, 1, pillar % 10);
          for (final node in chart.timeline().getHours(
            eph.makeGanzhi(pillar % 10, pillar % 12),
          )) {
            final segment = node.isLateRat
                ? RatHourSegment.late
                : node.isEarlyRat
                ? RatHourSegment.early
                : node.branch == 0
                ? RatHourSegment.unified
                : RatHourSegment.none;
            final hour = makeFlowHour(chart, day, node.hourIndex);
            expect(
              hour.toJson(),
              makeFlowHourFromPillar(
                chart,
                day,
                eph.makeGanzhi(node.stem, node.branch),
                segment,
              ).toJson(),
            );
            expect(hour.hourIndex, node.hourIndex);
            expect(hour.limit.coordinate.stem, node.stem);
            expect(
              hour.limit.coordinate.branch,
              (day.limit.coordinate.branch + node.branch) % 12,
            );
          }
        }
        for (final invalid in [-1, 13, if (mode == RatHourMode.nextDay) 12]) {
          expect(
            () => makeFlowHour(chart, makeFlowDay(chart, month, 1, 0), invalid),
            throwsArgumentError,
          );
        }
      }
    },
  );

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
