# Ziwei Core 快速上手指南 (Quick Start)

本指南将带你从零开始，在 5 分钟内使用本项目排盘

---

## 1. 安装与配置

在你的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  ziwei_core: ^1.0.0
```

运行 `dart pub get` 完成安装。

---

## 2. 基础排盘 (Primary Plate)

### 步骤 A：准备规则集
紫微斗数的安星规则极其复杂，我们预置了一套默认规则集。
```dart
final ruleset = ConfigLoader.getDefault();
```

### 步骤 B：定义时间与性别
```dart
final birth = ZiweiDate.fromSolar(
  AstroDateTime(1990, 5, 20, 14, 30),//这里也可以使用DateTime，但是不支持公元前的时间
  gender: Gender.female,
);
```

### 步骤 C：一键出盘
```dart
final plate = ZiweiEngine.calculate(birth, ruleset);
```

---

## 3. 流运推演 (Flow Timeline)

当需要看“今年运势”、“十年大运”或者“今日运势”时，`TimelineProvider` 是你的核心数据源。它负责将天文历法边界与命理解码逻辑相结合。

### 📊 获取年度清单 (Manifest)
你可以一键获取当前年份的所有关键节点，非常适合前端绘制时光轴。
```dart
final provider = TimelineProvider(plate);
final manifest = provider.generateManifest(2024);

print("历史红区状态: ${manifest['status']['is_historical_red_zone']}");
// list of FlowMonth objects for the year
final months = manifest['current_year_months']; 
```

### 🔍 精细化维度查询
你可以按需深入查询每一层的时间边界和干支：

```dart
// 1. 获取一生大限表 (120年)
final decades = provider.getDecades();

// 2. 获取指定年份的 12 个流月 (自动处理农历/节气交界)
final months = provider.getMonths(2024);

// 3. 获取指定月份的每一天 (流日)
// 返回包含阳历日期、日干支、交节时刻的详细数组
final days = provider.getDays(2024, 2); 
```

### 💫 查看流运盘
当你决定了要看哪一个月或哪一天的盘时，将时间交给 `ZiweiLimitManager`：

```dart
final manager = ZiweiLimitManager(plate);

// 锁定到 2024 年
manager.setYear(2024); 

// 此时获取的即为 2024 流年盘 (包含流年星曜、四化)
final yearPlate = manager.dynamicPlate;
```

---

## 4. 更多示例
- [ ] 如何自定义星曜规则？
- [ ] 如何处理早晚子时切换？
- [ ] 如何开启历史考据模式？

详情请参阅 [API & JSON 开发指南](./API_AND_JSON_GUIDE.md)。
