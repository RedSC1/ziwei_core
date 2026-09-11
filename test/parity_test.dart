import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';
import 'package:ephemeris_lite/ephemeris_lite.dart' as eph;

ZonedTime clock(Map v) => ZonedTime(
  year: v['year'],
  month: v['month'],
  day: v['day'],
  hour: v['hour'] ?? 0,
  minute: v['minute'] ?? 0,
  second: (v['second'] ?? 0).toDouble(),
  offsetMinutes: v['offsetMinutes'] ?? 480,
);
ZiweiOptions options(Map v, {ZiweiRuleset? ruleset}) => ZiweiOptions(
  gender: ZiweiGender.values[v['gender'] ?? 0],
  calendarOptions: CalendarOptions(
    eventAccuracy: Accuracy.values.byName(v['eventAccuracy'] ?? 'mid'),
  ),
  chartMode: ZiweiChartMode.values[v['chartMode'] ?? 0],
  ratHourMode:
      RatHourMode.values[[
        'next-day',
        'current-day',
        'current-day-tomorrow-stem',
      ].indexOf(v['ratHourMode'] ?? 'next-day')],
  clockMode:
      ZiweiClockMode.values[[
        'civil',
        'mean-solar',
        'true-solar',
      ].indexOf(v['clockMode'] ?? 'civil')],
  longitudeDeg: (v['longitudeDeg'] as num?)?.toDouble(),
  leapMonthStrategy: LeapMonthStrategy.values[v['leapMonthStrategy'] ?? 2],
  wuHuDunYearBoundary: PillarBoundary.values[v['wuHuDunYearBoundary'] ?? 1],
  sihuaYearBoundary: PillarBoundary.values[v['sihuaYearBoundary'] ?? 1],
  bodyMasterYearBoundary:
      PillarBoundary.values[v['bodyMasterYearBoundary'] ?? 1],
  flowLimitBoundary: PillarBoundary.values[v['flowLimitBoundary'] ?? 1],
  flowMonthPalaceStrategy:
      FlowMonthPalaceStrategy.values[v['flowMonthPalaceStrategy'] ?? 0],
  childhoodStrategy: ChildhoodStrategy.values[v['childhoodStrategy'] ?? 0],
  rules: ZiweiRuleSelection(ruleset: ruleset),
);
ZiweiModifyInput edit(Map v) => ZiweiModifyInput(
  yearGanIndex: v['yearGanIndex'],
  yearZhiIndex: v['yearZhiIndex'],
  month: v['month'],
  day: v['day'],
  hourZhiIndex: v['hourZhiIndex'],
  updateBureau: v['updateBureau'],
);
void same(dynamic actual, dynamic expected, [String path = '']) {
  if (actual is Map && expected is Map) {
    final actualKeys = actual.keys.toSet();
    // Old frozen JS fixtures predate the additive chartTime alias. The
    // compatibility virtualTime value is compared below; dedicated behavior
    // tests verify that the two current fields remain equal.
    if (!expected.containsKey('chartTime') &&
        actual.containsKey('chartTime') &&
        actual.containsKey('virtualTime')) {
      actualKeys.remove('chartTime');
    }
    expect(actualKeys, expected.keys.toSet(), reason: path);
    for (final k in expected.keys) {
      same(actual[k], expected[k], '$path.$k');
    }
    return;
  }
  if (actual is List && expected is List) {
    expect(actual.length, expected.length, reason: path);
    for (var i = 0; i < expected.length; i++) {
      same(actual[i], expected[i], '$path[$i]');
    }
    return;
  }
  if (actual is num &&
      expected is num &&
      (actual is double || expected is double)) {
    expect(
      actual,
      closeTo(expected, path.endsWith('second') ? 0.0001 : 0.00000001),
      reason: path,
    );
    return;
  }
  expect(actual, expected, reason: path);
}

Map compact(dynamic chart) {
  final Map value = chart.toJson();
  value.remove('options');
  return value;
}

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/parity-js.json').readAsStringSync(),
  );
  for (var i = 0; i < fixture['charts'].length; i++) {
    test('JS birth chart, chained modifications and limits $i', () {
      final c = fixture['charts'][i],
          chart = ZiweiChart.fromZonedTime(
            clock(c['input']),
            options(c['options']),
          );
      same(compact(chart), c['expected']);
      final m1 = chart.modify(edit(c['edits'][0])),
          m2 = m1.modify(edit(c['edits'][1])),
          shift = m2.shiftLifePalace(-5),
          again = shift.modify(ZiweiModifyInput(day: 1));
      final modified = [m1, m2, shift, again];
      for (var j = 0; j < 4; j++) {
        same(compact(modified[j]), c['modified'][j]);
        expect(identical(modified[j].reset(), chart), isTrue);
      }
      final variants = [chart, m1, m2, shift];
      for (var j = 0; j < 4; j++) {
        final v = variants[j], y = getEffectiveBirthYear(v);
        same([
          y,
          getStartDecadeYear(v),
          makeDecadeByIndex(v, y, 2).toJson(),
        ], c['limits'][j]);
      }
    });
  }
  for (final c in fixture['casting']) {
    test('JS casting ${c['method']} ${c['value']}', () {
      final o = ZiweiOptions(gender: ZiweiGender.female),
          chart = c['method'] == 'index'
              ? ZiweiCastingChart.fromIndex(c['value'], o)
              : ZiweiCastingChart.fromNumber(c['value'], o);
      same(compact(chart), c['expected']);
      final m = chart
          .modify(ZiweiModifyInput(month: 8, day: 23, updateBureau: true))
          .shiftLifePalace(3)
          .modify(ZiweiModifyInput(yearZhiIndex: 4));
      same(compact(m), c['modified']);
      expect(identical(m.reset(), chart), isTrue);
    });
  }
  for (var i = 0; i < fixture['flows'].length; i++) {
    test('JS physical flow $i', () {
      final c = fixture['flows'][i],
          chart = ZiweiChart.fromZonedTime(
            clock(c['input']),
            options(c['options']),
          ),
          flow = resolveZiweiFlow(chart, clock(c['target']));
      same(flow.toJson(), c['expected']);
      final dynamic = dynamicChartFromResolvedFlow(chart, flow).toJson()
        ..remove('natal');
      same(dynamic, c['dynamic']);
    });
  }
  for (final c in fixture['timelines']) {
    test('JS historical timeline ${c['year']}', () {
      final chart = ZiweiChart.fromZonedTime(
            clock(c['input']),
            options(c['options']),
          ),
          t = chart.timeline(),
          months = t.getMonths(c['year']);
      same(months.map((v) => v.toJson()).toList(), c['months']);
      final m = months.first;
      same(
        t
            .getDays(
              c['year'],
              m.month,
              isLeap: m.isLeap,
              effectiveMonth: m.effectiveMonth,
              effectiveYear: m.effectiveYear,
            )
            .map((v) => v.toJson())
            .toList(),
        c['days'],
      );
    });
  }
  for (var i = 0; i < fixture['rules'].length; i++) {
    test('JS custom rule resources $i', () {
      final c = fixture['rules'][i],
          p = c['patch'],
          module = ZiweiConfigLoader.compileJson(
            label: 'test',
            starsJson: p['starsJson'],
            flowJson: p['flowJson'],
            brightnessJson: p['brightnessJson'],
            sihuaJson: p['sihuaJson'],
          );
      final chart = ZiweiChart.fromZonedTime(
        clock(c['input']),
        options({}, ruleset: ZiweiRuleset([module])),
      );
      same(compact(chart), c['expected']);
      final f = makeFlowLayer(
        chart,
        FlowLevel.decade,
        FlowCoordinate(stem: 0, branch: 2),
      );
      same({
        ...f.toJson(),
        'starBitsets': f.starBitsets.map((v) => v.toString()).toList(),
      }, c['flow']);
    });
  }
  test('1200 frozen native C++ natal/flow oracle cases', () {
    final rows = jsonDecode(
      File('test/fixtures/flows-cpp.json').readAsStringSync(),
    )['rows'];
    expect(rows.length, 1200);
    for (var i = 0; i < rows.length; i++) {
      final input = rows[i]['input'];
      final int y = input[0], m = input[1], d = input[2], h = input[3];
      final o = ZiweiOptions(gender: ZiweiGender.values[input[4]]),
          p = eph.FourPillars(
            year: eph.makeGanzhi(y % 10, y % 12),
            month: eph.makeGanzhi((y % 10 % 5 * 2 + 1 + m) % 10, (m + 1) % 12),
            day: eph.makeGanzhi((d - 1) % 10, (d - 1) % 12),
            hour: eph.makeGanzhi(((d - 1) % 10 % 5 * 2 + h) % 10, h),
          ),
          a = computePlacementAnchors(
            ZiweiPlacementInput(
              yearGanIndex: y % 10,
              yearZhiIndex: y % 12,
              month: m,
              day: d,
              hourZhiIndex: h,
            ),
          );
      final birth = ResolvedZiweiBirth(
            clockTime: null,
            chartTime: const CalendarDate(year: 2000, month: 1, day: 1),
            jdUT1: 0,
            lunarDate: eph.LunarCalendarDate(
              year: 1984 + y,
              month: m,
              day: d,
              isLeap: false,
              monthName: MonthName.normal,
              historicalYear: 1984 + y,
              monthDays: 30,
            ),
            solarTermPillars: p,
            lunarPillars: p,
            effectiveLunarYear: 1984 + y,
            effectiveLunarMonth: m,
            solarDayFromPreviousJie: d,
            anchors: a,
            options: o,
          ),
          chart = ZiweiChart.fromResolvedBirth(birth),
          flow = makeFlowLayer(
            chart,
            FlowLevel.values[input[5]],
            FlowCoordinate(stem: input[6], branch: input[7]),
          );
      same(
        [
          a.palacePositions[0],
          chart.bodyPalace,
          a.bureau.index,
          chart.starPositions.map((n) => n < 0 ? 255 : n).toList(),
          chart.transformationMasks,
          flow.starPositions.map((n) => n < 0 ? 255 : n).toList(),
          flow.transforms.values.toList(),
        ],
        rows[i]['expected'],
        'C++ row $i',
      );
    }
  });

  final extra = jsonDecode(
    File('test/fixtures/extra-js.json').readAsStringSync(),
  );
  for (var i = 0; i < extra['variants'].length; i++) {
    test('JS builtin rule variant $i', () {
      final c = extra['variants'][i], r = c['rule'];
      final chart = ZiweiChart.fromZonedTime(
        clock({'year': 2003, 'month': 3, 'day': 14, 'hour': 0}),
        ZiweiOptions(
          gender: ZiweiGender.female,
          rules: ZiweiRuleSelection(
            placement: Map<String, String>.from(r['placement'] ?? {}),
            brightness: Map<String, String>.from(r['brightness'] ?? {}),
            sihua: Map<String, String>.from(r['sihua'] ?? {}),
            longevity: r['longevity'] ?? 'option1',
          ),
        ),
      );
      same(chart.starPositions, c['positions']);
      same(chart.transformationMasks, c['masks']);
      same([chart.lifeMaster, chart.bodyMaster], c['masters']);
      same(
        chart.starCatalog
            .map((s) => chart.getStarPosition(s.id)?.brightness)
            .toList(),
        c['brightness'],
      );
    });
  }
  for (var i = 0; i < extra['reverse'].length; i++) {
    test('JS reverse search, clocks and split-Zi $i', () {
      final c = extra['reverse'][i], q = c['query'];
      final results = reverseLookupZiweiTier1(
        start: clock(c['start']),
        end: clock(c['end']),
        options: options(c['options']),
        query: ZiweiTier1ReverseQuery(
          lucunBranch: q['lucunBranch'],
          hongluanBranch: q['hongluanBranch'],
          zuofuBranch: q['zuofuBranch'],
          wenchangBranch: q['wenchangBranch'],
          santaiBranch: q['santaiBranch'],
        ),
      );
      same(
        results
            .map(
              (v) => {
                'jdUT1': v.jdUT1,
                'hourBranch': v.hourBranch,
                'ratHourSegment': v.ratHourSegment.index,
                'starPositions': v.chart.starPositions,
              },
            )
            .toList(),
        c['expected'],
      );
    });
  }
}
