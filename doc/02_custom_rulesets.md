# 自定义规则集 (Custom Rulesets)

引擎的所有排盘逻辑，包括星曜安放、四化映射、亮度规则、流运配置等，都由一个 **`ZiweiRuleset`** 对象来驱动。
`ConfigLoader` 类提供了三种方式来获取或构建你需要的规则集。

---

## 方式一：直接使用默认规则集

引擎内置了一份默认规则集，直接调用即可：

```dart
final ruleset = ConfigLoader.getDefault();
final plate = ZiweiEngine.calculate(birth, ruleset);
```
由于作者精力有限，里面的安星规则、星体亮度和四化可能不尽如人意，如果需要自定义部分规则，请参见[方式二](#方式二热补丁覆盖-最常用的自定义方式)。

---

## 方式二：热补丁覆盖 (最常用的自定义方式)

如果你只想改变某一小部分规则，例如调换某颗星的四化，或修改星体亮度，使用 `ConfigLoader.overrideWith()` 是最安全、最省力的方式。

**它的工作原理是"按需覆盖"**：你只传入你想改变的那部分 JSON，引擎会自动将其与默认规则集做深度合并，未传入的部分保持不变。

> [!WARNING]
> **构建完自定义 ruleset 后，必须把 `ruleset.calendarOptions` 同步传给 [ZiweiDate](./06_ziwei_date.md)**，否则日期解析和排盘引擎的历法配置会不一致，导致排出错误的盘且不报任何错误。
> ```dart
> final ruleset = ConfigLoader.overrideWith(...);
> // ✅ 正确：将 ruleset 的历法选项同步给 date
> final birth = ZiweiDate.fromSolar(dt, gender: gender, options: ruleset.calendarOptions);
> final plate = ZiweiEngine.calculate(birth, ruleset);
> ```

JSON 文件格式详见[配置文件说明](./03_config_file.md)。

### 示例 A：修改历法运行参数 (main_rules)

修改四化以节气为界，并开启早晚子时区分：

```dart
final myMainRules = '''
{
  "calendar": {
    "split_rat_hour": true,
    "sihua_boundary": "solar"
  }
}
''';

final ruleset = ConfigLoader.overrideWith(
  ConfigLoader.getDefault(),
  mainRulesJson: myMainRules,
);
```

`main_rules` 中可配置的历法开关：

| 键名 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `split_rat_hour` | bool | `false` | 是否区分早晚子时（13时辰制） |
| `leap_month_strategy` | string | `"split"` | 闰月处理：`split`/`current`/`as_next` |
| `wu_hu_dun_boundary`（实验性功能）| string | `"lunar"` | 五虎遁月干推算基准：`lunar`/`solar` |
| `sihua_boundary` | string | `"lunar"` | 四化飞星基准：`lunar`/`solar` |
| `flowLimit_boundary`（实验性功能） | string | `"lunar"` | 流月/流日边界：`lunar`(农历)/`solar`(节气) |
| `enable_historical` | bool | `true` | 是否启用历史历法 |

### 示例 B：修改四化规则 (sihua)

比如将"甲干"的化忌改为"廉贞"改为"破军"：

```dart
final mySihua = '''
{
  "jia": {
    "ji": "pojun"
  }
}
''';

final ruleset = ConfigLoader.overrideWith(
  ConfigLoader.getDefault(),
  sihuaJson: mySihua,
);
```

干名使用拼音（`jia/yi/bing/ding/wu/ji/geng/xin/ren/gui`），
四化类型使用 `lu/quan/ke/ji`，星曜用 key 字符串（如 `ziwei`, `tianji`, `taiyang` 等）。

### 示例 C：修改星曜亮度 (brightness)

仅覆盖紫微星的亮度表（按 12 宫地支顺序，子宫为第 0 位）：

```dart
final myBrightness = '''
{
  "ziwei": [6, 5, 6, 5, 4, 5, 6, 5, 5, 5, 4, 5]
}
''';

final ruleset = ConfigLoader.overrideWith(
  ConfigLoader.getDefault(),
  brightnessJson: myBrightness,
);
```

亮度数值含义：`6`=庙 `5`=旺 `4`=得 `3`=利 `2`=平 `1`=不/闲 `0`=陷 `-1`=无（不显示亮度）

---

## 方式三：从零全量构建 (高级)

如果你想完全摒弃内置规则，从头注入一整套自定义规则，使用 `ConfigLoader.createRuleset()`：

```dart
final ruleset = ConfigLoader.createRuleset(
  starsJson: myStarsJson,       // 必填：安星规则
  sihuaJson: mySihuaJson,       // 必填：四化规则
  flowJson: myFlowStarsJson,    // 必填：流运星曜规则
  mainRulesJson: myMainJson,    // 必填：历法开关
  brightnessJson: myBrightness, // 可选：亮度表
  mastersJson: myMastersJson,   // 可选：命主身主规则
);
```

> [!CAUTION]
> 这种方式要求提供完整且合法的 JSON，缺少任何必填字段都会抛出 `FormatException`。
> 建议先用方式二验证你的改动，再考虑是否需要全量替换。

---

## 复用规则集

`ZiweiRuleset` 是无状态的只读对象，可以在多次排盘之间直接复用，无需每次重建：

```dart
// 只初始化一次，反复使用
final ruleset = ConfigLoader.getDefault();

final plate1 = ZiweiEngine.calculate(birth1, ruleset);
final plate2 = ZiweiEngine.calculate(birth2, ruleset);
```
