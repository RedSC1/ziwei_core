import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

LunarCalendarDate publicLunarResult(ResolvedZiweiBirth birth) =>
    birth.lunarDate;

void main() {
  test(
    'birth calendar/anchors match JS across historical dates and all accuracies',
    () {
      final cases =
          jsonDecode(File('test/fixtures/calendar-js.json').readAsStringSync())
              as List;
      for (final c in cases) {
        final v = c['clock'], o = c['options'];
        final result = resolveZiweiBirth(
          ZonedTime(
            year: v['year'],
            month: v['month'],
            day: v['day'],
            hour: v['hour'],
            offsetMinutes: v['offsetMinutes'],
          ),
          ZiweiOptions(
            gender: ZiweiGender.male,
            calendarOptions: CalendarOptions(
              eventAccuracy: Accuracy.values.byName(o['eventAccuracy']),
            ),
          ),
        );
        expect(
          {
            'solar': result.solarTermPillars.toJson(),
            'lunar': result.lunarPillars.toJson(),
            'bureau': result.anchors.bureau.index,
            'ziwei': result.anchors.ziwei,
            'tianfu': result.anchors.tianfu,
            'palaces': result.anchors.palacePositions,
            'body': result.anchors.bodyPalace,
            'effectiveYear': result.effectiveLunarYear,
            'effectiveMonth': result.effectiveLunarMonth,
            'day': result.lunarDate.day,
            'solarDay': result.solarDayFromPreviousJie,
          },
          c['expected'],
          reason: '$v $o',
        );
      }
    },
  );
  test('solar clock requires a valid longitude', () {
    expect(
      () => ZiweiOptions(
        gender: ZiweiGender.male,
        clockMode: ZiweiClockMode.trueSolar,
      ),
      throwsArgumentError,
    );
    expect(
      () => ZiweiOptions(gender: ZiweiGender.male, longitudeDeg: double.nan),
      throwsRangeError,
    );
  });
}
