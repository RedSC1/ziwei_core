# 配置文件说明 (Config File Guide)

引擎的所有核心规则都存储在 JSON 文件中。本文说明如何加载这些文件，以及每个文件的结构格式。各字段的**可选值**详见 [JSON 字段值速查手册](./07_json_value_reference.md)。

---

## 一、JSON 文件的两种加载方式

### 方式 A：内嵌为 Dart 字符串（推荐，适合打包发布）

将 JSON 内容预先编译为 Dart 的 `const String`，打包进库。好处是引用直接、零 IO 开销、适合 Flutter/纯 Dart 跨平台发布。

这也是本库默认规则集的工作方式（参见 `lib/src/config/default_jsons.dart`）。你可以使用 [编译工具](#三使用编译工具将-json-转为-dart-文件) 自动生成这个文件。

生成后，再传给 `ConfigLoader`：
```dart
// 你自己的 MyJsons 类（由 compile 工具生成）
final ruleset = ConfigLoader.createRuleset(
  starsJson: MyJsons.stars,
  sihuaJson: MyJsons.sihua,
  flowJson: MyJsons.flowStars,
  mainRulesJson: MyJsons.mainRules,
);
```

### 方式 B：运行时读取文件（适合服务端 / 需要热更新）

在服务端或需要动态加载规则的场景，可以直接从文件系统读取 JSON：

```dart
import 'dart:io';

final starsJson = await File('assets/config/my_rules/stars.json').readAsString();
final sihuaJson = await File('assets/config/my_rules/sihua.json').readAsString();
// ...

final ruleset = ConfigLoader.createRuleset(
  starsJson: starsJson,
  sihuaJson: sihuaJson,
  // ...
);
```

---

## 二、各配置文件格式说明

默认配置文件位于 `assets/config/default/` 下，共 6 个文件。

### 1. `stars.json` — 原局安星规则

JSON 数组，每项定义一颗星的安放逻辑。

```json
[
  {
    "key": "taiyang",
    "type": "major",
    "rule": {
      "type": "anchor_offset",
      "anchor": "ziwei",
      "offset": -3
    }
  }
]
```

`rule.type` 支持以下类型：

| 类型 | 说明 |
| :--- | :--- |
| `anchor_offset` | 以某颗锚点星为基准，顺/逆偏移若干宫 |
| `lookup` | 按年干/年支查表，直接定位到某宫 |
| `lookup_offset` | 查表后再叠加一个偏移量 |
| `constant` | 固定在某个宫位 |
| `pipeline` | 将多个规则串联执行（复合规则） |

`anchor` 的可选值举例：`ziwei`、`tianfu`、`year_stem`、`year_branch`、`hour`、`birth_month` 等。

---

### 2. `sihua.json` — 四化规则

按天干 → 四化类型 → 星曜 key 的嵌套结构：

```json
{
  "jia": { "lu": "lianzhen", "quan": "pojun", "ke": "wuqu",  "ji": "taiyang" },
  "yi":  { "lu": "tianji",   "quan": "tianliang", "ke": "ziwei", "ji": "taiyin" }
}
```

天干拼音：`jia/yi/bing/ding/wu/ji/geng/xin/ren/gui`  
四化类型：`lu/quan/ke/ji`  
值为星曜的 key（如 `ziwei`、`tianji`、`taiyang`...）

---

### 3. `brightness.json` — 星曜亮度

星曜 key → 12 宫亮度数组（索引 0 = 子宫，依次顺行至亥宫）：

```json
{
  "ziwei":   [2, 6, 6, 5, 4, 5, 6, 6, 5, 5, 4, 5],
  "taiyang": [0, 1, 5, 6, 5, 5, 5, 4, 4, 2, 1, 0]
}
```

亮度系统由两层组成，必须保持同步：

**第一层（这里）**：`brightness.json` 里的每个数字只是一个**整数键**，代表某种亮度等级。默认使用 `0`~`6` 和 `-1`，但这些值完全可以自定义。

**第二层**：`main_rules.json` 里的 `brightness_labels` 将上面的整数键映射为最终输出的 JSON 字段值（如 `"level_miao"`）。引擎在 Star 的 toJson 时会将数字替换为对应的标签字符串，`-1` 表示"无亮度标签"（不输出该字段）。

默认映射：`6`=`level_miao` `5`=`level_wang` `4`=`level_de` `3`=`level_li` `2`=`level_ping` `1`=`level_bu` `0`=`level_xian` `-1`=无

**自定义亮度等级示例**：如果你希望新增一个等级 `7`=极庙：

在 `brightness.json` 中使用 `7`：
```json
{ "ziwei": [7, 6, 6, 5, ...] }
```

在 `main_rules.json` 中声明对应标签：
```json
{
  "brightness_labels": {
    "7": "level_ji_miao",
    "6": "level_miao",
    ...
  }
}
```

> [!IMPORTANT]
> `brightness.json` 中用到的所有数字（除 `-1` 外）都必须在 `main_rules.json` 的 `brightness_labels` 中有对应定义，否则引擎会在加载时抛出 `FormatException`。


---

### 4. `flow_stars.json` — 流运星曜规则

限流盘叠加的动态星曜，格式与 `stars.json` 类似，多了独立的亮度表：

```json
[
  {
    "key": "flow_lucun",
    "rule": {
      "type": "lookup",
      "anchor": "year_stem",
      "table": {
        "jia": 2, "yi": 3, "bing": 5, "ding": 6, "wu": 5,
        "ji": 6, "geng": 8, "xin": 9, "ren": 11, "gui": 0
      }
    },
    "brightness": [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6]
  }
]
```

---

### 5. `main_rules.json` — 历法开关与亮度标签映射

```json
{
  "calendar": {
    "rat_hour_mode": "noSplit",
    "leap_month_strategy": "split",
    "wu_hu_dun_boundary": "lunar",
    "sihua_boundary": "lunar",
    "childhood_decade": "skip",
    "flowLimit_boundary": "lunar",
    "enable_historical": true
  },
  "brightness_labels": {
    "6": "level_miao",
    "5": "level_wang",
    "0": "level_xian",
    "-1": "level_none"
  }
}
```

**`calendar` 字段可用值：**

| 字段 | 类型 | 可用值 | 说明 |
| :--- | :--- | :--- | :--- |
| `rat_hour_mode` | `string` | `"noSplit"` / `"todayGan"` / `"tomorrowGan"` | 早晚子时配置模式 |
| `leap_month_strategy` | `string` | `"split"` / `"current"` / `"as_next"` | `split`=15日前后分属，`current`=全算上月，`as_next`=全算下月 |
| `wu_hu_dun_boundary` | `string` | `"lunar"` / `"solar"` | 五虎遁推宫干的历法基准 |
| `sihua_boundary` | `string` | `"lunar"` / `"solar"` | 生年四化的历法基准 |
| `childhood_decade` | `string` | `"skip"` / `"regular"` | `skip`=口诀跳跃派，`regular`=一年一格顺延派 |
| `flowLimit_boundary` | `string` | `"lunar"` / `"solar"` | 流月/流日的分界线 |
| `enable_historical` | `bool` | `true` / `false` | 是否开启历史历法保护 |

---

### 6. `masters.json` — 命主 / 身主起例（可选）

命主查命宫地支索引，身主查年地支索引。`boundary` 控制身主取农历年支还是节气年支。

```json
{
  "ming_zhu": {
    "table": { "0": "tanlang", "1": "jumen", ... }
  },
  "shen_zhu": {
    "boundary": "lunar",
    "table": { "0": "lingxing", "1": "tianxiang", ... }
  }
}
```

---

## 三、使用编译工具将 JSON 转为 Dart 文件

当你把修改好的 JSON 放到目录后，可以用编译工具将整个目录里的所有 JSON 文件一次性打包为单个 Dart 文件，以便在应用中直接引用：

```bash
# 默认用法（将 assets/config/default/ 编译为 lib/src/config/default_jsons.dart）
dart run tool/compile_jsons.dart

# 自定义用法（将你自己的 JSON 目录编译为自定义输出文件和类名）
dart run tool/compile_jsons.dart <输入目录> <输出文件路径> <Dart类名>
```

**示例：**
```bash
# 将 assets/config/my_rules/ 编译为 lib/my_ruleset.dart，生成 MyRuleset 类
dart run tool/compile_jsons.dart assets/config/my_rules lib/my_ruleset.dart MyRuleset
```

**参数说明：**
- `<输入目录>`: 存放 JSON 的文件夹。
- `<输出文件路径>`: 生成的 `.dart` 文件存放在哪里。
- `<Dart类名>`: 生成文件里的 **类名**。

**参数与生成的代码关系：**
若执行 `dart run tool/compile_jsons.dart assets/config/rules lib/my_config.dart MyStyle`：

生成的 `lib/my_config.dart` 内容：
```dart
class MyStyle {  // 这里就是你定义的 <Dart类名>
  static const String stars = r""" ... """; 
  // ...
}
```

> [!NOTE]
> 工具会自动将文件名转为驼峰命名作为字段名：
> `flow_stars.json` → `MyRuleset.flowStars`，`main_rules.json` → `MyRuleset.mainRules`，以此类推。
