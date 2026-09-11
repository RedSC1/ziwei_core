# 🔮 Ziwei Core

[中文](https://github.com/RedSC1/ziwei_core/blob/main/README.md)

A pure Dart port of `ziwei-lite`. Its astronomy and calendar core has moved from `sxwnl_spa_dart` to `ephemeris_lite`, and the rewritten package no longer depends on `bazi_core`.

Implemented: natal charts, placement variants, brightness and transformations, custom rule modules, decade/childhood/small limits, annual through hourly flows, historical calendar timelines, selection management, immutable chart modifications and reset, casting charts, deterministic reported-number mapping, unbiased random-index sampling, and reverse lookup.

> **Breaking release:** the rewritten API is not compatible with the previous `0.13.x` releases. Read the [migration guide](https://github.com/RedSC1/ziwei_core/blob/main/doc/migration.md) before upgrading. The previous implementation and its license remain available in Git history.

The previous release used `sxwnl_spa_dart`, whose primary goal is compatibility with an existing port. The rewrite uses the project-maintained `ephemeris_lite` so calendar-event accuracy, historical date assignment, solar time, and Zi-hour boundaries can be extended consistently when chart features require support from the astronomy core.

Natal-chart civil dates follow the core range of astronomical years −6000 through 10000, where year 0 is 1 BCE. This is a supported computation interval, not a claim of uniform accuracy across every epoch; historical-calendar and ΔT limitations follow the `ephemeris_lite` documentation. Casting charts without a birth date are independent of this civil-date range.

Current stable version: `1.0.0`.

`ZiweiClockMode.civil` is now the default. Legacy chart constructors enabled apparent solar time by default; preserving that behavior requires `ZiweiClockMode.trueSolar` and an explicit longitude.

## Installation

```yaml
dependencies:
  ziwei_core: ^1.0.0
```

Run `dart pub get`, or `flutter pub get` in a Flutter project.

## Natal chart

```dart
import 'package:ziwei_core/ziwei_core.dart';

final options = ZiweiOptions(
  gender: ZiweiGender.male,
  calendarOptions: CalendarOptions(eventAccuracy: Accuracy.mid),
);
final chart = ZiweiChart.fromZonedTime(
  ZonedTime(year: 2000, month: 1, day: 1, hour: 12, offsetMinutes: 480),
  options,
);
final modified = chart.modify(ZiweiModifyInput(month: 8, updateBureau: true));
final original = modified.reset();
final random = ZiweiCastingChart.random(options);
```

`modify` preserves the original birth facts. Changing the bureau also changes the starting limit age; shifting palace roles keeps stars and the body palace fixed. Casting charts deliberately have no calendar-dependent age or timeline API. Their index space contains 259,200 combinations. Reported-number mapping is reproducible, not a promise that human-chosen numbers are uniformly distributed.

Run `dart analyze`, `dart test`, and `dart run example/advanced.dart`. `tool/portable_check.dart` also compiles to JavaScript for cross-runtime verification. See [migration scope](https://github.com/RedSC1/ziwei_core/blob/main/doc/migration.md), [API mapping](https://github.com/RedSC1/ziwei_core/blob/main/doc/api-map.md), and [testing](https://github.com/RedSC1/ziwei_core/blob/main/doc/testing.md).

This rewrite follows the MPL-2.0 license of `ziwei-lite`. Previously released 0.13.0 code retains its original MIT license.
