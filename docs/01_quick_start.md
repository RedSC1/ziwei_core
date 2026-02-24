# Ziwei Core 快速上手指南 (Quick Start)

本指南将带你从零开始，在 5 分钟内使用本项目排盘

---

## 1. 安装与配置

在你的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  ziwei_core: ^1.0.0 //待完善文档后上传到pub.dev
```

运行 `dart pub get` 完成安装。

---

## 2. 基础排盘 (Primary Plate)

### 步骤 A：准备规则集
紫微斗数的安星规则极其复杂，我们预置了一套默认规则集。
关于自定义规则集，详情请参阅[自定义规则说明](./02_custom_rulesets.md)。
```dart
final ruleset = ConfigLoader.getDefault();
```

### 步骤 B：定义时间与性别
```dart
final birth = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 14, 30),
  //这里也可以使用DateTime，但是不支持公元前的时间
  gender: Gender.female,
);
```

### 步骤 C：一键出盘
```dart
final plate = ZiweiEngine.calculate(birth, ruleset);
```

### 步骤 D (可选)：序列化导出 JSON
如果你需要将命盘数据传递给前端或存储到数据库，可以使用内置的 `toJson` 方法：
```dart
import 'dart:convert';

final encoder = JsonEncoder.withIndent('  ');
print(encoder.convert(plate.toJson()));
```


---

## 3. 流运推演 (Flow Timeline)

当需要看“今年运势”、“十年大运”或者“今日运势”时，`TimelineProvider` 是你的核心数据源。

### 📊 获取时间线清单 (Timeline Manifest)
统一通过 `getManifest` 按需获取不同层级的时间线干支索引，大限与童限始终包含：
```dart
final provider = TimelineProvider(plate);

// 骨架：只要大限 + 童限
final skeleton = provider.getManifest();

// 传入年份 → 自动挂载流月 + 自动推断大限流年
final manifest = provider.getManifest(year: 2026);
print(manifest.currentYearMonths);   // 12 个流月
print(manifest.currentDecadeYears);  // 自动推断大限内的流年

// 显式覆盖大限索引
final custom = provider.getManifest(year: 2026, decadeIndex: 3);

// 全量：年 + 月 + 日 + 时
final full = provider.getManifest(year: 2026, month: 2, day: 5);
print(full.currentMonthDays);  // 该月流日
print(full.currentDayHours);   // 该日流时

print("历史红区状态: ${manifest.status.isHistoricalRedZone}");
```

历史上有些时间段历法混乱，需要特殊处理，这里对于一些特殊时间段，暂时不支持流月及以下的推演，仅支持原局和大限流年的排盘，若要强行排流月流日流时盘，可以设置`"enable_historical": false`，详情见[实验性功能](./05_experimental_features.md)。

| 历史时期 | 时间范围 (近似) | 说明 |
| :--- | :--- | :--- |
| **先秦混乱期** | 公元前 721 ~ 公元前 104 | 三正（建子/丑/寅）并行，历法标准极度不统一。 |
| **王莽新朝** | 公元 9 ~ 公元 23 | 实行王莽历，改变岁首，导致与夏历脱节。 |
| **曹魏景初历** | 公元 237 ~ 公元 239 | 曹魏推行景初历，短暂改变过正月定义。 |
| **武则天周历** | 公元 689 ~ 公元 700 | 武则天改以子月为正月，产生长达 11 年的历法断层。 |

> 当查询上述时间段时，`TimelineManifest` 的 `status.is_historical_red_zone` 会返回 `true`，且 `current_year_months` 为空。

### 🔍 分层级时间索引查询 (Layered Time Index Query)
你可以按需深入查询每一层的时间结构、年岁边界和干支，主要用于构建级联选择器、时间轴索引或按需异步加载：

```dart
// 1. 获取起运前的童限 (散装年份)
final childhoods = provider.getChildhood();

// 2. 获取一生大限表 (120年)
final decades = provider.getDecades();

// 3. 获取指定大限内的 10 个流年表 (需传入大限索引 1-12)
final years = provider.getYears(1);

// 4. 获取指定年份的 12 个流月 (自动处理农历/节气交界)
final months = provider.getMonths(2026);

// 5. 获取指定月份的每一天 (流日)
// 返回包含阳历日期、日干支的详细数组
final days = provider.getDays(2026, 2); 

// 6. 获取指定日期的 12/13 个（区分早晚子时13个，不区分12个）流时 (需传入日柱干支进行推算)
// 例如：获取 2026-02-01 这一天的所有时辰
final firstDayGZ = GanZhi.fromString(days[0].stem, days[0].branch);
final hours = provider.getHours(firstDayGZ);
```

### 💫 动态流运盘的切换与控制 (Dynamic Flow Chart Control)

`ZiweiLimitManager` 是控制时间切片的枢纽。它负责将原盘（底图）与特定的时间点（时刻）结合，生成带有流曜、流化的**动态盘**。

| 分类 | 方法 | 说明 |
| :--- | :--- | :--- |
| **核心定位** | `setPhysicalDate(time)` | **最推荐用法**。会自动解析并重构出此时此刻的完整流运切片。 |
| **手动切换** | `setDecadeIndex(index, {targetChildhoodYear})` | 直接跳转到指定大限 (0:童限, 1:第一大限...)。<br>💡 如果传入 `0` 看前几年的散装童限，**必须**带上第二个参数 `targetChildhoodYear` (你想看哪一年)，无法确定童限命宫落在哪宫。 |
| | `setYear(year)` | 设定特定流年，重置下属月、日、时。 |
| | `setMonth(month)` | 设定农历流月 (1:正月, 12:腊月)。 |
| | `setHour(hourIndex)` | 设定时辰索引 (0:子, 1:丑...)。 |
| **相对偏移** | `addYear(delta)` | 按年份幅度跨越 (如 `1` 为明年)。 |
| | `addDuration(duration)` | 物理滑动推演，完美处理闰月等天文盲区。 |
| **快捷微调** | `nextDay() / previousDay()` | 快速翻转日期。 |
| | `nextHour() / previousHour()` | 切换时辰，自动处理跨天逻辑。 |
| **状态工具** | `reset()` | 彻底重置所有时间标记，回退到原局。 |
| | `getManifest()` | 一键获取包含大限、流年、流月所有节点的 JSON 结构。 |

### 💫 获取流运动态星盘 (Retrieving Dynamic Flow Charts)

当你决定了要看哪一个月或哪一天的盘时，将时间交给 `ZiweiLimitManager`：

```dart
final manager = ZiweiLimitManager(plate);

// 1. 设置到某个时间点 (如 2024年3月15日)
manager.setPhysicalDate(DateTime(2024, 3, 15));

// 2. 获取该时刻的“限流动态盘”
// 它在原局基础上，实时注入了当前大限、流年、流月、流日及流时的星曜与四化
final flowPlate = manager.dynamicPlate;

// 3. 序列化导出或美化打印
final encoder = JsonEncoder.withIndent('  ');
print(encoder.convert(flowPlate.toJson())); 
```


