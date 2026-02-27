# Custom Rulesets

All chart calculation logic within the engine—including star placements, SiHua (Four Transformers) mapping, brightness rules, and flowing limit configurations—is driven by a **`ZiweiRuleset`** object.
The `ConfigLoader` class provides three ways to fetch or build the ruleset you need.

---

## Method 1: Using the Default Ruleset Directly

The engine comes with a built-in default ruleset. You can invoke it directly:

```dart
final ruleset = ConfigLoader.getDefault();
final plate = ZiweiEngine.calculate(birth, ruleset);
```

Due to limited personal capacity, the star placement rules, brightness levels, and SiHua herein might not meet everyone's expectations. If you need to customize certain rules, please refer to [Method 2](#method-2-hot-patching-most-common-customization-method).

---

## Method 2: Hot Patching (Most Common Customization Method)

If you only want to change a small subset of the rules, such as swapping the SiHua trigger of a star, or tweaking a star's brightness, using `ConfigLoader.overrideWith()` is the safest and least demanding approach.

**Its working principle is "override on demand"**: You only pass in the portion of JSON you wish to change, and the engine automatically performs a deep merge with the default ruleset, leaving unpassed portions untouched.

> [!WARNING]
> **After building a custom ruleset, you MUST synchronously pass `ruleset.calendarOptions` to [ZiweiDate](./06_ziwei_date.md)**. Otherwise, the date parser and the calculation engine will have mismatched calendar configurations, resulting in wildly incorrect charts without throwing any errors.
> ```dart
> final ruleset = ConfigLoader.overrideWith(...);
> // ✅ CORRECT: Synchronize the ruleset's calendar options to the date
> final birth = ZiweiDate.fromSolar(dt, gender: gender, options: ruleset.calendarOptions);
> final plate = ZiweiEngine.calculate(birth, ruleset);
> ```

For detailed JSON file formats, see [Configuration File Explanation](./03_config_file.md).

### Example A: Modifying Calendar Run Parameters (main_rules)

Modify SiHua to be bounded by Solar Terms, and enable distinct Early/Late Zi hour processing:

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

Calendar toggles configurable in `main_rules`:

| Key Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `split_rat_hour` | bool | `false` | Distinguish Early/Late Zi Hour (13-hour format) |
| `leap_month_strategy` | string | `"split"` | Leap month processing: `split` / `current` / `as_next` |
| `wu_hu_dun_boundary` (Experimental) | string | `"lunar"` | Five-Tigers-Chasing-Month stem calculation baseline: `lunar` / `solar` |
| `sihua_boundary` | string | `"lunar"` | SiHua (Transformer) baseline bound: `lunar` / `solar` |
| `flowLimit_boundary` (Experimental) | string | `"lunar"` | Flow Month/Day boundary base: `lunar` / `solar` |
| `enable_historical` | bool | `true` | Enable historical calendar quirks |

### Example B: Modifying SiHua Rules (sihua)

For example, changing the "Jia" stem's "Ji" (忌 - Annoying) trigger from "Lian Zhen" to "Po Jun":

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

Stem names use pinyin (`jia/yi/bing/ding/wu/ji/geng/xin/ren/gui`).
SiHua types use `lu/quan/ke/ji` (`禄/权/科/忌`). Star assignments use the key string (e.g. `ziwei`, `tianji`, `taiyang`).

### Example C: Modifying Star Brightness (brightness)

Only override ZiWei Star's brightness table (ordered by the 12 branches, with Zi [子] at index 0):

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

Brightness value definitions: `6`=Miao `5`=Wang `4`=De `3`=Li `2`=Ping `1`=Bu `0`=Xian `-1`=None (Omit brightness rendering)

---

## Method 3: Constructing from Scratch (Advanced)

If you wish to completely discard the built-in rules and inject a full custom rule suite from scratch, use `ConfigLoader.createRuleset()`:

```dart
final ruleset = ConfigLoader.createRuleset(
  starsJson: myStarsJson,       // Required: Star placement rules
  sihuaJson: mySihuaJson,       // Required: SiHua rules
  flowJson: myFlowStarsJson,    // Required: Flow limit star rules
  mainRulesJson: myMainJson,    // Required: Calendar toggles
  brightnessJson: myBrightness, // Optional: Brightness table
  mastersJson: myMastersJson,   // Optional: Ming/Shen master rules
);
```

> [!CAUTION]
> This method demands providing completely valid JSON spanning everything. Missing any required fields will throw a `FormatException`.
> It is advised to test your changes using Method 2 first before considering a full replacement.

---

## Reusing Rulesets

`ZiweiRuleset` is a stateless read-only object. It can be directly reused across multiple chart calculations without being reconstructed:

```dart
// Initialize only once, reuse repeatedly
final ruleset = ConfigLoader.getDefault();

final plate1 = ZiweiEngine.calculate(birth1, ruleset);
final plate2 = ZiweiEngine.calculate(birth2, ruleset);
```
