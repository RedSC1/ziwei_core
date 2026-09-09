part of '../ziwei_core.dart';

const ziweiCastingSpaceSize = 259200;
ZiweiPlacementInput _inputFromIndex(int index) {
  _checked(index, 0, ziweiCastingSpaceSize - 1, 'index');
  final h = index % 12;
  index = index ~/ 12;
  final d = index % 30 + 1;
  index = index ~/ 30;
  final m = index % 12 + 1, y = index ~/ 12;
  return ZiweiPlacementInput(
    yearGanIndex: y % 10,
    yearZhiIndex: y % 12,
    month: m,
    day: d,
    hourZhiIndex: h,
  );
}

int _randomIndex(int Function() randomUint32) {
  const limit = (4294967296 ~/ ziweiCastingSpaceSize) * ziweiCastingSpaceSize;
  for (var attempt = 0; attempt < 128; attempt++) {
    final value = randomUint32();
    _checked(value, 0, 4294967295, 'randomUint32');
    if (value < limit) return value % ziweiCastingSpaceSize;
  }
  throw StateError('randomUint32 repeatedly returned rejected values');
}

int _imul(int a, int b) =>
    (BigInt.from(a) * BigInt.from(b)).toUnsigned(32).toInt();
int Function() _numberGenerator(String number) {
  var state = 0x811c9dc5;
  for (final c in 'ziwei-casting-number-v1:$number'.codeUnits) {
    state = _imul(state ^ c, 0x01000193);
  }
  return () {
    state = (state + 0x6d2b79f5) & 0xffffffff;
    var value = _imul(state ^ (state >>> 15), state | 1);
    value =
        (value ^
            ((value + _imul(value ^ (value >>> 7), value | 61)) & 0xffffffff)) &
        0xffffffff;
    return (value ^ (value >>> 14)) & 0xffffffff;
  };
}

String _normalizedNumber(Object value) {
  if (value is int && (value < 0 || value > 9007199254740991)) {
    throw RangeError('use BigInt or decimal string beyond safe integers');
  }
  final text = value.toString();
  if (value is! int && value is! BigInt && value is! String ||
      !RegExp(r'^\d+$').hasMatch(text)) {
    throw ArgumentError('expected non-negative integer or decimal digits');
  }
  return BigInt.parse(text).toString();
}

class ZiweiCastingChart extends ZiweiPlate {
  ZiweiCastingChart._(
    ZiweiPlacementInput input,
    this.options,
    Map<String, Object> source, {
    Bureau? bureau,
    ZiweiCastingChart? original,
    this.modification,
    ZiweiCastingChart? preserved,
  }) : _original = original,
       casting = Map.unmodifiable(source) {
    _rules = selectZiweiRules(options.rules);
    starCatalog = _rules.catalog;
    final p = preserved != null
        ? null
        : _modifiedPlacement(
            input,
            options,
            {},
            retainedBureau: original != null && !modification!.updateBureau
                ? original.anchors.bureau
                : bureau,
            fixedLife: original?.anchors.palacePositions[0],
            fixedBody: original?.bodyPalace,
          );
    placementInput = preserved?.placementInput ?? p!.input;
    omittedPlacements = preserved?.omittedPlacements ?? p!.omittedPlacements;
    final a = preserved?.anchors ?? p!.anchors;
    anchors = PlacementAnchors(
      a.bureau,
      a.ziwei,
      original?.bodyPalace ?? a.bodyPalace,
      original == null
          ? a.palacePositions
          : original.anchors.palacePositions
                .map((b) => (b + modification!.lifePalaceShift) % 12)
                .toList(),
      original?.palaceStems ?? a.palaceStems,
    );
    bodyPalace = original?.bodyPalace ?? a.bodyPalace;
    palaceStems = original?.palaceStems ?? a.palaceStems;
    starPositions = preserved?.starPositions ?? p!.starPositions;
    yearTransformations =
        preserved?.yearTransformations ?? p!.yearTransformations;
    int master(String kind) {
      final m = _rules.masters[kind];
      return m['stars'][m['input'] == 'anchor.life'
          ? anchors.palacePositions[0]
          : placementInput.yearZhiIndex];
    }

    lifeMaster = original?.lifeMaster ?? master('life');
    bodyMaster = original?.bodyMaster ?? master('body');
  }
  factory ZiweiCastingChart.fromInput(
    ZiweiPlacementInput input,
    ZiweiOptions options, {
    Bureau? bureau,
  }) =>
      ZiweiCastingChart._(input, options, {'method': 'manual'}, bureau: bureau);
  factory ZiweiCastingChart.fromIndex(int index, ZiweiOptions options) =>
      ZiweiCastingChart._(_inputFromIndex(index), options, {
        'method': 'index',
        'index': index,
        'algorithm': 'index-v1',
      });
  factory ZiweiCastingChart.fromNumber(Object value, ZiweiOptions options) {
    final number = _normalizedNumber(value),
        index = _randomIndex(_numberGenerator(number));
    return ZiweiCastingChart._(_inputFromIndex(index), options, {
      'method': 'number',
      'number': number,
      'index': index,
      'algorithm': 'number-v1',
    });
  }
  factory ZiweiCastingChart.random(
    ZiweiOptions options, {
    int Function()? randomUint32,
  }) {
    final secure = randomUint32 == null ? math.Random.secure() : null;
    final index = _randomIndex(
      randomUint32 ??
          () => secure!.nextInt(65536) * 65536 + secure.nextInt(65536),
    );
    return ZiweiCastingChart._(_inputFromIndex(index), options, {
      'method': 'random',
      'index': index,
      'algorithm': 'index-v1',
    });
  }
  final ZiweiOptions options;
  final Map<String, Object> casting;
  final ZiweiCastingChart? _original;
  final ZiweiModification? modification;
  @override
  late final PlacementAnchors anchors;
  @override
  late final int bodyPalace;
  @override
  late final List<int> palaceStems, starPositions;
  @override
  late final List<StarInfo> starCatalog;
  @override
  late final SelectedZiweiRules _rules;
  late final Map<String, int> yearTransformations;
  @override
  Map<String, int> get _yearTransforms => yearTransformations;
  late final ZiweiPlacementInput placementInput;
  late final List<OmittedPlacement> omittedPlacements;
  late final int lifeMaster, bodyMaster;
  ZiweiCastingChart modify(ZiweiModifyInput input) {
    final original = _original ?? this,
        m = (modification ?? ZiweiModification({}, false, 0)).modify(input);
    return ZiweiCastingChart._(
      _input({...original.placementInput.toJson(), ...m.overrides}),
      options,
      original.casting,
      original: original,
      modification: m,
    );
  }

  ZiweiCastingChart shiftLifePalace(int steps) {
    final original = _original ?? this;
    return ZiweiCastingChart._(
      placementInput,
      options,
      original.casting,
      original: original,
      modification: (modification ?? ZiweiModification({}, false, 0)).shift(
        steps,
      ),
      preserved: this,
    );
  }

  ZiweiCastingChart reset() => _original ?? this;
  ZiweiCastingChart resetModification() => reset();
  Map<String, Object?> toJson() => {
    'schemaVersion': 'ziwei-casting-chart-v1',
    'kind': 'ziwei-casting',
    'casting': casting,
    'originalInput': (_original ?? this).placementInput.toJson(),
    'originalBureau': (_original ?? this).anchors.bureau.index,
    'placementInput': placementInput.toJson(),
    'modification': modification?.toJson(),
    'omittedPlacements': omittedPlacements.map((p) => p.toJson()).toList(),
    'anchors': {
      'bureau': anchors.bureau.index,
      'ziwei': anchors.ziwei,
      'tianfu': anchors.tianfu,
      'palacePositions': anchors.palacePositions,
    },
    'bodyPalace': bodyPalace,
    'lifeMaster': lifeMaster,
    'bodyMaster': bodyMaster,
    'palaceStems': palaceStems,
    'starCatalog': starCatalog.map((s) => s.toJson()).toList(),
    'starPositions': starPositions,
    'yearTransformations': yearTransformations,
    'transformationMasks': transformationMasks,
    'brightnessLabels': _rules.brightnessLabels,
    'palaces': _serializePalaces('year'),
    'options': options.toJson(),
  };
}
