# API Reference Manual

---

## ConfigLoader

The primary entrance for constructing Rulesets. All `ZiweiRuleset` objects are born here.

| Method | Signature | Description |
| :--- | :--- | :--- |
| `getDefault()` | `static ZiweiRuleset getDefault()` | Returns the engine's built-in default ruleset. Works out of the box. |
| `overrideWith()` | `static ZiweiRuleset overrideWith(baseRuleset, {...})` | Applies a hot patch on top of a base ruleset. You only transmit the parameters you want to override. |
| `createRuleset()` | `static ZiweiRuleset createRuleset({...})` | Builds an entire ruleset universe from scratch. Requires supplying all necessary JSON strings. |

Optional JSON string parameters for `overrideWith` and `createRuleset`:
- `starsJson` — Origin Chart star placement rules
- `brightnessJson` — Brightness tiers table
- `sihuaJson` — SiHua mapping algorithms
- `flowJson` — Flow limit dynamic stars processing
- `mainRulesJson` — Calendar runtime toggles & Brightness labels
- `mastersJson` — Ming Master / Shen Master extraction mechanics

---

## ZiweiDate

Handles Birth Date definitions, bundling complete Lunar/BaZi/Solar Term parsing results within. For granular explanations (including `CalendarOptions` properties, Apparent Solar Time fixes based on Lat/Long, and calendar hazard cautions), please refer to the [ZiweiDate Detailed Guide](./06_ziwei_date.md).

### Construction

Three primary modes, segmented based on input formats:

| Method | Usage |
| :--- | :--- |
| `ZiweiDate.fromSolar(dt, {...})` | Solar/Gregorian input (Most common). `dt` accepts `AstroDateTime` (essential for BC dates) or Dart's `DateTime`. |
| `ZiweiDate.fromLunar(year, month, day, h, m, s, isLeap, {...})` | Lunar input. Months utilize integers. `isLeap` flags intercalary Leap Months. |
| `ZiweiDate.fromStringLunar(year, monthString, day, h, m, s, {...})` | Chinese lunar month string configurations (e.g., `"正"` [1st Month], `"闰五"` [Internal Leap 5th Month]). |

Parameters shared amongst all 3 constructors:
- `gender`: Gender flag, default `Gender.male`
- `options`: Calendar Toggles (When building custom rulesets, you **must** supply `ruleset.calendarOptions` here)
- `location`: Geographic Coordinates `(Longitude, Latitude)`. Default `(120E, 30N)`
- `timeZone`: Time Zone (UTC offset in hours). Default `8.0`
- `useTrueSolarTime`: Toggle Apparent Solar Time fixes. Default `true`

### Core Getters

| Property | Type | Description |
| :--- | :--- | :--- |
| `solar` | `AstroDateTime` | Gregorian Time |
| `trueSolarTime` | `AstroDateTime?` | Corrected Apparent Solar Time (Optional) |
| `lunar` | `LunarDate` | Lunar Time (Holds Leap Month flags, relative Month, and Day) |
| `bazi` | `BaZi` | BaZi / Four Pillars (Stems and Branches for Year, Month, Day, and Hour) |
| `solarDay` | `int` | Solar Term sequence day (Which day of the Solar Term calendar cycle it currently inhabits) |
| `timeIndex` | `int` | Hour stem index (`Zi` = 0, `Chou` = 1...) |
| `options` | `CalendarOptions` | Active calendar configurations applied to this date |
| `gender` | `Gender` | Gender |
| `location` | `Location` | Geographic observational coordinate point |
| `timeZone` | `double` | UTC Hour offset |

---

## ZiweiEngine

The core processing engine where all layout computations take place to spit out a plate object.

| Method | Signature | Description |
| :--- | :--- | :--- |
| `calculate()` | `static ZiWeiPlate calculate(date, ruleset, {tdrPan})` | Scaffolds the static Origin Chart based on birthday specifics and the designated ruleset. `tdrPan` is optional, defaults to `TDRpan.tianPan` (Heaven Plate). Pass `diPan` (Earth Plate, Body Palace as Ming) or `renPan` (Human Plate, Fude Palace as Ming). |
| `calculateDynamic()` | `static ZiWeiPlate calculateDynamic(LimitContext)` | Stacks specific timeline constraints (Decades, Flowing Years, etc.) over an Origin Chart generating a dynamic clone variant. Typically never invoked standalone—routed via `ZiweiLimitManager`. |

---

## ZiweiReverseLookup

Tier 1 reverse lookup engine: deduce possible birth-time parameters by specifying the palace indices of certain anchor stars.

### Entry Point

| Method | Signature | Description |
| :--- | :--- | :--- |
| `searchTier1()` | `static List<ZiweiReverseCandidate> searchTier1(ZiweiTier1Query query)` | Reverse-searches all possible birth times matching the given star positions. Results are deduplicated. |

### ZiweiTier1Query

The query object for reverse lookup. You must cover at least the **Year Stem, Year Branch, Month, Day, and Hour** dimensions to narrow down a meaningful date range.

| Field | Type | Dimension | Description |
| :--- | :--- | :--- | :--- |
| `lucunIndex` | `int?` | Year Stem | Palace index `0-11` of **Lucun**. Required. |
| `hongluanIndex` | `int?` | Year Branch | Palace index `0-11` of **Hongluan**. Required. |
| `zuofuIndex` | `int?` | Month | Palace index `0-11` of **Zuofu**. At least one of `zuofuIndex` / `youbiIndex` must be provided. |
| `youbiIndex` | `int?` | Month | Palace index `0-11` of **Youbi**. At least one of `zuofuIndex` / `youbiIndex` must be provided. |
| `wenchangIndex` | `int?` | Hour | Palace index `0-11` of **Wenchang**. At least one of `wenchangIndex` / `wenquIndex` must be provided. |
| `wenquIndex` | `int?` | Hour | Palace index `0-11` of **Wenqu**. At least one of `wenchangIndex` / `wenquIndex` must be provided. |
| `santaiIndex` | `int?` | Day | Palace index `0-11` of **Santai**. At least one of `santaiIndex` / `bazuoIndex` must be provided (strongly recommended). |
| `bazuoIndex` | `int?` | Day | Palace index `0-11` of **Bazuo**. At least one of `santaiIndex` / `bazuoIndex` must be provided. |
| `ziweiIndex` | `int?` | Advanced filter | Palace index `0-11` of **Ziwei**. Optional; supplying it further reduces ambiguous candidates. |
| `startDate` | `AstroDateTime` | Range | Start of the Gregorian date search window. |
| `endDate` | `AstroDateTime` | Range | End of the Gregorian date search window. |
| `gender` | `Gender` | Config | Gender, default `male`. |
| `tdrPan` | `TDRpan` | Config | Plate type, default `tianPan`. |
| `location` | `Location` | Config | Birth location, default Shanghai `(120E, 30N)`. |
| `timeZone` | `double` | Config | Time zone offset, default `8.0`. |
| `useTrueSolarTime` | `bool` | Config | Enable apparent solar time correction, default `true`. |
| `ruleset` | `ZiweiRuleset` | Config | The ruleset to use for both calendar conversion and chart calculation. **Required**. |

### ZiweiReverseCandidate

A single candidate result containing a prospective birth time and its forward-verified chart.

| Field | Type | Description |
| :--- | :--- | :--- |
| `solarDate` | `AstroDateTime` | Candidate Gregorian birth time (after true-solar-time conversion if enabled). |
| `lunarYear` | `int` | Lunar year. |
| `lunarMonth` | `int` | Lunar month `1-12`. |
| `lunarDay` | `int` | Lunar day `1-30`. |
| `hourIndex` | `int` | Hour index `0-11` (`Zi`=0). |
| `isLeapMonth` | `bool` | Whether the candidate falls in a leap month. |
| `plate` | `ZiWeiPlate` | The fully calculated chart used for forward verification. |

### Usage Example

```dart
final results = ZiweiReverseLookup.searchTier1(
  ZiweiTier1Query(
    lucunIndex: 2,      // Lucun in Yin (3rd palace)
    hongluanIndex: 3,   // Hongluan in Mao (4th palace)
    zuofuIndex: 6,      // Zuofu in Si (7th palace)
    wenchangIndex: 8,   // Wenchang in Wei (9th palace)
    santaiIndex: 4,     // Santai in Chen (5th palace)
    ziweiIndex: 0,      // Ziwei in Zi ( optional; tightens results)
    startDate: AstroDateTime(1970, 1, 1),
    endDate: AstroDateTime(2025, 12, 31),
    ruleset: ruleset,
    gender: Gender.male,
  ),
);

for (final r in results) {
  print('Solar: ${r.solarDate} / Lunar: ${r.lunarYear}-${r.lunarMonth}-${r.lunarDay}');
}
```

### Important Limitations

**Day-level stars can never uniquely lock down the exact lunar day.** All static day-based placement formulas—including Santai, Bazuo, Ziwei, Tianfu, Enguang, and Tiangui—are fundamentally limited to resolving `day % 12`. This means:

- Within the same lunar month, there are usually **2–3 candidate days** that satisfy the given constraints (separated by 12 or 24 days).
- Adding `ziweiIndex` **reduces** ambiguity (especially when the Five-Element Bureau is not Water-2), but it still cannot mathematically guarantee a single unique answer in every case.

If multiple candidates are returned, that is expected behavior; the end user must select the actual birth date from the shortlist.

---

## ZiWeiPlate

The data package of the Astrological Chart carrying the complete states of the 12 Palaces. Typically never constructed by hand, derived solely via `ZiweiEngine`.

### Palace Probing Queries

```dart
// Fetch the Palace Object based on a Flow constraint hierarchy and a Palace Role
final decadeSpousePalace = plate.getPalace(ZiweiScope.decade, PalaceRole.spouse);

// Reverse Lookup: What exact Role does this rigid geometric tile represent for the current active flow tier?
final role = plate.getRole(ZiweiScope.year, palaceIndex);
```

### Ming (Life) Palace Shortcut Getters

| Property | Description |
| :--- | :--- |
| `originMingPalace` | Origin limit Life Palace |
| `bodyPalace` | Body Palace (Shen Gong) |
| `tdrPan` | Current plate type (`tianPan` Heaven / `diPan` Earth / `renPan` Human) |
| `decadeMingPalace` | Currently active Decade Life Palace (Yields null if subject hasn't reached an active decade yet) |
| `yearMingPalace` | Currently active Flowing Year Life Palace |
| `monthMingPalace` | Currently active Flowing Month Life Palace |
| `dayMingPalace` | Currently active Flowing Day Life Palace |
| `hourMingPalace` | Currently active Flowing Hour Life Palace |

### Serialization

```dart
// Rapidly serialize the entire board state (Including the inner-states of 12 Palaces, all Stars, SiHuases, and cascading dynamic cursors)
final Map<String, dynamic> json = plate.toJson();
```

---

## TimelineProvider

A structural time navigator, issuing structural Tree hierarchies for branches, epochs, and constraints spanning a lifetime without loading the exhaustive astrological data maps.

```dart
final provider = TimelineProvider(plate);
```

### Layered Index Extractions

| Method | Return | Description |
| :--- | :--- | :--- |
| `getDecades()` | `List<DecadeNode>` | Plucks the 12 Decades covering an exhaustive 120-year cycle (Start/End years, ages, mapped Earthly Branches) |
| `getChildhood()` | `List<ChildhoodNode>` | Scattershot Childhood span preceding the threshold of the very first Decade Limit |
| `getYears(decadeIndex)` | `List<YearNode>` | Yields exactly 10 chronological Flowing Years inside the designated Decade Limit constraint |
| `getMonths(year)` | `List<MonthNode>` | Yields 12 structured Flowing Months matching the target Calendar constraint properties inside a Year |
| `getDays(year, month)` | `List<DayNode>` | Explodes a defined lunar month into detailed days (Holding Gregorian references + daily BaZi Stems/Branches) |
| `getHours(dayGanZhi)` | `List<HourNode>` | Fetches daily constraints yielding 12 or 13 Flowing Hours linked to a specific Day Stem/Branch pillar |

### Unified Timeline Manifest Payload

```dart
// Base skeleton exclusively (Decades + Childhoods)
provider.getManifest();

// Year passed → Injects Flowing Month arrays + intrinsically deduces Decade and Flowing Year brackets
provider.getManifest(year: 2026);

// Overpowering intrinsic decade deducer forcing a bespoke index 
provider.getManifest(year: 2026, decadeIndex: 3);

// The Full Omniscient View Tree (Year + Month + Day + Hour)
provider.getManifest(year: 2026, month: 2, day: 5);
```

**`getManifest` Argument Breakdown:**

| Argument | Type | Description |
| :--- | :--- | :--- |
| `year` | `int?` | Instantiates Flowing Months parsing down arrays, subsequently triggering internal bounds deduction mapping back to Decade and Year origins |
| `decadeIndex` | `int?` | Forceps index mapping bypassing deduction inference (`0`=Childhood, `1`=Active Decade 1...) |
| `month` | `int?` | Instantiates Flowing Days arrays mapped to the given month param (Mandates `year` presence) |
| `day` | `int?` | Instantiates Flowing Hours mapped exclusively to the given day boundary param (Mandates both `year` + `month` presence) |

`getManifest` Returns strictly a parsed `TimelineManifest` package wrapping:

| Field | Type | Description |
| :--- | :--- | :--- |
| `childhoods` | `List<ChildhoodNode>` | Always Returned |
| `decades` | `List<DecadeNode>` | Always Returned |
| `currentDecadeYears` | `List<YearNode>?` | Existent so long as `year` or `decadeIndex` queries triggered parsing |
| `currentYearMonths` | `List<MonthNode>?` | Existent if `year` queries triggered parsing |
| `currentMonthDays` | `List<DayNode>?` | Existent if `year` + `month` queries triggered parsing |
| `currentDayHours` | `List<HourNode>?` | Existent if `year` + `month` + `day` queries triggered parsing |
| `status.isHistoricalRedZone` | `bool` | Evaluates runtime vulnerability to documented erratic ancient calendar discrepancies blocking microscopic month estimations |

---

## ZiweiLimitManager

Stateful Flow plate manager masking granular timescale offsets controlling cascading generation sequences required to instantiate Dynamic Limit Context plates seamlessly.

```dart
final manager = ZiweiLimitManager(plate);
```

### Retrieving Active States

| Property/Method | Return | Description |
| :--- | :--- | :--- |
| `dynamicPlate` | `ZiWeiPlate` | **A live instantiated clone variant plate fully packed mapping precise time limit arrays dictated by internal cursors.** (Driven largely via internal limits set like `setYear`/`setMonth`, preserving origins preventing reference pollutions) |
| `basePlate` | `ZiWeiPlate` | Absolute pristine untouched Origin Chart |
| `limitContext` | `LimitContext` | Underlying constraints engine container |
| `currentManifest` | `TimelineManifest` | Unified timeline node package relative to the current active bounds. |
| `getManifest([decadeIndex])` | `TimelineManifest` | Symmetrical replica wrapper retrieving specific nodes identical to the current context constraints logic parameters. |

### Time Traveling Toggles

| Method | Description |
| :--- | :--- |
| `setPhysicalDate(time)` | **Pinnacle Recommendation**. Feed parameter variants of `DateTime` or `AstroDateTime` mapping automatic physical alignment dropping constraints parsing straight cascading into identical Decade/Year/Month/Day/Hour indices synchronously. |
| `setDecadeIndex(index, {targetChildhoodYear})` | Absolute drop target pointing Decade (`0`=Childhood constraint—requiring supplementary constraints like `targetChildhoodYear` parameter ensuring precise alignment points). |
| `setYear(year)` | Wipes all sub-level bounds targeting a raw Flowing Year limit. |
| `setMonth(month)` | Focus targets chronological Lunar months (`1`=1st Month...). |
| `setHour(hourIndex)` | Chronological Time offset index (`0`=Zi hour...). |

### Chronological Steppers and Crawlers

| Method | Description |
| :--- | :--- |
| `addYear(delta)` | Modulates bounds by relative amplitudes (`1`=Following Year, `-1`=Preceding Year). |
| `addMonth(delta)` | Modulates bounds by relative amplitudes. Assures exact celestial navigation bounding cleanly transitioning within Solar bounds settings if active. |
| `addDuration(duration)` | Precision physical timeline sliding. Safely glides boundaries across chronological hazard zones like internally divided leap months. |
| `nextDay() / previousDay()` | Daily flips. |
| `nextHour() / previousHour()` | Cascading hour toggles, preserving late Zi hour safeguards stopping illegal bound transgressions overlapping raw day spans. |

### Destructions and Rollbacks

| Method | Description |
| :--- | :--- |
| `clearHour/Day/Month/Year/Decade()` | Singular bounds destruction peeling limit layers one by one. |
| `reset()` | Atomizing destruction resetting states dropping constraints reverting raw arrays directly to Origin Chart boundaries. |

---

## Palace

An architectural data pillar encasing single tile constraint elements on plates. Usually retrieved natively via `plate.palaces[i]` or `plate.getPalace()`.

| Property | Type | Description |
| :--- | :--- | :--- |
| `branch` | `DiZhi` | Fixed foundation index Branch belonging fundamentally to this geometric Palace (`Zi` = 0...) |
| `stem` | `TianGan?` | Sky Stem governing the tile (Dictated intrinsically by Five-Tigers-Chasing algorithms) |
| `ganzhi` | `GanZhi` | Conjoined properties encompassing `stem` and `branch` |
| `stars` | `List<Star>` | The aggregation of stars occupying the space (Both Original static anchors and Dynamic moving modifiers) |

```dart
// Target probe seeking a particular star existence
palace.hasStar('ziwei');

// Single Palace specific JSON packaging wrapper
palace.toJson(brightnessLabels: ruleset.brightnessLabels);
```

---

## TimeMachine

Surgical bypass component structuring `LimitContext` wrappers entirely dismissing `ZiweiLimitManager` constructs providing unmitigated access building abstract parameters suitable for mass-array parallel generations.

| Method | Description |
| :--- | :--- |
| `TimeMachine.travel(plate, {year, month, day, hourIndex, dayGanZhi})` | Auto structures full `LimitContext` variants dropping direct limit wrappers via parameters. |
| `TimeMachine.travelByMacro(plate, index, {targetYear})` | Structured drop directly assigning limits mapped immediately to chronological index bindings (`0`=Childhood bounds, `1`=Decade Number 1...). |

---

## Enum Value Index Overview

| Enum | Common Attributes |
| :--- | :--- |
| `Gender` | `male`、`female` |
| `TDRpan` | `tianPan` (Heaven)、`diPan` (Earth)、`renPan` (Human) |
| `ZiweiScope` | `origin`、`decade`、`year`、`month`、`day`、`hour`、`smallLimit` |
| `PalaceRole` | `ming` (Life)、`siblings` (Brothers)、`spouse` (Partner)、`children` (Offspring)... |
| `Boundary` | `lunar` (Lunar)、`solar` (Solar Term boundaries) |
