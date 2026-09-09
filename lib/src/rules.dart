part of '../ziwei_core.dart';

const _stemKeys = [
  'jia',
  'yi',
  'bing',
  'ding',
  'wu',
  'ji',
  'geng',
  'xin',
  'ren',
  'gui',
];
const _branchKeys = [
  'zi',
  'chou',
  'yin',
  'mao',
  'chen',
  'si',
  'wu',
  'wei',
  'shen',
  'you',
  'xu',
  'hai',
];
const _longevity = {
  'changsheng',
  'muyu',
  'guandai',
  'linguan',
  'diwang',
  'shuai',
  'bing',
  'si',
  'mu',
  'jue',
  'tai',
  'yang',
};
const palaceNames = [
  '命宫',
  '兄弟',
  '夫妻',
  '子女',
  '财帛',
  '疾厄',
  '迁移',
  '交友',
  '官禄',
  '田宅',
  '福德',
  '父母',
];
const brightnessNames = ['陷', '不', '平', '利', '得', '旺', '庙'];
String? brightnessName(int value) =>
    value == -1 ? null : brightnessNames[_checked(value, 0, 6, 'brightness')];
int bureauNumber(Bureau bureau) => bureau.number;
int advanceBranch(int branch, int offset) => (branch + offset) % 12;
bool isForward(int stem, ZiweiGender gender) => stem % 2 == gender.index;
String _nonempty(String value) {
  if (value.trim().isEmpty) throw ArgumentError('empty key or label');
  return value;
}

dynamic _freeze(dynamic value) => value is Map
    ? Map<String, dynamic>.unmodifiable(
        value.map((k, v) => MapEntry(k.toString(), _freeze(v))),
      )
    : value is List
    ? List<dynamic>.unmodifiable(value.map(_freeze))
    : value;
Map<String, dynamic> _object(dynamic value) {
  if (value is! Map) throw ArgumentError('expected object');
  return Map<String, dynamic>.from(value);
}

class StarInfo {
  const StarInfo(this.id, this.key, this.category, this.natal);
  final int id;
  final String key, category;
  final bool natal;
  Map<String, Object> toJson() => {
    'id': id,
    'key': key,
    'category': category,
    'natal': natal,
  };
}

final List<StarInfo> starCatalogDefault = List.unmodifiable(
  (bundledRules['GENERATED_STARS'] as List).map(
    (s) => StarInfo(s['id'], s['key'], s['category'], s['natal']),
  ),
);
final int natalStarCount = bundledRules['GENERATED_NATAL_STAR_COUNT'] as int;
int get starCount => starCatalogDefault.length;
StarInfo getStar(int id) =>
    starCatalogDefault[_checked(id, 0, starCount - 1, 'starId')];
int? findStarId(String key) {
  for (final s in starCatalogDefault) {
    if (s.key == key) return s.id;
  }
  return null;
}

int requireStarId(String key) =>
    findStarId(key) ?? (throw ArgumentError('unknown star: $key'));

class ZiweiCompiledPlacement {
  ZiweiCompiledPlacement({
    required List<String> inputs,
    required List<int> shape,
    required List<int> positions,
    this.starId = -1,
  }) : inputs = List.unmodifiable(inputs),
       shape = List.unmodifiable(shape),
       positions = List.unmodifiable(positions) {
    if (inputs.length != shape.length ||
        shape.any((d) => d < 1) ||
        shape.fold(1, (int a, b) => a * b) != positions.length ||
        positions.any((p) => p < 0 || p > 11)) {
      throw ArgumentError('invalid placement table');
    }
  }
  factory ZiweiCompiledPlacement.fromJson(Map value, {int? starId}) {
    _checkKeys(value, ['inputs', 'shape', 'positions', 'starId'], 'placement');
    return ZiweiCompiledPlacement(
      inputs: (value['inputs'] as List).cast<String>(),
      shape: (value['shape'] as List).cast<int>(),
      positions: (value['positions'] as List).cast<int>(),
      starId: starId ?? value['starId'] ?? -1,
    );
  }
  final List<String> inputs;
  final List<int> shape, positions;
  final int starId;
  int evaluate(int? Function(String) read) {
    var index = 0;
    for (var i = 0; i < inputs.length; i++) {
      final v = read(inputs[i]);
      if (v == null) throw StateError('missing input ${inputs[i]}');
      index = index * shape[i] + _checked(v, 0, shape[i] - 1, inputs[i]);
    }
    return positions[index];
  }

  Map<String, Object> toJson() => {
    'inputs': inputs,
    'shape': shape,
    'positions': positions,
  };
}

const _flowInputs = {
  'anchor.bureau',
  'anchor.ziwei',
  'anchor.tianfu',
  'anchor.life',
  'anchor.body',
  'birth.gender',
  'lunar.year_stem',
  'solar.year_stem',
  'lunar.year_branch',
  'solar.year_branch',
};

class ZiweiRuleModule {
  ZiweiRuleModule({required String label, required Map<String, dynamic> patch})
    : label = _nonempty(label).trim(),
      patch = _normalizePatch(patch);
  final String label;
  final Map<String, dynamic> patch;
}

void _checkKeys(Map value, Iterable<String> allowed, String path) {
  for (final key in value.keys) {
    if (!allowed.contains(key)) {
      throw ArgumentError('unknown $path field: $key');
    }
  }
}

Map<String, dynamic> _normalizePatch(Map<String, dynamic> patch) {
  final result = _object(_canonicalNumbers(jsonDecode(jsonEncode(patch))));
  _checkKeys(result, [
    'stars',
    'natalPlacements',
    'flowPlacements',
    'brightness',
    'brightnessLabels',
    'sihua',
    'masters',
  ], 'rule patch');
  final seen = <String>{};
  for (final s in result['stars'] ?? []) {
    _checkKeys(_object(s), ['key', 'category', 'natal'], 'star');
    if (s['key'] is! String ||
        !seen.add(_nonempty(s['key'])) ||
        s['natal'] is! bool) {
      throw ArgumentError('invalid or duplicate star');
    }
    if (s['category'] != null) _nonempty(s['category']);
  }
  for (final name in ['natalPlacements', 'flowPlacements']) {
    for (final e in _object(result[name] ?? {}).entries) {
      _nonempty(e.key);
      final compiled = ZiweiCompiledPlacement.fromJson(_object(e.value));
      for (var i = 0; i < compiled.inputs.length; i++) {
        final input = compiled.inputs[i];
        if (compiled.shape[i] != _domain(input) ||
            (name == 'flowPlacements' && !_flowInputs.contains(input))) {
          throw ArgumentError('invalid $name input or domain: $input');
        }
      }
    }
  }
  for (final e in _object(result['brightness'] ?? {}).entries) {
    _nonempty(e.key);
    final v = e.value as List;
    if (v.length != 12 || v.any((n) => n is! int || n < -1 || n > 6)) {
      throw ArgumentError('invalid brightness');
    }
  }
  for (final e in _object(result['brightnessLabels'] ?? {}).entries) {
    final i = int.tryParse(e.key);
    if (i == null || i < -1 || i > 6 || e.value is! String) {
      throw ArgumentError('invalid brightness label');
    }
  }
  for (final e in _object(result['sihua'] ?? {}).entries) {
    if (!_stemKeys.contains(e.key) || _object(e.value).isEmpty) {
      throw ArgumentError('invalid sihua');
    }
    for (final entry in _object(e.value).entries) {
      if (!_transformKeys.contains(entry.key)) {
        throw ArgumentError('unknown sihua transformation: ${entry.key}');
      }
      _starReference(entry.value);
    }
  }
  final masterValues = _object(result['masters'] ?? {});
  _checkKeys(masterValues, ['life', 'body'], 'masters');
  for (final v in masterValues.values) {
    _checkKeys(_object(v), ['input', 'stars'], 'master lookup');
    if (![
          'anchor.life',
          'lunar.year_branch',
          'solar.year_branch',
          'master.year_branch',
        ].contains(v['input']) ||
        (v['stars'] as List).length != 12) {
      throw ArgumentError('invalid master');
    }
    for (final s in v['stars']) {
      _starReference(s);
    }
  }
  return _freeze(result) as Map<String, dynamic>;
}

void _starReference(dynamic s) {
  if (s is int && s >= 0) return;
  if (s is String && s.trim().isNotEmpty) return;
  throw ArgumentError('invalid star reference');
}

class ZiweiRuleset {
  ZiweiRuleset([List<ZiweiRuleModule> modules = const []])
    : modules = List.unmodifiable(modules) {
    if (modules.map((m) => m.label).toSet().length != modules.length) {
      throw ArgumentError('duplicate module label');
    }
  }
  final List<ZiweiRuleModule> modules;
  ZiweiRuleset withModule(ZiweiRuleModule module) =>
      ZiweiRuleset([...modules, module]);
}

class ZiweiRuleSelection {
  ZiweiRuleSelection({
    this.placementDefault = 'option1',
    this.brightnessDefault = 'option1',
    this.sihuaDefault = 'option1',
    this.masters = 'option1',
    this.longevity = 'option1',
    Map<String, String> placement = const {},
    Map<String, String> brightness = const {},
    Map<String, String> sihua = const {},
    ZiweiRuleset? ruleset,
  }) : placement = Map.unmodifiable(placement),
       brightness = Map.unmodifiable(brightness),
       sihua = Map.unmodifiable(sihua),
       ruleset = ruleset ?? ZiweiRuleset() {
    for (final s in [
      placementDefault,
      brightnessDefault,
      sihuaDefault,
      masters,
      longevity,
      ...placement.keys,
      ...placement.values,
      ...brightness.keys,
      ...brightness.values,
      ...sihua.keys,
      ...sihua.values,
    ]) {
      _nonempty(s);
    }
  }
  ZiweiRuleSelection copyWith({
    String? placementDefault,
    String? brightnessDefault,
    String? sihuaDefault,
    String? masters,
    String? longevity,
    Map<String, String> placement = const {},
    Map<String, String> brightness = const {},
    Map<String, String> sihua = const {},
    ZiweiRuleset? ruleset,
  }) => ZiweiRuleSelection(
    placementDefault: placementDefault ?? this.placementDefault,
    brightnessDefault: brightnessDefault ?? this.brightnessDefault,
    sihuaDefault: sihuaDefault ?? this.sihuaDefault,
    masters: masters ?? this.masters,
    longevity: longevity ?? this.longevity,
    placement: {...this.placement, ...placement},
    brightness: {...this.brightness, ...brightness},
    sihua: {...this.sihua, ...sihua},
    ruleset: ruleset ?? this.ruleset,
  );
  final String placementDefault,
      brightnessDefault,
      sihuaDefault,
      masters,
      longevity;
  final Map<String, String> placement, brightness, sihua;
  final ZiweiRuleset ruleset;
  Map<String, Object> toJson() => {
    'placementDefault': placementDefault,
    'brightnessDefault': brightnessDefault,
    'sihuaDefault': sihuaDefault,
    'masters': masters,
    'longevity': longevity,
    'placement': placement,
    'brightness': brightness,
    'sihua': sihua,
    'ruleset': {
      'modules': ruleset.modules
          .map((m) => {'label': m.label, 'patch': m.patch})
          .toList(),
    },
  };
}

class SelectedZiweiRules {
  SelectedZiweiRules(
    List<StarInfo> catalog,
    List<ZiweiCompiledPlacement> natal,
    List<ZiweiCompiledPlacement> flow,
    List<List<int>> brightness,
    List<Map<String, int>> sihua,
    Map<String, dynamic> masters,
    Map<String, String> labels,
  ) : catalog = List.unmodifiable(catalog),
      natalPlacements = List.unmodifiable(natal),
      flowPlacements = List.unmodifiable(flow),
      brightness = List.unmodifiable(
        brightness.map((v) => List<int>.unmodifiable(v)),
      ),
      sihua = List.unmodifiable(
        sihua.map((v) => Map<String, int>.unmodifiable(v)),
      ),
      masters = _freeze(masters),
      brightnessLabels = Map.unmodifiable(labels);
  final List<StarInfo> catalog;
  final List<ZiweiCompiledPlacement> natalPlacements, flowPlacements;
  final List<List<int>> brightness;
  final List<Map<String, int>> sihua;
  final Map<String, dynamic> masters;
  final Map<String, String> brightnessLabels;
}

final _ruleCache = Expando<SelectedZiweiRules>();
dynamic _option(Map variants, String option, String label) =>
    variants[option] ??
    (throw ArgumentError('unavailable $label option: $option'));
SelectedZiweiRules selectZiweiRules(ZiweiRuleSelection s) {
  final cached = _ruleCache[s];
  if (cached != null) return cached;
  final nv = bundledRules['GENERATED_PLACEMENT_VARIANTS'] as List,
      fv = bundledRules['GENERATED_FLOW_PLACEMENT_VARIANTS'] as List,
      bv = bundledRules['GENERATED_BRIGHTNESS_VARIANTS'] as List,
      sv = bundledRules['GENERATED_SIHUA_VARIANTS'] as List;
  void known(Map<String, String> overrides, Iterable keys) {
    for (final k in overrides.keys) {
      if (!keys.contains(k)) throw ArgumentError('unknown rule key: $k');
    }
  }

  known(s.placement, [...nv, ...fv].map((v) => v['starKey']));
  known(s.brightness, bv.map((v) => v['starKey']));
  known(s.sihua, _stemKeys);
  Map<int, ZiweiCompiledPlacement> placements(List variants, bool natal) => {
    for (final v in variants)
      v['starId'] as int: ZiweiCompiledPlacement.fromJson(
        _option(
          v['options'],
          natal && _longevity.contains(v['starKey'])
              ? s.longevity
              : s.placement[v['starKey']] ?? s.placementDefault,
          v['starKey'],
        ),
      ),
  };
  final natal = placements(nv, true),
      flow = placements(fv, false),
      catalog = [...starCatalogDefault];
  final brightness = bv
      .map(
        (v) =>
            (_option(
                      v['options'],
                      s.brightness[v['starKey']] ?? s.brightnessDefault,
                      v['starKey'],
                    )
                    as List)
                .cast<int>(),
      )
      .toList();
  final sihua = sv
      .map(
        (v) =>
            (_option(
                      v['options'],
                      s.sihua[v['stemKey']] ?? s.sihuaDefault,
                      v['stemKey'],
                    )
                    as Map)
                .cast<String, int>(),
      )
      .toList();
  var masters = _object(
    _option(
      bundledRules['GENERATED_MASTER_VARIANTS'] as Map,
      s.masters,
      'masters',
    ),
  );
  final ids = {for (final star in catalog) star.key: star.id};
  final labels = {
    '-1': '',
    for (var i = 0; i < 7; i++) '$i': brightnessNames[i],
  };
  int starId(dynamic ref) {
    final id = ref is int ? ref : ids[ref];
    if (id == null ||
        id < 0 ||
        id >= catalog.length ||
        ref is int && id >= starCount) {
      throw ArgumentError('unknown/unstable star reference: $ref');
    }
    return id;
  }

  for (final module in s.ruleset.modules) {
    final p = module.patch;
    for (final d in p['stars'] ?? []) {
      final existing = ids[d['key']];
      if (existing != null) {
        if (catalog[existing].natal != d['natal'] ||
            d['category'] != null &&
                catalog[existing].category != d['category']) {
          throw ArgumentError('cannot change star scope/category');
        }
        continue;
      }
      final id = catalog.length;
      catalog.add(
        StarInfo(
          id,
          d['key'],
          d['category'] ?? (d['natal'] ? 'custom' : 'other'),
          d['natal'],
        ),
      );
      ids[d['key']] = id;
      brightness.add(List.filled(12, -1));
    }
    for (final name in ['natalPlacements', 'flowPlacements']) {
      for (final e in _object(p[name] ?? {}).entries) {
        final id = starId(e.key);
        if (catalog[id].natal != (name == 'natalPlacements')) {
          throw ArgumentError('wrong star scope');
        }
        (name == 'natalPlacements' ? natal : flow)[id] =
            ZiweiCompiledPlacement.fromJson(e.value, starId: id);
      }
    }
    for (final e in _object(p['brightness'] ?? {}).entries) {
      brightness[starId(e.key)] = (e.value as List).cast<int>();
    }
    for (final e in _object(p['sihua'] ?? {}).entries) {
      final i = _stemKeys.indexOf(e.key);
      sihua[i] = {
        ...sihua[i],
        for (final v in _object(e.value).entries) v.key: starId(v.value),
      };
    }
    for (final e in _object(p['masters'] ?? {}).entries) {
      masters = {
        ...masters,
        e.key: {
          'input': e.value['input'],
          'stars': (e.value['stars'] as List).map(starId).toList(),
        },
      };
    }
    labels.addAll(_object(p['brightnessLabels'] ?? {}).cast<String, String>());
  }
  final n = natal.values.toList()..sort((a, b) => a.starId.compareTo(b.starId)),
      f = flow.values.toList()..sort((a, b) => a.starId.compareTo(b.starId));
  return _ruleCache[s] = SelectedZiweiRules(
    catalog,
    n,
    f,
    brightness,
    sihua,
    masters,
    labels,
  );
}

int brightnessAt(SelectedZiweiRules rules, int starId, int branch) =>
    rules.brightness[_checked(
      starId,
      0,
      rules.catalog.length - 1,
      'starId',
    )][_checked(branch, 0, 11, 'branch')];

String _source(String anchor, String boundary) => switch (anchor) {
  'ziwei' => 'anchor.ziwei',
  'tianfu' => 'anchor.tianfu',
  'ming' => 'anchor.life',
  'body' || 'shen' => 'anchor.body',
  'wuxingjv' => 'anchor.bureau',
  'month' => '$boundary.month_index',
  'day' || 'day_number' => '$boundary.day_index',
  'hour' => '$boundary.hour_branch',
  'year_stem' ||
  'year_branch' ||
  'month_stem' ||
  'month_branch' ||
  'zheng_kong' ||
  'fu_kong' => '$boundary.$anchor',
  _ => throw ArgumentError('unsupported anchor: $anchor'),
};
final Map<String, int> _inputDomains = {
  'anchor.bureau': 5,
  'anchor.ziwei': 12,
  'anchor.tianfu': 12,
  'anchor.life': 12,
  'anchor.body': 12,
  'birth.gender': 2,
  for (final prefix in ['lunar', 'solar']) ...{
    for (final pillar in ['year', 'month', 'day', 'hour']) ...{
      '$prefix.${pillar}_stem': 10,
      '$prefix.${pillar}_branch': 12,
    },
    '$prefix.zheng_kong': 12,
    '$prefix.fu_kong': 12,
    '$prefix.month_index': 12,
    '$prefix.day_index': prefix == 'solar' ? 33 : 30,
  },
};
int _domain(String s) =>
    _inputDomains[s] ??
    (throw ArgumentError('unsupported placement input: $s'));
String _lookupKey(String s, int v) => s.endsWith('_stem')
    ? _stemKeys[v]
    : s == 'anchor.bureau'
    ? ['water2', 'wood3', 'metal4', 'earth5', 'fire6'][v]
    : (s.endsWith('_branch') || s.startsWith('anchor.') || s.endsWith('_kong'))
    ? _branchKeys[v]
    : '$v';
ZiweiCompiledPlacement compileZiweiJsonPlacement(Object rule) {
  final inputs = <String>[];
  String boundary(Map r, String inherited) {
    final b = r['boundary'] ?? inherited;
    if (b != 'solar' && b != 'lunar') throw ArgumentError('invalid boundary');
    return b;
  }

  void add(String s) {
    if (!inputs.contains(s)) inputs.add(s);
  }

  void collect(Object raw, String inherited, int depth) {
    if (depth > 128) throw ArgumentError('rule nesting limit exceeded');
    final r = _object(raw), b = boundary(r, inherited);
    final fields = switch (r['type']) {
      'constant' => ['value'],
      'pipeline' => ['steps'],
      'anchor_offset' => ['anchor', 'offset', 'direction'],
      'lookup' => ['anchor', 'table', 'offset', 'direction'],
      'lookup_offset' => [
        'anchor',
        'table',
        'shift_anchor',
        'offset',
        'direction',
      ],
      _ => throw ArgumentError('unsupported rule type: ${r['type']}'),
    };
    _checkKeys(r, ['type', 'boundary', '_comment', ...fields], 'JSON rule');

    if (r['type'] == 'constant') return;
    if (r['type'] == 'pipeline') {
      for (final step in r['steps'] as List) {
        collect(step, b, depth + 1);
      }
      return;
    }
    final source = _source(r['anchor'], b);
    add(source);
    if (r['type'] == 'lookup' || r['type'] == 'lookup_offset') {
      _checkKeys(
        _object(r['table']),
        List.generate(_domain(source), (i) => _lookupKey(source, i)),
        "${r['type']}.table",
      );
    }
    if (r['type'] == 'lookup_offset') add(_source(r['shift_anchor'], b));
    if (r['direction'] == 'gender_shun_ni') {
      add('birth.gender');
      add('$b.year_stem');
    }
  }

  int integer(dynamic v, [int? fallback]) {
    final raw = v ?? fallback;
    final x = raw is double && raw.isFinite && raw == raw.truncateToDouble()
        ? raw.toInt()
        : raw;
    if (x is! int || x < -2147483648 || x > 2147483647) {
      throw ArgumentError('rule value must be int32');
    }
    return x;
  }

  int eval(Object raw, String inherited, Map<String, int> values, int depth) {
    if (depth > 128) throw ArgumentError('rule nesting limit exceeded');
    final r = _object(raw), b = boundary(r, inherited), type = r['type'];
    if (type == 'constant') return integer(r['value'], 0);
    if (type == 'pipeline') {
      var total = 0;
      for (final step in r['steps'] as List) {
        total = (total + eval(step, b, values, depth + 1)) % 12;
      }
      return total;
    }
    final source = _source(r['anchor'], b), v = values[source]!;
    final d = r['direction'];
    final dir = d == null || d == 1
        ? 1
        : d == -1 || d == 'ni'
        ? -1
        : d == 'gender_shun_ni'
        ? (values['$b.year_stem']! % 2 == values['birth.gender'] ? 1 : -1)
        : throw ArgumentError('invalid direction');
    final offset = integer(r['offset'], 0);
    if (type == 'anchor_offset') {
      return [
            'month',
            'day',
            'day_number',
            'hour',
            'year',
          ].contains(r['anchor'])
          ? offset + v * dir
          : v + offset * dir;
    }
    final table = _object(r['table']);
    final base = integer(table[_lookupKey(source, v)]);
    if (type == 'lookup') return base + offset * dir;
    if (type == 'lookup_offset') {
      return base + values[_source(r['shift_anchor'], b)]! * dir + offset;
    }
    throw ArgumentError('unsupported rule type: $type');
  }

  collect(rule, 'lunar', 0);
  final shape = inputs.map(_domain).toList();
  final count = shape.fold(1, (int a, b) => a * b);
  // Bound memory allocated from untrusted rule resources.
  if (count > 2000000) {
    throw ArgumentError('compiled rule exceeds two million cells');
  }
  final positions = List.generate(count, (flat) {
    var rem = flat;
    final values = <String, int>{};
    for (var i = shape.length - 1; i >= 0; i--) {
      values[inputs[i]] = rem % shape[i];
      rem = rem ~/ shape[i];
    }
    return eval(rule, 'lunar', values, 0) % 12;
  });
  return ZiweiCompiledPlacement(
    inputs: inputs,
    shape: shape,
    positions: positions,
  );
}

class ZiweiConfigLoader {
  static ZiweiRuleset getDefault() => ZiweiRuleset();
  static ZiweiRuleset withOptions(
    ZiweiRuleset base, {
    required String label,
    String? placementDefault,
    String? brightnessDefault,
    String? sihuaDefault,
    String? masters,
    String? longevity,
    Map<String, String> placement = const {},
    Map<String, String> brightness = const {},
    Map<String, String> sihua = const {},
  }) {
    final patch = <String, dynamic>{};
    Map<String, dynamic> compile(
      String category,
      String? fallback,
      Map<String, String> overrides, {
      bool natal = false,
    }) {
      final variants = bundledRules[category] as List,
          known = variants.map((v) => v['starKey']).toSet();
      for (final key in overrides.keys) {
        if (!known.contains(key)) throw ArgumentError('unknown rule key: $key');
      }
      final result = <String, dynamic>{};
      for (final v in variants) {
        final key = v['starKey'],
            option = natal && longevity != null && _longevity.contains(key)
                ? longevity
                : overrides[key] ?? fallback;
        if (option == null) continue;
        final value = _option(v['options'], option, key);
        result[key] = category.contains('PLACEMENT')
            ? ZiweiCompiledPlacement.fromJson(value).toJson()
            : value;
      }
      return result;
    }

    final nv = bundledRules['GENERATED_PLACEMENT_VARIANTS'] as List,
        fv = bundledRules['GENERATED_FLOW_PLACEMENT_VARIANTS'] as List;
    final nk = nv.map((v) => v['starKey']).toSet(),
        fk = fv.map((v) => v['starKey']).toSet();
    for (final key in placement.keys) {
      if (!nk.contains(key) && !fk.contains(key)) {
        throw ArgumentError('unknown rule key: $key');
      }
    }
    patch['natalPlacements'] = compile(
      'GENERATED_PLACEMENT_VARIANTS',
      placementDefault,
      {
        for (final e in placement.entries)
          if (nk.contains(e.key)) e.key: e.value,
      },
      natal: true,
    );
    patch['flowPlacements'] = compile(
      'GENERATED_FLOW_PLACEMENT_VARIANTS',
      placementDefault,
      {
        for (final e in placement.entries)
          if (fk.contains(e.key)) e.key: e.value,
      },
    );
    patch['brightness'] = compile(
      'GENERATED_BRIGHTNESS_VARIANTS',
      brightnessDefault,
      brightness,
    );
    final sets = <String, dynamic>{};
    for (final key in sihua.keys) {
      if (!_stemKeys.contains(key)) {
        throw ArgumentError('unknown sihua key: $key');
      }
    }
    for (final v in bundledRules['GENERATED_SIHUA_VARIANTS'] as List) {
      final key = v['stemKey'], option = sihua[key] ?? sihuaDefault;
      if (option != null) sets[key] = _option(v['options'], option, key);
    }
    patch['sihua'] = sets;
    if (masters != null) {
      patch['masters'] = _option(
        bundledRules['GENERATED_MASTER_VARIANTS'] as Map,
        masters,
        'masters',
      );
    }
    return base.withModule(ZiweiRuleModule(label: label, patch: patch));
  }

  static ZiweiRuleModule compileJson({
    required String label,
    String? starsJson,
    String? brightnessJson,
    String? sihuaJson,
    String? flowJson,
    String? mastersJson,
  }) {
    final stars = <Map<String, dynamic>>[],
        natal = <String, dynamic>{},
        flow = <String, dynamic>{},
        brightness = <String, dynamic>{},
        labels = <String, dynamic>{};
    void parseStars(String source, bool isNatal) {
      for (final raw in jsonDecode(source) as List) {
        final r = _object(raw);
        _checkKeys(r, [
          'key',
          'type',
          'category',
          'rule',
          '_comment',
          if (!isNatal) 'brightness',
        ], 'JSON ${isNatal ? 'natal' : 'flow'} star');
        final category = r['type'] ?? r['category'];
        stars.add({
          'key': r['key'],
          'natal': isNatal,
          if (category != null)
            'category':
                [
                  'cycle',
                  'boshi12',
                  'jiangqian12',
                  'suijian12',
                  'changsheng12',
                ].contains(category)
                ? 'cycle'
                : category == 'bad'
                ? 'malefic'
                : category,
        });
        final compiled = compileZiweiJsonPlacement(r['rule']);
        (isNatal ? natal : flow)[r['key']] = compiled.toJson();
        if (!isNatal && r.containsKey('brightness')) {
          brightness[r['key']] = (r['brightness'] as List)
              .map(_jsonNumber)
              .toList();
        }
      }
    }

    if (starsJson != null) parseStars(starsJson, true);
    if (flowJson != null) parseStars(flowJson, false);
    if (brightnessJson != null) {
      final r = _object(jsonDecode(brightnessJson));
      brightness.addAll(_numericBrightness(r['static_stars'] ?? {}));
      brightness.addAll(_numericBrightness(r['flow_stars'] ?? {}));
      for (final e in r.entries) {
        if (![
          '_comment',
          'static_stars',
          'flow_stars',
          'brightness_labels',
        ].contains(e.key)) {
          brightness[e.key] = (e.value as List).map(_jsonNumber).toList();
        }
      }
      final l = r['brightness_labels'];
      if (l is List) {
        for (var i = 0; i < l.length; i++) {
          labels['$i'] = '${l[i]}';
        }
      } else if (l != null) {
        labels.addAll(_object(l));
      }
    }
    final masters = <String, dynamic>{};
    if (mastersJson != null) {
      final r = _object(jsonDecode(mastersJson));
      _checkKeys(r, ['ming_zhu', 'shen_zhu', '_comment'], 'mastersJson');
      for (final key in ['ming_zhu', 'shen_zhu']) {
        if (r[key] == null) continue;
        final v = _object(r[key]);
        _checkKeys(v, ['boundary', 'table', '_comment'], 'master rule');
        _checkKeys(
          _object(v['table']),
          List.generate(12, (i) => '$i'),
          'master table',
        );
        if (v.containsKey('boundary') &&
            v['boundary'] != 'solar' &&
            v['boundary'] != 'lunar') {
          throw ArgumentError('master boundary must be lunar or solar');
        }
        masters[key == 'ming_zhu' ? 'life' : 'body'] = {
          'input': v['boundary'] == 'solar'
              ? 'solar.year_branch'
              : v['boundary'] == 'lunar'
              ? 'lunar.year_branch'
              : key == 'ming_zhu'
              ? 'anchor.life'
              : 'master.year_branch',
          'stars': List.generate(12, (i) => v['table']['$i']),
        };
      }
    }
    return ZiweiRuleModule(
      label: label,
      patch: {
        'stars': stars,
        'natalPlacements': natal,
        'flowPlacements': flow,
        'brightness': brightness,
        'brightnessLabels': labels,
        if (sihuaJson != null) 'sihua': jsonDecode(sihuaJson),
        if (masters.isNotEmpty) 'masters': masters,
      },
    );
  }

  static ZiweiRuleset overrideWith(
    ZiweiRuleset base, {
    required String label,
    String? starsJson,
    String? brightnessJson,
    String? sihuaJson,
    String? flowJson,
    String? mastersJson,
  }) => base.withModule(
    compileJson(
      label: label,
      starsJson: starsJson,
      brightnessJson: brightnessJson,
      sihuaJson: sihuaJson,
      flowJson: flowJson,
      mastersJson: mastersJson,
    ),
  );
}

int evaluatePlacementInputs(
  ZiweiCompiledPlacement rule,
  int? Function(String) read,
) => rule.evaluate(read);
int readNatalRuleInput(
  String source,
  ResolvedZiweiBirth facts,
  PlacementAnchors anchors,
  int bodyPalace,
) {
  final values = _birthValues(facts, anchors)..['anchor.body'] = bodyPalace;
  return values[source] ??
      (throw ArgumentError('unsupported natal rule input: $source'));
}

int evaluateNatalPlacement(
  ZiweiCompiledPlacement rule,
  ResolvedZiweiBirth facts,
  PlacementAnchors anchors,
  int bodyPalace,
) => rule.evaluate((s) => readNatalRuleInput(s, facts, anchors, bodyPalace));
int evaluateFlowPlacement(
  ZiweiCompiledPlacement rule,
  FlowCoordinate coordinate,
  ZiweiGender gender, {
  PlacementAnchors? anchors,
}) => rule.evaluate(
  (s) => switch (s) {
    'lunar.year_stem' || 'solar.year_stem' => coordinate.stem,
    'lunar.year_branch' || 'solar.year_branch' => coordinate.branch,
    'birth.gender' => gender.index,
    'anchor.bureau' => anchors?.bureau.index,
    'anchor.ziwei' => anchors?.ziwei,
    'anchor.tianfu' => anchors?.tianfu,
    'anchor.life' => anchors?.palacePositions[0],
    'anchor.body' => anchors?.bodyPalace,
    _ => null,
  },
);

// JavaScript JSON numbers have no int/double distinction. Preserve the same
// integral resource semantics without accepting fractional placement values.
dynamic _canonicalNumbers(dynamic value) {
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k, _canonicalNumbers(v)));
  }
  if (value is List) return value.map(_canonicalNumbers).toList();
  return value;
}

num _jsonNumber(dynamic value) {
  if (value == null) return 0;
  if (value is bool) return value ? 1 : 0;
  if (value is num) return value;
  if (value is String) {
    return value.trim().isEmpty ? 0 : num.parse(value.trim());
  }
  throw ArgumentError('brightness must be numeric');
}

Map<String, dynamic> _numericBrightness(dynamic raw) => _object(
  raw,
).map((k, v) => MapEntry(k, (v as List).map(_jsonNumber).toList()));
