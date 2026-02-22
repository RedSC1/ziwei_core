import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';
import 'package:ziwei_core/src/time/time_adapter.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';

void main() {
  group('TimeAdapter.fromStringLunar', () {
    late ZiweiRuleset defaultRuleset;

    setUpAll(() {
      defaultRuleset = ConfigLoader.getDefault();
    });

    test('Regular string "正" matches integer 1', () {
      final dateInt = TimeAdapter.fromLunar(
        2023,
        1,
        15,
        12,
        0,
        0,
        false,
        Gender.male,
        options: defaultRuleset.calendarOptions,
      );

      final dateStr = TimeAdapter.fromStringLunar(
        2023,
        "正",
        15,
        12,
        0,
        0,
        Gender.male,
        options: defaultRuleset.calendarOptions,
      );

      expect(dateInt.bazi.toString(), equals(dateStr.bazi.toString()));
      expect(
        dateInt.solar.toDateTime()!.toIso8601String(),
        equals(dateStr.solar.toDateTime()!.toIso8601String()),
      );
    });

    test('Leap string "闰二" matches integer 2 with isLeap=true', () {
      final dateInt = TimeAdapter.fromLunar(
        2023,
        2,
        15,
        10,
        30,
        0,
        true,
        Gender.female,
        options: defaultRuleset.calendarOptions,
      );

      final dateStr = TimeAdapter.fromStringLunar(
        2023,
        "闰二",
        15,
        10,
        30,
        0,
        Gender.female,
        options: defaultRuleset.calendarOptions,
      );

      expect(dateInt.bazi.toString(), equals(dateStr.bazi.toString()));
      expect(
        dateInt.solar.toDateTime()!.toIso8601String(),
        equals(dateStr.solar.toDateTime()!.toIso8601String()),
      );
    });

    test(
      'Historical string "后九" matches integer 9 with isLeap=true inside Zhuanxu Era',
      () {
        final histOptions = CalendarOptions(enableHistorical: true);

        final dateInt = TimeAdapter.fromLunar(
          -209,
          9,
          15,
          12,
          0,
          0,
          true,
          Gender.male,
          options: histOptions,
        );

        final dateStr = TimeAdapter.fromStringLunar(
          -209,
          "后九",
          15,
          12,
          0,
          0,
          Gender.male,
          options: histOptions,
        );

        expect(dateInt.bazi.toString(), equals(dateStr.bazi.toString()));
      },
    );
  });
}
