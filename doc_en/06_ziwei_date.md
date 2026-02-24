# ZiweiDate Detailed Guide

`ZiweiDate` serves as the absolute **Time Input Layer** of the plotting engine. During its construction, it automatically completes a full suite of calculations including Lunar conversion, BaZi deduction, Solar Term positioning, and Apparent Solar Time fixes.

---

## Three Construction Methods

### `ZiweiDate.fromSolar` — Gregorian Input (Most Common)

```dart
final date = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 14, 30, 0),
  gender: Gender.female,
);
```

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dt` (Positional) | `AstroDateTime` or `DateTime` | Required | Gregorian birth time. `DateTime` does not support BC dates. Historical charts must utilize `AstroDateTime`. |
| `gender` | `Gender` | `Gender.male` | Gender, dictates whether Decade Limits flow clockwise or counter-clockwise. |
| `options` | `CalendarOptions?` | Ruleset default | Calendar Toggles. **If you use a customized `ZiweiRuleset`, you MUST pass `ruleset.calendarOptions` here, lest you plot inconsistent charts** (See warning below). |
| `location` | `Location?` | `(120E, 30N)` | Geographical reference point for Apparent Solar Time fixes. |
| `timeZone` | `double` | `8.0` | Target Time Zone offset (in hours). |

> [!WARNING]
> **`options` MUST match `ruleset.calendarOptions`.**
>
> Several calendar toggles (like `splitRatHour`) profoundly impact how `ZiweiDate` parses time **during its construction** (shifting `bazi`, `lunar`, etc.). These must be firmly set *before* calling the calculation engine. The engine reads `date.options` to plot the chart, not `ruleset.calendarOptions`. 
> Therefore, when dealing with custom rulesets, the correct approach is:
>
> ```dart
> // ✅ CORRECT: Build ruleset first, sync its calendarOptions into the date
> final ruleset = ConfigLoader.overrideWith(ConfigLoader.getDefault(), mainRulesJson: myMain);
> final date = ZiweiDate.fromSolar(dt, gender: Gender.female, options: ruleset.calendarOptions);
> final plate = ZiweiEngine.calculate(date, ruleset);
>
> // ⚠️ FATAL: The date utilized default options, but the ruleset toggled splitRatHour
> final date2 = ZiweiDate.fromSolar(dt, gender: Gender.female); // Forgot options synchronization
> final plate2 = ZiweiEngine.calculate(date2, ruleset); // Discrepancy explosion!
> ```

---

### `ZiweiDate.fromLunar` — Lunar Input

Utilized when solely Lunar birth details are known.

```dart
final date = ZiweiDate.fromLunar(
  1990,   // Lunar Year
  4,      // Lunar Month (1=Jan... 12=Dec)
  26,     // Lunar Day
  14,     // physical Hour (0-23, NOT stem/branch index)
  30,     // Minute
  0,      // Second
  false,  // Is Leap Month?
  gender: Gender.female,
);
```

> [!IMPORTANT]
> The `hour` parameter expects a **physical clock hour (0–23)**, NOT an Earthly Branch index. Feeding `14` (2 PM) triggers the engine to automatically compute it as a Wei [未] hour (Branch Index 7).

---

### `ZiweiDate.fromStringLunar` — String Lunar Month Input

Optimal for frontends or databases channeling raw Chinese Month strings, naturally housing backward compatibility for ancient calendar anomalies like the Zhuanxu calendar's "Latter 9th Month" (`"后九"`).

```dart
final date = ZiweiDate.fromStringLunar(
  -209,    // Lunar Year (1st Year of Qin Er Shi)
  "后九",   // Literal Chinese String Month
  15,      // Lunar Day
  12,      // Hour (0-23)
  0, 0,    // Min, Sec
  gender: Gender.male,
);
```

Supported Formats: `"正"` / `"一"` ~ `"十二"`, `"冬"` (11th Month), `"腊"` / `"拾贰"` (12th Month), `"闰X"` (Leap month e.g. `"闰五"`), `"后九"` (Zhuanxu Leap 9th month), `"十三"` (Ancient 13th month).

Internally, `fromLunar` strictly delegates to `fromStringLunar` for parsing. Both yield utterly identical computations.

---

## Complete CalendarOptions Breakdown

`CalendarOptions` operates as the tribunal governing how the engine settles astrological "disputed territories." Primarily, sticking with `ConfigLoader.getDefault()` is pristine behavior.

> [!NOTE]
> It is extremely normal for the exact same birth timestamp to yield varying charts under differing sects leveraging altered `CalendarOptions`. This is not a bug.

| Field | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `splitRatHour` | `bool` | `false` | **Distinguish Early/Late Zi hour**. When `true`: 23:00~24:00 is Late Zi (Counted as 'today'), 00:00~01:00 is Early Zi (Counted as 'tomorrow'). |
| `leapRule` | `LeapMonthRule` | `splitAt15` | **Leap month processing**. `splitAt15` (Pre-15th = Prev month, Post-15th = Next month), `asPrevious` (entirely prev month), `asNext` (entirely next month). |
| `wuHuDunBasedOn` (Experimental) | `Boundary` | `lunar` | **Five-Tigers-Chasing base**. `lunar` (Lunar Year Stem) or `solar` (Solar Term/BaZi Year Stem). |
| `siHuaBasedOn` | `Boundary` | `lunar` | **Birth Year SiHua base**. `lunar` (Lunar Year) or `solar` (Solar Term Year). Severely impacts charts born around Li Chun (Start of Spring). |
| `flowLimitBasedOn` (Experimental) | `Boundary` | `lunar` | **Flow bounds divider**. `lunar` (Lunar 1st) or `solar` (Solar Term bounds). |
| `enableHistorical` | `bool` | `true` | **Historical Safeguard**. Disables lower-tier timeline calculation logic across highly erratic historical calendar periods. |

---

## Location & Apparent Solar Time Fixes

Throughout Ziwei history, calculating times natively clashes between "Mean Solar Time" (Clock time) and "True/Apparent Solar Time."

- **Apparent Solar Time (Default)**: Fixes chronological time disparity based on Longitude shifting relative to the standard timezone meridian whilst stacking the Equation of Time effect (Earth's non-uniform orbit yields ±16 min swings). Subjects born immediately upon hour boundaries will observe their hours shift drastically.
- **Mean Solar Time**: Employs raw ticking clock parameters (timezone offsets). Handled simply by passing `useTrueSolarTime: false`.

```dart
// Apparent Solar Time (Default nature, pass coordinates)
final date = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 23, 45, 0),
  gender: Gender.female,
  location: Location(longitude: 121.47, latitude: 31.23), // Shanghai
);

// Mean Solar Time (Disables physical fixes entirely)
final date2 = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 23, 45, 0),
  gender: Gender.female,
  useTrueSolarTime: false,
);
```

> [!TIP]
> Excluding a `location` sets the baseline to `(120E, 30N)` by default (essentially fusing evenly with UTC+8), zeroing longitude fixes but leaving the Equation of Time fixes active. For pure naked clock-time plotting, explicitly toggle `useTrueSolarTime: false`.

---

## Serialization

```dart
final json = date.toJson();
// Extrudes comprehensive sub-structures holding solar, lunar, bazi, location, gender, timeZone, options logic.
```

---

## Common Pitfalls

### 1. Born between Li Chun (Start of Spring) and Lunar New Year Day—SiHua or Decades seem inverted
Year Stems (Lunar Vs Solar boundaries) are dictated via `siHuaBasedOn` and `wuHuDunBasedOn`. Trapped inside this temporal window, the Solar Term technically embraces a new Stem whereas the Lunar constraint stubbornly clings to the old one. This clash causes radically inverted chart flows. Please investigate the subject's distinct sect framework and toggle `CalendarOptions` accurately.

### 2. Born past 23:00 (11 PM) however the hour feels incorrect
`splitRatHour: false` ignores Early/Late Zi variations defaults merging the Zi boundary backwards counting as 'today'. Users enforcing 13-hour boundary arrays should declare `splitRatHour: true`.

### 3. Leap month births wildly deviate across engines
Leap month treatment (`leapRule`) presents the greatest astrological division known to Ziwei history. The 15th-day bisect constraint runs by default; adapt appropriately.

### 4. Plotting Historical Figures

**BC (Before Christ)**: Dart's native `DateTime` terminates forcefully at 1 AD. Navigating past antiquity unconditionally mandates `AstroDateTime`:
```dart
// 179 BC (Han Wendi)
final date = ZiweiDate.fromSolar(
  AstroDateTime(-179, 1, 1, 12, 0, 0),
  gender: Gender.male,
);
```

**Pre-1582 AD**: The drastic Gregorian calendar reform occurred forcing October 4 instantly skipping to October 15 (10 dead days). `AstroDateTime` channels the Meeus algorithms **identifying and shielding this discontinuity immaculately**—dates previous traverse Julian logic, dates following obey Gregorian boundaries. Using `AstroDateTime` remains absolutely valid.

Dart's native `DateTime`, however, executes a highly corrosive "Proleptic Gregorian" offset projecting modern bounds backward mindlessly corrupting timeline alignment preceding 1582 AD. **NEVER use `DateTime` attempting bounds previous to 1582**, firmly enforce `AstroDateTime` OR resort exclusively targeting `fromLunar`.

> [!TIP]
> If armed with documented Lunar records surrounding historical eras (as universally recorded natively in Imperial dynastic literature), plugging directly into `fromLunar` executes flawlessly dismissing Gregorian transitional catastrophes permanently.
