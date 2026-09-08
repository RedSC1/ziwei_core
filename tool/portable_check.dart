// VM and dart2js executable regression checks. No dart:io / FFI dependency.
import 'dart:convert';
import 'package:ziwei_core/ziwei_core.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

void main() {
  final options = ZiweiOptions(gender: ZiweiGender.male);
  final birth = ZonedTime(
    year: 2000,
    month: 1,
    day: 1,
    hour: 12,
    offsetMinutes: 480,
  );
  final chart = ZiweiChart.fromZonedTime(birth, options);
  final modified = chart
      .modify(ZiweiModifyInput(month: 12, day: 30, updateBureau: true))
      .shiftLifePalace(-3);
  final flow = modified.dynamicForTime(
    ZonedTime(year: 2023, month: 4, day: 6, hour: 23, offsetMinutes: 480),
  );
  final outputs = <Object>[
    chart.starPositions,
    chart.transformationMasks,
    modified.starPositions,
    modified.anchors.toJson(),
    flow.flowStack.map((v) => v.toJson()).toList(),
  ];
  for (final number in [
    '0',
    '123',
    '4294967295',
    '999999999999999999999999999999999',
  ]) {
    final cast = ZiweiCastingChart.fromNumber(number, options);
    outputs.add(cast.casting);
    outputs.add(cast.starPositions);
  }
  final rules = ZiweiConfigLoader.overrideWith(
    ZiweiRuleset(),
    label: 'custom',
    starsJson:
        '[{"key":"extra","type":"minor","rule":{"type":"constant","value":4}}]',
  );
  final custom = ZiweiChart.fromZonedTime(
        birth,
        options.copyWith(rules: ZiweiRuleSelection(ruleset: rules)),
      ),
      id = custom.findStarId('extra')!;
  check(
    (custom.palaces[4].starBitset & (BigInt.one << id)) != BigInt.zero,
    'high star bitset',
  );
  check(identical(modified.reset(), chart), 'reset identity');
  var calls = 0;
  final random = ZiweiCastingChart.random(
    options,
    randomUint32: () => calls++ == 0 ? 0xffffffff : 123456,
  );
  check(random.casting['index'] == 123456 && calls == 2, 'rejection sampling');
  print(jsonEncode(outputs));
}
