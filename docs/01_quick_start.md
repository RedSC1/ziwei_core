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
关于自定义规则集，详情请参阅[自定义规则说明](./03_custom_rulesets.md)。
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

---

## 3. 流运推演 (Flow Timeline)

当需要看“今年运势”、“十年大运”或者“今日运势”时，`TimelineProvider` 是你的核心数据源。

### 📊 获取年度清单 (Manifest)
你可以一键获取当前年份的所有关键节点，非常适合前端绘制时光轴。
```dart
final provider = TimelineProvider(plate);
final manifest = provider.generateManifest(2024);

print("历史红区状态: ${manifest['status']['is_historical_red_zone']}");
// list of FlowMonth objects for the year
final months = manifest['current_year_months']; 
```
历史上有些时间段历法混乱，需要特殊处理，这里对于一些特殊时间段，暂时不支持流月及以下的推演，仅支持原局和大限流年的排盘，若要强行排流月流日流时盘，可以设置`"enable_historical": false`，详情见[实验性功能](./04_experimental_features.md)。

| 历史时期 | 时间范围 (近似) | 说明 |
| :--- | :--- | :--- |
| **先秦混乱期** | 公元前 721 ~ 公元前 104 | 三正（建子/丑/寅）并行，历法标准极度不统一。 |
| **王莽新朝** | 公元 9 ~ 公元 23 | 实行王莽历，改变岁首，导致与夏历脱节。 |
| **曹魏景初历** | 公元 237 ~ 公元 239 | 曹魏推行景初历，短暂改变过正月定义。 |
| **武则天周历** | 公元 689 ~ 公元 700 | 武则天改以子月为正月，产生长达 11 年的历法断层。 |

> 当查询上述“红区”时间段时，`TimelineManifest` 的 `status.is_historical_red_zone` 会返回 `true`，且 `current_year_months` 为空。

### 🔍 精细化维度查询
你可以按需深入查询每一层的时间边界和干支：

```dart
// 1. 获取一生大限表 (120年)
final decades = provider.getDecades();

// 2. 获取指定年份的 12 个流月 (自动处理农历/节气交界)
final months = provider.getMonths(2026);

// 3. 获取指定月份的每一天 (流日)
// 返回包含阳历日期、日干支、交节时刻的详细数组
final days = provider.getDays(2026, 2); 
```

### 💫 动态流运管理器 (LimitManager)

`ZiweiLimitManager` 是控制时间切片的枢纽。它负责将原盘（底图）与特定的时间点（时刻）结合，生成带有流曜、流化的**动态盘**。

| 分类 | 方法 | 说明 |
| :--- | :--- | :--- |
| **核心定位** | `setPhysicalDate(time)` | **最推荐用法**。会自动解析并重构出此时此刻天地相交的完整流运切片。 |
| **手动切换** | `setDecadeIndex(index, {targetChildhoodYear})` | 直接跳转到指定大限 (0:童限, 1:第一大限...)。<br>💡 如果传入 `0` 看前几年的散装童限，**必须**带上第二个参数 `targetChildhoodYear` (你想看哪一年)，无法确定童限命宫落在哪宫。 |
| | `setYear(year)` | 设定特定流年，重置下属月、日、时。 |
| | `setMonth(month)` | 设定农历流月 (1:正月, 12:腊月)。 |
| | `setHour(hourIndex)` | 设定时辰索引 (0:子, 1:丑...)。 |
| **相对偏移** | `addYear(delta)` | 按年份幅度跨越 (如 `1` 为明年)。 |
| | `addDuration(duration)` | 物理滑动推演，完美处理闰月等天文盲区。 |
| **快捷微调** | `nextDay() / previousDay()` | 快速翻转日期。 |
| | `nextHour() / previousHour()` | 切换时辰，自动处理跨天逻辑。 |
| **状态工具** | `reset()` | 彻底重置所有时间标记，回退到原局。 |
| | `getFullManifest()` | 一键获取包含大限、流年、流月所有节点的 JSON 结构。 |

### 💫 查看流运盘

当你决定了要看哪一个月或哪一天的盘时，将时间交给 `ZiweiLimitManager`：

```dart
final manager = ZiweiLimitManager(plate);

// 1. 设置到某个时间点 (如 2024年3月15日)
manager.setPhysicalDate(DateTime(2024, 3, 15));

// 2. 此时获取的即为该时刻的动态盘 (包含该时间对应的流年、流月星曜与四化)
final dynamicPlate = manager.dynamicPlate;

// 3. 也可以获取一键全家桶 JSON
final manifest = manager.getFullManifest();
print(manifest.toJson()); 
```

---

## 4. 更多示例
- [ ] 如何自定义星曜规则？
- [ ] 如何处理早晚子时切换？
- [ ] 如何开启历史考据模式？

详情请参阅 [API & JSON 开发指南](./API_AND_JSON_GUIDE.md)。
