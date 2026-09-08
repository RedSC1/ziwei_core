import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:ziwei_core/ziwei_core.dart';

void main() {
  final cases =
      jsonDecode(File('test/fixtures/placement-js.json').readAsStringSync())
          as List;
  test(
    '480 JS manual arrangements: anchors, all stars, omissions, transformations',
    () {
      for (var i = 0; i < cases.length; i++) {
        final c = cases[i], v = c['input'], o = c['options'];
        final result = arrangeZiweiStars(
          ZiweiPlacementInput(
            yearGanIndex: v['yearGanIndex'],
            yearZhiIndex: v['yearZhiIndex'],
            month: v['month'],
            day: v['day'],
            hourZhiIndex: v['hourZhiIndex'],
          ),
          gender: ZiweiGender.values[o['gender']],
          chartMode: ZiweiChartMode.values[o['chartMode'] ?? 0],
        );
        expect(result.toJson(), c['expected'], reason: 'case $i');
      }
    },
  );
  test('range validation does not reject incompatible year pairs', () {
    expect(
      () => ZiweiPlacementInput(
        yearGanIndex: 10,
        yearZhiIndex: 0,
        month: 1,
        day: 1,
        hourZhiIndex: 0,
      ),
      throwsRangeError,
    );
    expect(
      () => ZiweiPlacementInput(
        yearGanIndex: 0,
        yearZhiIndex: 0,
        month: 13,
        day: 1,
        hourZhiIndex: 0,
      ),
      throwsRangeError,
    );
    final result = arrangeZiweiStars(
      ZiweiPlacementInput(
        yearGanIndex: 0,
        yearZhiIndex: 1,
        month: 1,
        day: 1,
        hourZhiIndex: 0,
      ),
      gender: ZiweiGender.male,
    );
    expect(result.omittedPlacements, isNotEmpty);
    expect(() => result.starPositions[0] = 4, throwsUnsupportedError);
    expect(() => result.anchors.palacePositions[0] = 4, throwsUnsupportedError);
  });
  test('retaining bureau preserves its ziwei calculation', () {
    final input = ZiweiPlacementInput(
      yearGanIndex: 9,
      yearZhiIndex: 7,
      month: 3,
      day: 14,
      hourZhiIndex: 4,
    );
    for (final bureau in Bureau.values) {
      final anchors = computePlacementAnchors(input, retainedBureau: bureau);
      expect(anchors.bureau, bureau);
      expect(anchors.ziwei, inInclusiveRange(0, 11));
    }
  });
}
