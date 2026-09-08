part of '../ziwei_core.dart';

class ZiweiAnchors extends PlacementAnchors {
  ZiweiAnchors(PlacementAnchors a, this.solarTerm, this.lunar)
    : super(a.bureau, a.ziwei, a.bodyPalace, a.palacePositions, a.palaceStems);
  final FourPillars solarTerm, lunar;
  @override
  Map<String, Object> toJson() => {
    'solarTerm': solarTerm.toJson(),
    'lunar': lunar.toJson(),
    'bureau': bureau.index,
    'ziwei': ziwei,
    'tianfu': tianfu,
    'palacePositions': palacePositions,
  };
}

Map<String, int?> _birthValues(
  ResolvedZiweiBirth birth,
  PlacementAnchors anchors,
) {
  final values = <String, int?>{
    'anchor.bureau': anchors.bureau.index,
    'anchor.ziwei': anchors.ziwei,
    'anchor.tianfu': anchors.tianfu,
    'anchor.life': anchors.palacePositions[0],
    'anchor.body': birth.anchors.bodyPalace,
    'birth.gender': birth.options.gender.index,
  };
  for (final prefix in ['lunar', 'solar']) {
    final p = prefix == 'lunar' ? birth.lunarPillars : birth.solarTermPillars;
    for (final e in p.toJson().entries) {
      values['$prefix.${e.key}_stem'] = ganzhiStem(e.value);
      values['$prefix.${e.key}_branch'] = ganzhiBranch(e.value);
    }
    values['$prefix.zheng_kong'] = _kong(
      ganzhiStem(p.year),
      ganzhiBranch(p.year),
      false,
    );
    values['$prefix.fu_kong'] = _kong(
      ganzhiStem(p.year),
      ganzhiBranch(p.year),
      true,
    );
    values['$prefix.month_index'] = prefix == 'lunar'
        ? birth.effectiveLunarMonth - 1
        : (ganzhiBranch(p.month) + 10) % 12;
    values['$prefix.day_index'] = prefix == 'lunar'
        ? birth.lunarDate.day - 1
        : birth.solarDayFromPreviousJie - 1;
  }
  return values;
}

ZiweiPlacement _modifiedPlacement(
  ZiweiPlacementInput original,
  ZiweiOptions options,
  Map<String, int> changes, {
  ResolvedZiweiBirth? birth,
  Bureau? retainedBureau,
  int? fixedLife,
  int? fixedBody,
}) {
  final input = _input({...original.toJson(), ...changes});
  int yearFor(PillarBoundary b) => b == PillarBoundary.lunar
      ? birth!.lunarPillars.year
      : birth!.solarTermPillars.year;
  final gan =
      changes['yearGanIndex'] ??
      (birth == null
          ? input.yearGanIndex
          : ganzhiStem(yearFor(options.wuHuDunYearBoundary)));
  final anchors = computePlacementAnchors(
    _input({...input.toJson(), 'yearGanIndex': gan}),
    chartMode: options.chartMode,
    retainedBureau: retainedBureau,
  );
  final values = birth == null
      ? <String, int?>{}
      : _birthValues(birth, birth.anchors);
  values.addAll({
    'anchor.bureau': anchors.bureau.index,
    'anchor.ziwei': anchors.ziwei,
    'anchor.tianfu': anchors.tianfu,
    'anchor.life':
        fixedLife ??
        birth?.anchors.palacePositions[0] ??
        anchors.palacePositions[0],
    'anchor.body': fixedBody ?? birth?.anchors.bodyPalace ?? anchors.bodyPalace,
    'birth.gender': options.gender.index,
  });
  for (final prefix in ['lunar', 'solar']) {
    final pillars = birth == null
        ? null
        : prefix == 'lunar'
        ? birth.lunarPillars
        : birth.solarTermPillars;
    final g =
        changes['yearGanIndex'] ??
        (pillars == null ? input.yearGanIndex : ganzhiStem(pillars.year));
    final z =
        changes['yearZhiIndex'] ??
        (pillars == null ? input.yearZhiIndex : ganzhiBranch(pillars.year));
    values.addAll({
      '$prefix.year_stem': g,
      '$prefix.year_branch': z,
      '$prefix.zheng_kong': _kong(g, z, false),
      '$prefix.fu_kong': _kong(g, z, true),
    });
    final m =
        changes['month'] ??
        (prefix == 'solar' && pillars != null
            ? (ganzhiBranch(pillars.month) + 10) % 12 + 1
            : input.month);
    if (birth == null ||
        changes.containsKey('month') ||
        changes.containsKey('yearGanIndex')) {
      values.addAll({
        '$prefix.month_stem': (g % 5 * 2 + 1 + m) % 10,
        '$prefix.month_branch': (m + 1) % 12,
        '$prefix.month_index': m - 1,
      });
    }
    if (birth == null || changes.containsKey('day')) {
      values['$prefix.day_index'] = input.day - 1;
    }
    if (birth == null || changes.containsKey('hourZhiIndex')) {
      values['$prefix.hour_branch'] = input.hourZhiIndex;
      values['$prefix.hour_stem'] = pillars == null
          ? null
          : (ganzhiStem(pillars.day) % 5 * 2 + input.hourZhiIndex) % 10;
    }
  }
  return _arrange(
    input,
    anchors,
    values,
    options.rules,
    sihuaGan:
        changes['yearGanIndex'] ??
        (birth == null
            ? input.yearGanIndex
            : ganzhiStem(yearFor(options.sihuaYearBoundary))),
  );
}

class ZiweiChart extends ZiweiPlate {
  ZiweiChart._(
    this.facts, {
    this.lunarInput,
    ZiweiChart? original,
    this.modification,
    ZiweiChart? preserved,
  }) : _original = original {
    options = facts.options;
    _rules = selectZiweiRules(options.rules);
    starCatalog = _rules.catalog;
    final base = facts.anchors;
    final initial = ZiweiPlacementInput(
      yearGanIndex: ganzhiStem(facts.lunarPillars.year),
      yearZhiIndex: ganzhiBranch(facts.lunarPillars.year),
      month: facts.effectiveLunarMonth,
      day: facts.lunarDate.day,
      hourZhiIndex: ganzhiBranch(facts.lunarPillars.hour),
    );
    final placement = original == null || preserved != null
        ? null
        : _modifiedPlacement(
            initial,
            options,
            modification!.overrides,
            birth: facts,
            retainedBureau: modification!.updateBureau ? null : base.bureau,
          );
    placementInput = preserved?.placementInput ?? placement?.input ?? initial;
    omittedPlacements =
        preserved?.omittedPlacements ??
        placement?.omittedPlacements ??
        const [];
    final selected = preserved?.anchors ?? placement?.anchors ?? base;
    final shifted = PlacementAnchors(
      selected.bureau,
      selected.ziwei,
      base.bodyPalace,
      base.palacePositions
          .map((b) => (b + (modification?.lifePalaceShift ?? 0)) % 12)
          .toList(),
      base.palaceStems,
    );
    anchors = ZiweiAnchors(shifted, facts.solarTermPillars, facts.lunarPillars);
    bodyPalace = base.bodyPalace;
    palaceStems = computePalaceStems(
      ganzhiStem(
        options.wuHuDunYearBoundary == PillarBoundary.lunar
            ? anchors.lunar.year
            : anchors.solarTerm.year,
      ),
    );
    if (preserved != null) {
      starPositions = preserved.starPositions;
    } else if (placement != null) {
      starPositions = placement.starPositions;
    } else {
      final values = _birthValues(facts, anchors),
          positions = List<int>.filled(starCatalog.length, -1);
      for (final rule in _rules.natalPlacements) {
        positions[rule.starId] = rule.evaluate((s) => values[s]);
      }
      starPositions = List.unmodifiable(positions);
    }
    birthYearTransformations =
        preserved?.birthYearTransformations ??
        placement?.yearTransformations ??
        _rules.sihua[ganzhiStem(
          options.sihuaYearBoundary == PillarBoundary.lunar
              ? anchors.lunar.year
              : anchors.solarTerm.year,
        )];
    int master(String kind) {
      final m = _rules.masters[kind];
      final branch = switch (m['input']) {
        'anchor.life' => anchors.palacePositions[0],
        'lunar.year_branch' => ganzhiBranch(anchors.lunar.year),
        'solar.year_branch' => ganzhiBranch(anchors.solarTerm.year),
        _ => ganzhiBranch(
          options.bodyMasterYearBoundary == PillarBoundary.lunar
              ? anchors.lunar.year
              : anchors.solarTerm.year,
        ),
      };
      return m['stars'][branch];
    }

    lifeMaster = original?.lifeMaster ?? master('life');
    bodyMaster = original?.bodyMaster ?? master('body');
  }
  factory ZiweiChart.fromZonedTime(ZonedTime birth, ZiweiOptions options) =>
      ZiweiChart._(resolveZiweiBirth(birth, options));
  factory ZiweiChart.fromLunar(
    LunarDate lunar,
    ZiweiOptions options, {
    int hour = 0,
    int minute = 0,
    double second = 0,
  }) {
    final solar = lunarToSolar(lunar, options: options.calendarOptions);
    final clock = ZonedTime(
      year: solar.year,
      month: solar.month,
      day: solar.day,
      hour: hour,
      minute: minute,
      second: second,
      offsetMinutes: options.utcOffsetMinutes.toInt(),
    );
    return ZiweiChart._(
      resolveZiweiBirth(clock, options),
      lunarInput: _freeze({
        ...lunar.toJson(),
        'hour': hour,
        'minute': minute,
        'second': second,
      }),
    );
  }
  factory ZiweiChart.fromResolvedBirth(ResolvedZiweiBirth birth) =>
      ZiweiChart._(birth);
  final ResolvedZiweiBirth facts;
  final Map<String, dynamic>? lunarInput;
  final ZiweiChart? _original;
  final ZiweiModification? modification;
  ZonedTime? get birthClockTime => facts.clockTime;
  @override
  late final ZiweiAnchors anchors;
  late final ZiweiOptions options;
  @override
  late final int bodyPalace;
  late final int lifeMaster, bodyMaster;
  @override
  late final List<int> palaceStems, starPositions;
  @override
  late final List<StarInfo> starCatalog;
  @override
  late final SelectedZiweiRules _rules;
  late final Map<String, int> birthYearTransformations;
  @override
  Map<String, int> get _yearTransforms => birthYearTransformations;
  late final ZiweiPlacementInput placementInput;
  late final List<OmittedPlacement> omittedPlacements;
  ZiweiChart modify(ZiweiModifyInput input) {
    final original = _original ?? this;
    final m = (modification ?? ZiweiModification({}, false, 0)).modify(input);
    return ZiweiChart._(
      original.facts,
      lunarInput: original.lunarInput,
      original: original,
      modification: m,
    );
  }

  ZiweiChart shiftLifePalace(int steps) {
    final original = _original ?? this;
    return ZiweiChart._(
      original.facts,
      lunarInput: original.lunarInput,
      original: original,
      modification: (modification ?? ZiweiModification({}, false, 0)).shift(
        steps,
      ),
      preserved: this,
    );
  }

  ZiweiChart reset() => _original ?? this;
  ZiweiChart resetModification() => reset();
  ZiweiTimelineProvider timeline() => ZiweiTimelineProvider(this);
  ZiweiLimitManager createLimitManager() => ZiweiLimitManager(this);
  ResolvedZiweiFlow resolveFlow(ZonedTime target) =>
      resolveZiweiFlow(this, target);
  ZiweiDynamicChart dynamicForTime(
    ZonedTime target, {
    FlowLevel deepestLevel = FlowLevel.hour,
  }) => dynamicChartForTime(this, target, deepestLevel: deepestLevel).chart;
  Map<String, Object?> toJson() => {
    'schemaVersion': 'ziwei-chart-v1',
    'kind': 'ziwei',
    'scope': 'natal',
    'birth': {
      'calendar': 'julian-gregorian-1582',
      'yearNumbering': 'astronomical',
      'jdUT1': facts.jdUT1,
      'clockTime': birthClockTime?.toJson(),
      'virtualTime': facts.virtualTime.toJson(),
      'clockMode': [
        'civil',
        'mean-solar',
        'true-solar',
      ][options.clockMode.index],
      'longitudeDeg': options.longitudeDeg,
      'gender': options.gender.name,
      'lunarInput': lunarInput,
      'logicalLunarDate': _lunarJson(facts.lunarDate),
    },
    'modification': modification?.toJson(),
    'placementInput': placementInput.toJson(),
    'omittedPlacements': omittedPlacements.map((v) => v.toJson()).toList(),
    'facts': _factsJson(facts),
    'anchors': anchors.toJson(),
    'bodyPalace': bodyPalace,
    'lifeMaster': lifeMaster,
    'bodyMaster': bodyMaster,
    'palaceStems': palaceStems,
    'starCatalog': starCatalog.map((s) => s.toJson()).toList(),
    'starPositions': starPositions,
    'birthYearTransformations': birthYearTransformations,
    'transformationMasks': transformationMasks,
    'brightnessLabels': _rules.brightnessLabels,
    'palaces': _serializePalaces('birthYear'),
    'options': options.toJson(),
  };
}

Map<String, Object> _lunarJson(LunarCalendarDate v) => {
  'year': v.year,
  'historicalYear': v.historicalYear,
  'month': v.month,
  'day': v.day,
  'isLeap': v.isLeap,
  'monthName': v.monthName.index,
};
Map<String, Object> _factsJson(ResolvedZiweiBirth v) => {
  'jdUT1': v.jdUT1,
  'virtualTime': v.virtualTime.toJson(),
  'gender': v.options.gender.index,
  'lunarDate': _lunarJson(v.lunarDate),
  'solarTermPillars': v.solarTermPillars.toJson(),
  'lunarPillars': v.lunarPillars.toJson(),
  'effectiveLunarYear': v.effectiveLunarYear,
  'effectiveLunarMonth': v.effectiveLunarMonth,
  'solarDayFromPreviousJie': v.solarDayFromPreviousJie,
};
