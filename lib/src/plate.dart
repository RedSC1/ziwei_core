part of '../ziwei_core.dart';

class ZiweiPalaceState {
  ZiweiPalaceState(this.branch, this.stem, this.palaceId, List<int> starIds)
    : starIds = List.unmodifiable(starIds),
      starBitset = starIds.fold(BigInt.zero, (v, i) => v | (BigInt.one << i));
  final int branch, stem, palaceId;
  final List<int> starIds;
  final BigInt starBitset;
}

class ZiweiStarPlacement extends StarInfo {
  ZiweiStarPlacement(
    StarInfo info,
    this.branch,
    this.palaceId,
    this.brightness,
    this.transformMask,
  ) : super(info.id, info.key, info.category, info.natal);
  final int branch, palaceId, brightness, transformMask;
  @override
  Map<String, Object> toJson() => {
    ...super.toJson(),
    'branch': branch,
    'palaceId': palaceId,
    'brightness': brightness,
    'transformMask': transformMask,
  };
}

abstract class ZiweiPlate {
  PlacementAnchors get anchors;
  int get bodyPalace;
  List<int> get palaceStems;
  List<StarInfo> get starCatalog;
  List<int> get starPositions;
  SelectedZiweiRules get _rules;
  late final List<ZiweiPalaceState> palaces = List.unmodifiable(
    List.generate(
      12,
      (b) => ZiweiPalaceState(
        b,
        palaceStems[b],
        anchors.palacePositions.indexOf(b),
        starCatalog
            .where((s) => s.natal && starPositions[s.id] == b)
            .map((s) => s.id)
            .toList(),
      ),
    ),
  );
  Map<String, int> get _yearTransforms;
  late final List<int> transformationMasks = _buildMasks();
  List<int> _buildMasks() {
    final masks = List<int>.filled(starCatalog.length, 0);
    for (var k = 0; k < 4; k++) {
      masks[_yearTransforms[_transformKeys[k]]!] |= 1 << k;
    }
    for (var b = 0; b < 12; b++) {
      for (var k = 0; k < 4; k++) {
        final own = _rules.sihua[palaceStems[b]][_transformKeys[k]]!,
            other = _rules.sihua[palaceStems[(b + 6) % 12]][_transformKeys[k]]!;
        if (starPositions[own] == b) masks[own] |= 1 << (4 + k);
        if (starPositions[other] == b) masks[other] |= 1 << (8 + k);
      }
    }
    return List.unmodifiable(masks);
  }

  ZiweiPalaceState getPalace(int id) =>
      palaces[anchors.palacePositions[_checked(id, 0, 11, 'palaceId')]];
  StarInfo getStarInfo(int id) =>
      starCatalog[_checked(id, 0, starCatalog.length - 1, 'starId')];
  int? findStarId(String key) {
    for (final s in starCatalog) {
      if (s.key == key) return s.id;
    }
    return null;
  }

  ZiweiStarPlacement? getStarPosition(int id) {
    final s = getStarInfo(id), b = starPositions[id];
    return b < 0
        ? null
        : ZiweiStarPlacement(
            s,
            b,
            palaces[b].palaceId,
            brightnessAt(_rules, id, b),
            transformationMasks[id],
          );
  }

  List<ZiweiStarPlacement> getStarsAtBranch(int branch) => List.unmodifiable(
    palaces[_checked(branch, 0, 11, 'branch')].starIds.map(
      (id) => getStarPosition(id)!,
    ),
  );
  List<ZiweiStarPlacement> getStarsInPalace(int id) =>
      getStarsAtBranch(getPalace(id).branch);
  String? getBrightnessLabel(int value) {
    _checked(value, -1, 6, 'brightness');
    final label = _rules.brightnessLabels['$value'];
    return value == -1 || label == null || label.isEmpty ? null : label;
  }

  bool hasTransform(int starId, int mark) =>
      mark >= 0 &&
      mark < 12 &&
      starId >= 0 &&
      starId < transformationMasks.length &&
      (transformationMasks[starId] & (1 << mark)) != 0;
  List<Map<String, Object?>> _serializePalaces(String scope) => palaces
      .map(
        (p) => <String, Object?>{
          'branch': p.branch,
          'branchName': earthlyBranches[p.branch],
          'stem': p.stem,
          'stemName': heavenlyStems[p.stem],
          'palaceId': p.palaceId,
          'name': palaceNames[p.palaceId],
          'isBodyPalace': p.branch == bodyPalace,
          'starIds': p.starIds,
          'stars': getStarsAtBranch(p.branch)
              .map(
                (s) => {
                  ...s.toJson(),
                  'brightnessLabel': getBrightnessLabel(s.brightness),
                  'transformations': [
                    for (var i = 0; i < 3; i++)
                      for (var k = 0; k < 4; k++)
                        if (s.transformMask & (1 << (i * 4 + k)) != 0)
                          {
                            'scope': [scope, 'self', 'centripetal'][i],
                            'kind': _transformKeys[k],
                          },
                  ],
                },
              )
              .toList(),
        },
      )
      .toList();
}

const _transformKeys = ['lu', 'quan', 'ke', 'ji'];

class ZiweiModifyInput {
  ZiweiModifyInput({
    this.yearGanIndex,
    this.yearZhiIndex,
    this.month,
    this.day,
    this.hourZhiIndex,
    this.updateBureau,
  }) {
    for (final e in overrides.entries) {
      _checked(
        e.value,
        e.key == 'month' || e.key == 'day' ? 1 : 0,
        e.key == 'yearGanIndex'
            ? 9
            : e.key == 'month'
            ? 12
            : e.key == 'day'
            ? 30
            : 11,
        e.key,
      );
    }
  }
  final int? yearGanIndex, yearZhiIndex, month, day, hourZhiIndex;
  final bool? updateBureau;
  Map<String, int> get overrides => {
    'yearGanIndex': ?yearGanIndex,
    'yearZhiIndex': ?yearZhiIndex,
    'month': ?month,
    'day': ?day,
    'hourZhiIndex': ?hourZhiIndex,
  };
}

class ZiweiModification {
  ZiweiModification(
    Map<String, int> overrides,
    this.updateBureau,
    this.lifePalaceShift,
  ) : overrides = Map.unmodifiable(overrides);
  final Map<String, int> overrides;
  final bool updateBureau;
  final int lifePalaceShift;
  Map<String, Object> toJson() => {
    'overrides': overrides,
    'updateBureau': updateBureau,
    'lifePalaceShift': lifePalaceShift,
  };
  ZiweiModification modify(ZiweiModifyInput input) => ZiweiModification(
    {...overrides, ...input.overrides},
    input.updateBureau ?? updateBureau,
    lifePalaceShift,
  );
  ZiweiModification shift(int steps) => ZiweiModification(
    overrides,
    updateBureau,
    (lifePalaceShift + steps) % 12,
  );
}

ZiweiPlacementInput _input(Map<String, int> v) => ZiweiPlacementInput(
  yearGanIndex: v['yearGanIndex']!,
  yearZhiIndex: v['yearZhiIndex']!,
  month: v['month']!,
  day: v['day']!,
  hourZhiIndex: v['hourZhiIndex']!,
);

abstract final class Palace {
  static const life = 0,
      siblings = 1,
      spouse = 2,
      children = 3,
      wealth = 4,
      health = 5,
      travel = 6,
      friends = 7,
      career = 8,
      property = 9,
      fortune = 10,
      parents = 11;
}

abstract final class StarTransformMark {
  static const birthYearLu = 0,
      birthYearQuan = 1,
      birthYearKe = 2,
      birthYearJi = 3,
      centrifugalLu = 4,
      centrifugalQuan = 5,
      centrifugalKe = 6,
      centrifugalJi = 7,
      centripetalLu = 8,
      centripetalQuan = 9,
      centripetalKe = 10,
      centripetalJi = 11;
}

abstract final class Brightness {
  static const none = -1,
      xian = 0,
      bu = 1,
      ping = 2,
      li = 3,
      de = 4,
      wang = 5,
      miao = 6;
}
