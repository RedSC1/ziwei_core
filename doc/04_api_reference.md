# API 参考手册 (API Reference)

---

## ConfigLoader

规则集的构建入口，所有`ZiweiRuleset`都由它创建。

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `getDefault()` | `static ZiweiRuleset getDefault()` | 返回引擎内置的默认规则集，开箱即用。 |
| `overrideWith()` | `static ZiweiRuleset overrideWith(baseRuleset, {...})` | 在基准规则集上热补丁覆盖，只传入你想改变的部分。 |
| `createRuleset()` | `static ZiweiRuleset createRuleset({...})` | 从零全量构建一套规则集，需传入所有必要的 JSON 字符串。 |

`overrideWith` 和 `createRuleset` 的可选 JSON 参数：
- `starsJson` — 原局安星规则
- `brightnessJson` — 亮度表
- `sihuaJson` — 四化规则
- `flowJson` — 流运星曜规则
- `mainRulesJson` — 历法开关与亮度标签
- `mastersJson` — 命主/身主起例

---

## ZiweiDate

出生时间定义，同时包含完整的农历/八字/节气解析结果。详细说明（含 `CalendarOptions` 全字段、经纬度真太阳时及踩坑指南）请参阅 [ZiweiDate 详细说明](./06_ziwei_date.md)。

### 构造

三种方式，按输入格式选择：

| 方法 | 用途 |
| :--- | :--- |
| `ZiweiDate.fromSolar(dt, {...})` | 阳历输入（最常用）。`dt` 支持 `AstroDateTime`（公元前可用）或 `DateTime`。 |
| `ZiweiDate.fromLunar(year, month, day, h, m, s, isLeap, {...})` | 农历输入。月份用整数，`isLeap` 标记闰月。 |
| `ZiweiDate.fromStringLunar(year, monthString, day, h, m, s, {...})` | 中文月份字符串（如 `"正"`, `"闰五"`, `"后九"`）。 |

三者共有的可选参数：
- `gender`: 性别，默认 `Gender.male`
- `options`: 历法开关（自定义 ruleset 时必须传 `ruleset.calendarOptions`）
- `location`: 经纬度，默认 `(120E, 30N)`
- `timeZone`: 时区，默认 `8.0`
- `useTrueSolarTime`: 是否启用真太阳时，默认 `true`

### 主要 Getters

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `solar` | `AstroDateTime` | 阳历时间 |
| `trueSolarTime` | `AstroDateTime?` | 真太阳时修正后的时间（可选） |
| `lunar` | `LunarDate` | 农历时间（含是否闰月、月份、日） |
| `bazi` | `BaZi` | 四柱八字（年月日时的天干地支） |
| `solarDay` | `int` | 节气日序（该年节气历第几天） |
| `timeIndex` | `int` | 时辰索引（子=0, 丑=1...） |
| `options` | `CalendarOptions` | 当前生效的历法配置 |
| `gender` | `Gender` | 性别 |
| `location` | `Location` | 地理观测点 |
| `timeZone` | `double` | 时区（UTC 偏移小时数） |

---

## ZiweiEngine

核心排盘引擎，所有计算都在这里完成，返回命盘对象。

| 方法 | 签名 | 说明 |
| :--- | :--- | :--- |
| `calculate()` | `static ZiWeiPlate calculate(date, ruleset, {tdrPan})` | 根据出生时间和规则集排原局命盘。`tdrPan` 可选，默认 `TDRpan.tianPan`（天盘），可传 `diPan`（地盘，身宫为命宫）或 `renPan`（人盘，福德宫为命宫）。 |
| `calculateDynamic()` | `static ZiWeiPlate calculateDynamic(LimitContext)` | 根据流运上下文在原盘上叠加大限/流年等，返回动态克隆盘。通常不需要直接调用，由 `ZiweiLimitManager` 封装。 |

---

## ZiWeiPlate

命盘数据对象，包含 12 宫位完整状态。通常不直接构造，由 `ZiweiEngine` 返回。

### 宫位查询

```dart
// 获取某流运层级、某宫位角色的宫位对象
final decadeSpousePalace = plate.getPalace(ZiweiScope.decade, PalaceRole.spouse);

// 反查：某个格子在当前流派里是什么宫
final role = plate.getRole(ZiweiScope.year, palaceIndex);
```

### 命宫快捷 Getters

| 属性 | 说明 |
| :--- | :--- |
| `originMingPalace` | 原局命宫 |
| `bodyPalace` | 身宫 |
| `tdrPan` | 当前盘类型（`tianPan` 天盘 / `diPan` 地盘 / `renPan` 人盘） |
| `decadeMingPalace` | 当前大限命宫（未进入大限则为 null） |
| `yearMingPalace` | 当前流年命宫 |
| `monthMingPalace` | 当前流月命宫 |
| `dayMingPalace` | 当前流日命宫 |
| `hourMingPalace` | 当前流时命宫 |

### 序列化

```dart
// 序列化整盘（含 12 宫所有星曜、四化、流运命宫游标）
final Map<String, dynamic> json = plate.toJson();
```

---

## TimelineProvider

时间线索引生成器，提供各级时间结构的干支索引数据，不包含星盘信息。

```dart
final provider = TimelineProvider(plate);
```

### 分层索引查询

| 方法 | 返回 | 说明 |
| :--- | :--- | :--- |
| `getDecades()` | `List<DecadeNode>` | 一生 12 个大限（起止年份、岁数、干支） |
| `getChildhood()` | `List<ChildhoodNode>` | 起运前的童限年份列表 |
| `getYears(decadeIndex)` | `List<YearNode>` | 指定大限内的 10 个流年干支 |
| `getMonths(year)` | `List<MonthNode>` | 指定年份的 12 个流月（自动处理农历/节气界标） |
| `getDays(year, month)` | `List<DayNode>` | 指定月份的每一天（含阳历日期和日干支） |
| `getHours(dayGanZhi)` | `List<HourNode>` | 指定日干支的 12/13 个流时 |

### 统一时间线清单

```dart
// 只获取骨架（大限 + 童限）
provider.getManifest();

// 传入年份 → 自动推断大限流年 + 返回流月索引
provider.getManifest(year: 2026);

// 显式覆盖大限索引
provider.getManifest(year: 2026, decadeIndex: 3);

// 全量（年 + 月 + 日 + 时）
provider.getManifest(year: 2026, month: 2, day: 5);
```

**`getManifest` 参数：**

| 参数 | 类型 | 说明 |
| :--- | :--- | :--- |
| `year` | `int?` | 传入后挂载流月，并自动推断所属大限/流年 |
| `decadeIndex` | `int?` | 覆盖大限自动推断（`0`=童限，`1`=第一大限...） |
| `month` | `int?` | 传入后挂载流日（需同时传 `year`） |
| `day` | `int?` | 传入后挂载流时（需同时传 `year` + `month`） |

`getManifest` 返回 `TimelineManifest`，包含：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `childhoods` | `List<ChildhoodNode>` | 始终返回 |
| `decades` | `List<DecadeNode>` | 始终返回 |
| `currentDecadeYears` | `List<YearNode>?` | 传入 `year` 或 `decadeIndex` 时返回 |
| `currentYearMonths` | `List<MonthNode>?` | 传入 `year` 时返回 |
| `currentMonthDays` | `List<DayNode>?` | 传入 `year` + `month` 时返回 |
| `currentDayHours` | `List<HourNode>?` | 传入 `year` + `month` + `day` 时返回 |
| `status.isHistoricalRedZone` | `bool` | 是否处于历史历法混乱期 |

---

## ZiweiLimitManager

流运动态盘控制器，封装时间切片的切换逻辑并负责生成限流动态盘。

```dart
final manager = ZiweiLimitManager(plate);
```

### 读取状态

| 属性/方法 | 返回 | 说明 |
| :--- | :--- | :--- |
| `dynamicPlate` | `ZiWeiPlate` | **当前已设定的时间切片对应的限流动态盘**（基于 `setYear`/`setMonth` 等设定的流运状态，每次调用返回新克隆，不污染原盘） |
| `basePlate` | `ZiWeiPlate` | 原局命盘（不变） |
| `limitContext` | `LimitContext` | 当前流运上下文（含大限/年/月/日/时对象） |
| `currentManifest` | `TimelineManifest` | 当前年份的流月时间线清单 |
| `getManifest([decadeIndex])` | `TimelineManifest` | 包含当前大限流年在内的完整时间线清单（`currentManifest` 的可控版本） |

### 时间切换

| 方法 | 说明 |
| :--- | :--- |
| `setPhysicalDate(time)` | **最推荐**。传入 `DateTime` 或 `AstroDateTime`，自动解析并切入对应的大限/年/月/日/时。 |
| `setDecadeIndex(index, {targetChildhoodYear})` | 直接跳到指定大限（`0`=童限，童限时必须同时传 `targetChildhoodYear`）。 |
| `setYear(year)` | 切入指定流年，清空下属流月/日/时。 |
| `setMonth(month)` | 切入指定农历流月（`1`=正月...）。 |
| `setHour(hourIndex)` | 切入指定时辰索引（`0`=子时...）。 |

### 相对偏移

| 方法 | 说明 |
| :--- | :--- |
| `addYear(delta)` | 按年份幅度跨越（`1`=明年，`-1`=去年）。 |
| `addMonth(delta)` | 按月份偏移。节气模式下会精准跳至下一个"节"。 |
| `addDuration(duration)` | 物理时间滑动，完美处理闰月/早晚子时等历法盲区。 |
| `nextDay() / previousDay()` | 翻日。 |
| `nextHour() / previousHour()` | 切换时辰，自动回归时辰中轴点，规避晚子时越界问题。 |

### 清理与重置

| 方法 | 说明 |
| :--- | :--- |
| `clearHour/Day/Month/Year/Decade()` | 逐层向上剥离流运。 |
| `reset()` | 彻底清空所有时间标记，回退到原局。 |

---

## Palace

命盘中的单个宫位对象。通常通过 `plate.palaces[i]` 或 `plate.getPalace()` 获取。

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `branch` | `DiZhi` | 该宫的地支（固定，子=0...） |
| `stem` | `TianGan?` | 该宫的天干（由五虎遁决定） |
| `ganzhi` | `GanZhi` | 宫位干支组合 |
| `stars` | `List<Star>` | 该宫的所有星曜（含原局星和流运星） |

```dart
// 判断宫内有无某颗星
palace.hasStar('ziwei');

// 序列化单个宫位
palace.toJson(brightnessLabels: ruleset.brightnessLabels);
```

---

## TimeMachine

`LimitContext` 的快捷工厂类，用于跳过 `ZiweiLimitManager` 直接构建流运上下文。通常不需要直接使用，除非你需要细粒度控制 `LimitContext` 或进行批量计算。

| 方法 | 说明 |
| :--- | :--- |
| `TimeMachine.travel(plate, {year, month, day, hourIndex, dayGanZhi})` | 按年/月/日/时自动构建完整的 `LimitContext`（包含大限、小限、流年等） |
| `TimeMachine.travelByMacro(plate, index, {targetYear})` | 按大限索引直接构建 `LimitContext`（`0`=童限，`1`=第一大限...） |

---

## 枚举速查

| 枚举 | 常用值 |
| :--- | :--- |
| `Gender` | `male`、`female` |
| `TDRpan` | `tianPan`（天盘）、`diPan`（地盘）、`renPan`（人盘） |
| `ZiweiScope` | `origin`、`decade`、`year`、`month`、`day`、`hour`、`smallLimit` |
| `PalaceRole` | `ming`（命）、`siblings`（兄弟）、`spouse`（夫妻）、`children`（子女）... |
| `Boundary` | `lunar`（农历）、`solar`（节气） |
