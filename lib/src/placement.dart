part of '../ziwei_core.dart';

enum ZiweiGender { male, female }

enum ZiweiChartMode { tianPan, diPan, renPan }

enum Bureau {
  water2(2),
  wood3(3),
  metal4(4),
  earth5(5),
  fire6(6);

  const Bureau(this.number);
  final int number;
}

int _checked(int value, int min, int max, String name) {
  if (value < min || value > max) throw RangeError.range(value, min, max, name);
  return value;
}

/// Discrete placement coordinates, not a civil birthday. Incompatible year
/// stem/branch pairs are accepted; dependent cycle rules are then omitted.
class ZiweiPlacementInput {
  ZiweiPlacementInput({
    required int yearGanIndex,
    required int yearZhiIndex,
    required int month,
    required int day,
    required int hourZhiIndex,
  }) : yearGanIndex = _checked(yearGanIndex, 0, 9, 'yearGanIndex'),
       yearZhiIndex = _checked(yearZhiIndex, 0, 11, 'yearZhiIndex'),
       month = _checked(month, 1, 12, 'month'),
       day = _checked(day, 1, 30, 'day'),
       hourZhiIndex = _checked(hourZhiIndex, 0, 11, 'hourZhiIndex');
  final int yearGanIndex, yearZhiIndex, month, day, hourZhiIndex;
  Map<String, int> toJson() => {
    'yearGanIndex': yearGanIndex,
    'yearZhiIndex': yearZhiIndex,
    'month': month,
    'day': day,
    'hourZhiIndex': hourZhiIndex,
  };
}

class PlacementAnchors {
  PlacementAnchors(
    this.bureau,
    this.ziwei,
    this.bodyPalace,
    List<int> palaces,
    List<int> stems,
  ) : tianfu = (4 - ziwei) % 12,
      palacePositions = List.unmodifiable(palaces),
      palaceStems = List.unmodifiable(stems);
  final Bureau bureau;
  final int ziwei, tianfu, bodyPalace;
  final List<int> palacePositions, palaceStems;
  Map<String, Object> toJson() => {
    'bureau': bureau.index,
    'ziwei': ziwei,
    'tianfu': tianfu,
    'bodyPalace': bodyPalace,
    'palacePositions': palacePositions,
    'palaceStems': palaceStems,
  };
}

List<int> computePalaceStems(int yearGanIndex) {
  _checked(yearGanIndex, 0, 9, 'yearGanIndex');
  final yin = yearGanIndex % 5 * 2 + 2;
  final result = List<int>.filled(12, 0);
  for (var i = 0; i < 12; i++) {
    result[(2 + i) % 12] = (yin + i) % 10;
  }
  return List.unmodifiable(result);
}

PlacementAnchors computePlacementAnchors(
  ZiweiPlacementInput input, {
  ZiweiChartMode chartMode = ZiweiChartMode.tianPan,
  Bureau? retainedBureau,
}) {
  final original = (1 + input.month - input.hourZhiIndex) % 12;
  final body = (1 + input.month + input.hourZhiIndex) % 12;
  final life = switch (chartMode) {
    ZiweiChartMode.tianPan => original,
    ZiweiChartMode.diPan => body,
    ZiweiChartMode.renPan => (original + 2) % 12,
  };
  final stems = computePalaceStems(input.yearGanIndex);
  final bureau =
      retainedBureau ??
      [
        Bureau.metal4,
        Bureau.water2,
        Bureau.fire6,
        Bureau.earth5,
        Bureau.wood3,
      ][(stems[life] ~/ 2 + (life ~/ 2) % 3) % 5];
  final add = (bureau.number - input.day % bureau.number) % bureau.number;
  final ziwei =
      ((input.day + add) ~/ bureau.number + (add.isOdd ? -add : add) + 1) % 12;
  return PlacementAnchors(
    bureau,
    ziwei,
    body,
    List.generate(12, (p) => (life - p) % 12),
    stems,
  );
}

class OmittedPlacement {
  OmittedPlacement(this.starId, Iterable<String> inputs)
    : missingInputs = List.unmodifiable(inputs);
  final int starId;
  final List<String> missingInputs;
  Map<String, Object> toJson() => {
    'starId': starId,
    'missingInputs': missingInputs,
  };
}

class ZiweiPlacement {
  ZiweiPlacement(
    this.input,
    this.anchors,
    List<int> positions,
    Map<String, int> transformations,
    List<OmittedPlacement> omitted, {
    List<StarInfo>? catalog,
  }) : starCatalog = List.unmodifiable(catalog ?? starCatalogDefault),
       starPositions = List.unmodifiable(positions),
       yearTransformations = Map.unmodifiable(transformations),
       omittedPlacements = List.unmodifiable(omitted);
  final ZiweiPlacementInput input;
  final List<StarInfo> starCatalog;
  final PlacementAnchors anchors;

  /// -1 means unplaced (including flow stars in a natal arrangement).
  final List<int> starPositions;
  final Map<String, int> yearTransformations;
  final List<OmittedPlacement> omittedPlacements;
  Map<String, Object> toJson() => {
    'input': input.toJson(),
    ...anchors.toJson(),
    'starCatalog': starCatalog.map((s) => s.toJson()).toList(),
    'starPositions': starPositions,
    'yearTransformations': yearTransformations,
    'omittedPlacements': omittedPlacements.map((p) => p.toJson()).toList(),
  };
}

int? _kong(int gan, int zhi, bool secondary) {
  if (gan % 2 != zhi % 2) return null;
  final cycle = List.generate(
    60,
    (i) => i,
  ).firstWhere((i) => i % 10 == gan && i % 12 == zhi);
  final first = (10 - cycle ~/ 10 * 2) % 12, second = (first + 1) % 12;
  final firstMain = first % 2 == gan % 2;
  return secondary
      ? (firstMain ? second : first)
      : (firstMain ? first : second);
}

/// Pure arrangement with selected rules (option1 by default). Does not invent a birthday,
/// day Ganzhi, physical instant, or age information for manual inputs.
ZiweiPlacement arrangeZiweiStars(
  ZiweiPlacementInput input, {
  required ZiweiGender gender,
  ZiweiChartMode chartMode = ZiweiChartMode.tianPan,
  Bureau? retainedBureau,
  ZiweiRuleSelection? rules,
}) {
  final anchors = computePlacementAnchors(
    input,
    chartMode: chartMode,
    retainedBureau: retainedBureau,
  );
  final values = <String, int?>{
    'anchor.bureau': anchors.bureau.index,
    'anchor.ziwei': anchors.ziwei,
    'anchor.tianfu': anchors.tianfu,
    'anchor.life': anchors.palacePositions[0],
    'anchor.body': anchors.bodyPalace,
    'birth.gender': gender.index,
  };
  for (final prefix in ['lunar', 'solar']) {
    values.addAll({
      '$prefix.year_stem': input.yearGanIndex,
      '$prefix.year_branch': input.yearZhiIndex,
      '$prefix.zheng_kong': _kong(
        input.yearGanIndex,
        input.yearZhiIndex,
        false,
      ),
      '$prefix.fu_kong': _kong(input.yearGanIndex, input.yearZhiIndex, true),
      '$prefix.month_stem': (input.yearGanIndex % 5 * 2 + 1 + input.month) % 10,
      '$prefix.month_branch': (input.month + 1) % 12,
      '$prefix.month_index': input.month - 1,
      '$prefix.day_index': input.day - 1,
      '$prefix.hour_branch': input.hourZhiIndex,
    });
  }
  return _arrange(input, anchors, values, rules ?? ZiweiRuleSelection());
}

ZiweiPlacement _arrange(
  ZiweiPlacementInput input,
  PlacementAnchors anchors,
  Map<String, int?> values,
  ZiweiRuleSelection selection, {
  int? sihuaGan,
}) {
  final rules = selectZiweiRules(selection);
  final positions = List<int>.filled(rules.catalog.length, -1);
  final omitted = <OmittedPlacement>[];
  for (final rule in rules.natalPlacements) {
    final missing = rule.inputs.where((key) => values[key] == null).toList();
    if (missing.isNotEmpty) {
      omitted.add(OmittedPlacement(rule.starId, missing));
      continue;
    }
    positions[rule.starId] = rule.evaluate((source) => values[source]);
  }
  return ZiweiPlacement(
    input,
    anchors,
    positions,
    rules.sihua[sihuaGan ?? input.yearGanIndex],
    omitted,
    catalog: rules.catalog,
  );
}
