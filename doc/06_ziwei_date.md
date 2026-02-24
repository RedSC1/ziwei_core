# ZiweiDate 详细说明

`ZiweiDate` 是整个排盘引擎的**时间输入层**，它在构造时就会自动完成农历转换、八字推算、节气定位、真太阳时修正等全套计算。

---

## 三种构造方式

### `ZiweiDate.fromSolar` — 阳历输入（最常用）

```dart
final date = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 14, 30, 0),
  gender: Gender.female,
);
```

| 参数 | 类型 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `dt`（位置参数） | `AstroDateTime` 或 `DateTime` | 必填 | 出生的阳历时间。`DateTime` 不支持公元前，历史命盘必须用 `AstroDateTime`。 |
| `gender` | `Gender` | `Gender.male` | 性别，影响大限顺逆。 |
| `options` | `CalendarOptions?` | 规则集默认值 | 历法开关。**如果你使用了自定义 `ZiweiRuleset`，必须将 `ruleset.calendarOptions` 传入此处，否则排的是不一致的盘**（见下文说明）。 |
| `location` | `Location?` | `(120E, 30N)` | 真太阳时地理基准点（见下文）。 |
| `timeZone` | `double` | `8.0` | 输入时间所在时区（UTC 偏移小时数）。 |

> [!WARNING]
> **`options` 与 `ruleset.calendarOptions` 必须保持一致。**
>
> 部分历法选项（如 `splitRatHour`）会影响 `ZiweiDate` **在构造时**对时间的解析（影响 `bazi`、`lunar` 等字段），必须在排盘之前确定下来。引擎在排盘时读取的是 `date.options`，而非 `ruleset.calendarOptions`。因此，如果你使用了自定义规则集，正确做法是：
>
> ```dart
> // ✅ 正确：先建 ruleset，再将 calendarOptions 传给 date
> final ruleset = ConfigLoader.overrideWith(ConfigLoader.getDefault(), mainRulesJson: myMain);
> final date = ZiweiDate.fromSolar(dt, gender: Gender.female, options: ruleset.calendarOptions);
> final plate = ZiweiEngine.calculate(date, ruleset);
>
> // ⚠️ 危险：date 用了默认 options，ruleset 却改了 splitRatHour 或其他选项
> final date2 = ZiweiDate.fromSolar(dt, gender: Gender.female); // 遗漏 options
> final plate2 = ZiweiEngine.calculate(date2, ruleset); // 两者不一致！
> ```


---

### `ZiweiDate.fromLunar` — 农历输入

当你只知道农历生辰时使用。

```dart
final date = ZiweiDate.fromLunar(
  1990,   // 农历年
  4,      // 农历月（正月=1，腊月=12）
  26,     // 农历初几
  14,     // 小时（0-23，非时辰索引）
  30,     // 分
  0,      // 秒
  false,  // 是否为闰月
  gender: Gender.female,
);
```

> [!IMPORTANT]
> `hour` 参数是 **物理钟点小时（0–23）**，不是时辰索引。例如下午 2 点传 `14`，引擎会自动换算成未时（地支索引 7）。

---

### `ZiweiDate.fromStringLunar` — 中文月份字符串输入

适用于前端或数据库直接传入中文月份名称的场景，内置对颛顼古历 `"后九"` 等特殊月名的兼容。

```dart
final date = ZiweiDate.fromStringLunar(
  -209,    // 农历年（秦二世元年）
  "后九",   // 中文月份字符串
  15,      // 农历初几
  12,      // 小时（0-23）
  0, 0,    // 分、秒
  gender: Gender.male,
);
```

支持的月份字符串格式：`"正"` / `"一"` ~ `"十二"`, `"冬"`（=十一月）, `"腊"`（=十二月）, `"拾贰"`（=十二月）, `"闰X"`（闰月，如 `"闰五"`）, `"后九"`（颛顼历闰九月）, `"十三"`（古历十三月）。

`fromLunar` 内部最终也是调用 `fromStringLunar` 完成解析的，两者在计算结果上完全等价，只是输入格式不同。

---

## CalendarOptions 历法开关详解

`CalendarOptions` 控制引擎在推算命盘时对一些历法"争议地带"的裁定规则。绝大多数情况下，使用 `ConfigLoader.getDefault()` 里自带的配置即可。

> [!NOTE]
> 对于同一个人的生辰，不同的流派可能会选择不同的 `CalendarOptions`，导致命盘结果不同。这是正常现象，并非 bug。

| 字段 | 类型 | 默认 | 说明 |
| :--- | :--- | :--- | :--- |
| `splitRatHour` | `bool` | `false` | **是否区分早晚子时**。`true` 时：23:00~24:00 为晚子时（算作本日），00:00~01:00 为早子时（算作次日）。 |
| `leapRule` | `LeapMonthRule` | `splitAt15` | **闰月处理规则**：`splitAt15`（15日前算上月，15日后算下月）、`asPrevious`（全算上月）、`asNext`（全算下月）。 |
| `wuHuDunBasedOn` （实验性功能）| `Boundary` | `lunar` | **五虎遁推宫干的历法基准**：`lunar`（农历年干）或 `solar`（节气年干/八字年柱）。 |
| `siHuaBasedOn` | `Boundary` | `lunar` | **生年四化的历法基准**：`lunar`（农历年干）或 `solar`（节气年干）。立春前后出生的人，此选项会影响四化结果。 |
| `flowLimitBasedOn`（实验性功能） | `Boundary` | `lunar` | **流月/流日的分界线**：`lunar`（以农历初一为界）或 `solar`（以节气交节时刻为界）。 |
| `enableHistorical` | `bool` | `true` | **历史历法保护**。开启时，部分特殊历史时期的流月及以下层无法计算（详见[快速上手](./01_quick_start.md)）。 |

---

## Location 与真太阳时

紫微斗数中，时辰的判定历来有"平太阳时"和"真太阳时"两种流派。

- **真太阳时（默认）**：根据出生地经度修正与标准时区之间的时差，同时叠加均时差修正（太阳并非匀速运动，一年中最大偏差约 ±16 分钟）。在时辰边界附近出生的人，真太阳时可能导致时辰判定与钟表时间不同。
- **平太阳时**：直接使用钟表时间（标准时区时间），不做任何天文修正。设置 `useTrueSolarTime: false` 即可。

```dart
// 真太阳时（默认行为，传入出生地经纬度）
final date = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 23, 45, 0),
  gender: Gender.female,
  location: Location(longitude: 121.47, latitude: 31.23), // 上海
);

// 平太阳时（关闭真太阳时修正）
final date2 = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 23, 45, 0),
  gender: Gender.female,
  useTrueSolarTime: false,
);
```

> [!TIP]
> 如果不传 `location`，引擎默认使用 `(120E, 30N)` 作为基准点（与 UTC+8 基本重合），此时经度修正近乎为零，但均时差修正仍然生效。如果你希望完全不做任何修正，请设置 `useTrueSolarTime: false`。

---

## 序列化

```dart
final json = date.toJson();
// 输出包含 solar, lunar, bazi, location, gender, timeZone, options 的完整结构
```

---

## 常见踩坑

### 1. 立春后、春节前出生，四化/大限顺逆与预期不符
年干的界定方式（农历年还是节气年）由 `siHuaBasedOn` 和 `wuHuDunBasedOn` 控制。在立春之后、春节之前的这段时间里，节气年已经换到新年干支，但农历年仍在旧年干支，两者对"年干"的判定不同，会导致四化结果和大限顺逆完全不同。请明确选择流派后再设置对应的 `CalendarOptions`。

### 2. 晚上 11 点多出生，时辰可能不同于预期
默认不区分早晚子时（`splitRatHour: false`），子时统一算作当日。若你的流派区分早晚子时，需要设置 `splitRatHour: true`。

### 3. 闰月生辰排出的盘差异大
闰月的处理规则（`leapRule`）是最常见的流派争议点之一。默认以15日为分界，你可以根据所选流派调整。

### 4. 历史人物排盘注意事项

**公元前**：Dart 原生的 `DateTime` 最早只支持公元元年。如果需要推算历史人物，必须使用 `AstroDateTime`：
```dart
// 公元前 179 年（汉文帝）
final date = ZiweiDate.fromSolar(
  AstroDateTime(-179, 1, 1, 12, 0, 0),
  gender: Gender.male,
);
```

**1582 年以前**：这一年发生了格里高利历改革，公历从 10 月 4 日直接跳至 10 月 15 日（消失了 10 天）。`AstroDateTime` 内部使用 Meeus 算法，**已正确处理了这个切换**——1582-10-15 之前按儒略历计算，之后按格里高利历计算。因此使用 `AstroDateTime` 输入历史日期是准确的。

但 Dart 原生的 `DateTime` 使用的是"回推格里高利历"（Proleptic Gregorian），会把格里高利历规则无脑延伸到 1582 年之前，导致与实际儒略历产生偏差。**因此 1582 年之前的日期绝对不要用 `DateTime`**，必须用 `AstroDateTime` 或直接用 `fromLunar` 输入农历。

> [!TIP]
> 如果你手上的历史资料记载的是农历日期（大多数中国古代文献都是），直接用 `fromLunar` 输入最省事、最准确，无需关心公历体系的任何历法切换问题。
