# Ziwei Core Quick Start Guide

This guide will take you from zero to calculating your first chart using this project in 5 minutes.

---

## 1. Installation & Configuration

Add the dependency in your `pubspec.yaml`:

```yaml
dependencies:
  ziwei_core: ^0.9.3
```

Run `dart pub get` to complete the installation.

---

## 2. Basic Chart Calculation (Origin Plate)

### Step A: Prepare Ruleset
The star placement rules of Ziwei Doushu are extremely complex. We have pre-configured a default ruleset for you.
For information on customizing rulesets, please refer to [Custom Rulesets](./02_custom_rulesets.md).
```dart
final ruleset = ConfigLoader.getDefault();
```

### Step B: Define Time & Gender
```dart
final birth = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 14, 30),
  // You can also use DateTime here, but it does not support BC dates.
  gender: Gender.female,
);
```

### Step C: Generate Chart in One Shot
```dart
final plate = ZiweiEngine.calculate(birth, ruleset);
```

### Step D (Optional): Serialize & Export JSON
If you need to pass chart data to a frontend or store it in a database, you can use the built-in `toJson` method:
```dart
import 'dart:convert';

final encoder = JsonEncoder.withIndent('  ');
print(encoder.convert(plate.toJson()));
```

---

## 3. Flow Timeline 推演 (Flow Timeline)

When you need to look at "this year's fortune," "the ten-year major limit," or "today's fortune," `TimelineProvider` is your core data source.

### 📊 Fetching the Timeline Manifest
Unified retrieval of time line stems and branches indices across different hierarchies via `getManifest`. Decade limits (Da Xian) and Childhood limits (Tong Xian) are always included:
```dart
final provider = TimelineProvider(plate);

// Skeleton: Only Decade limit + Childhood limit
final skeleton = provider.getManifest();

// Passing a year → Automatically mounts Flowing Month + infers Flowing Year within the Decade
final manifest = provider.getManifest(year: 2026);
print(manifest.currentYearMonths);   // 12 Flowing Months
print(manifest.currentDecadeYears);  // Infers the flowing years within the current decade

// Explicitly overriding the Decade limit index
final custom = provider.getManifest(year: 2026, decadeIndex: 3);

// Full Scope: Year + Month + Day + Hour
final full = provider.getManifest(year: 2026, month: 2, day: 5);
print(full.currentMonthDays);  // Flowing Days of that month
print(full.currentDayHours);   // Flowing Hours of that day

print("Historical Red Zone Status: ${manifest.status.isHistoricalRedZone}");
```

Some historical periods had chaotic calendars that require special handling. For these periods, calculating flowing month and below is temporarily unsupported. Only origin chart, decade limit, and flowing year generations are supported. If you forcefully wish to calculate down to flowing hours for these periods, you can set `"enable_historical": false`. See [Experimental Features](./05_experimental_features.md) for details.

| Historical Period | Time Range (Approximate) | Description |
| :--- | :--- | :--- |
| **Pre-Qin Chaotic Period** | 721 BC ~ 104 BC | Three starts of the year (Zi/Chou/Yin months) coexisted, highly inconsistent calendar standards. |
| **Wang Mang's Xin Dynasty** | 9 AD ~ 23 AD | Implemented the Wang Mang calendar, shifting the start of the year, breaking away from the Xia calendar. |
| **Cao Wei's Jingchu Calendar** | 237 AD ~ 239 AD | Briefly altered the definition of the first month. |
| **Wu Zetian's Zhou Calendar** | 689 AD ~ 700 AD | Shifted the first month to the Zi month, creating an 11-year calendar disjoint. |

> When querying these periods, `TimelineManifest`'s `status.is_historical_red_zone` will return `true`, and `current_year_months` will be empty.

### 🔍 Layered Time Index Query
You can query historical structure, age boundaries, and stem/branch indices on demand per layer. This is primarily used for building cascading pickers, timeline indices, or loading asynchronously on demand:

```dart
// 1. Fetch Childhood limit before the major limits begin (scattered years)
final childhoods = provider.getChildhood();

// 2. Fetch the entire life's Decade limit table (120 years)
final decades = provider.getDecades();

// 3. Fetch 10 Flowing Years within a specific Decade limit (requires decade index 1-12)
final years = provider.getYears(1);

// 4. Fetch 12 Flowing Months for a specific year (automatically handles lunar/solar term boundaries)
final months = provider.getMonths(2026);

// 5. Fetch every day strictly within a specific month (Flowing Day)
// Returns detailed array including Gregorian dates and day stems/branches
final days = provider.getDays(2026, 2); 

// 6. Fetch the 12/13 Flowing Hours of a specific date (requires the day pillar's stem/branch)
// Example: Fetch all hours for 2026-02-01
final firstDayGZ = GanZhi.fromString(days[0].stem, days[0].branch);
final hours = provider.getHours(firstDayGZ);
```

### 💫 Switching and Controlling Dynamic Flow Charts

`ZiweiLimitManager` is the hub for controlling time slices. It handles combining the origin chart (base map) with a specific time point (moment) to output a **Dynamic Chart** populated with flow stars and flow SiHua (transformers).

| Category | Method | Description |
| :--- | :--- | :--- |
| **Core Positioning** | `setPhysicalDate(time)` | **Highly Recommended**. Automatically parses and reconstructs the complete flowing time slice at this precise physical moment. |
| **Manual Switching** | `setDecadeIndex(index, {targetChildhoodYear})` | Jumps directly to the specified decade limit (0: Childhood, 1: First Decade...).<br>💡 If passing `0` to look at scattered childhood years, you **must** include `targetChildhoodYear` (the year you want to view), otherwise it cannot determine where the childhood Life palace lands. |
| | `setYear(year)` | Sets a specific flowing year. Resets subordinate months, days, and hours. |
| | `setMonth(month)` | Sets Lunar flowing month (1: First month, 12: Twelfth month). |
| | `setHour(hourIndex)` | Sets hour index (0: Zi, 1: Chou...). |
| **Relative Offset** | `addYear(delta)` | Jumps by a margin of years (e.g., `1` for next year). |
| | `addDuration(duration)` | Physical sliding calculation, flawlessly handling dead zones like leap months. |
| **Quick Adjustments** | `nextDay() / previousDay()` | Quickly flip daily dates. |
| | `nextHour() / previousHour()` | Switches hours, automatically dealing with cross-day logic. |
| **State Tools** | `reset()` | Completely resets all time markers, reverting to the origin chart. |
| | `getManifest()` | One-click fetch of a JSON structure containing all nodes for decades, flowing years, and flowing months. |

### 💫 Retrieving the Dynamic Flow Star Chart

Once you've decided which month or day's chart you want to view, hand the time over to `ZiweiLimitManager`:

```dart
final manager = ZiweiLimitManager(plate);

// 1. Set to a specific point in time (e.g., March 15, 2024)
manager.setPhysicalDate(DateTime(2024, 3, 15));

// 2. Extract the "Dynamic Limit Flow Plate" at this moment
// Based on the origin chart, it has injected the stars and SiHua for the current Decade, Year, Month, Day, and Hour in real-time.
final flowPlate = manager.dynamicPlate;

// 3. Serialize to export or pretty-print
final encoder = JsonEncoder.withIndent('  ');
print(encoder.convert(flowPlate.toJson())); 
```
