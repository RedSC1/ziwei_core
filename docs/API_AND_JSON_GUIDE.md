# Ziwei Core API & JSON 开发指南

本库是基于 Dart 开发的高精度紫微斗数排盘与流运计算引擎。本文档旨在帮助开发者快速掌握 API 调用逻辑及 JSON 交互规范。

---

## 1. 核心计算 API (`ZiweiEngine`)

`ZiweiEngine` 是整个库的入口，负责将输入日期转换为完整的紫微命盘对象。

### `ZiweiEngine.calculate(ZiweiDate date, Ruleset ruleset)`
- **ZiweiDate**: 输入的时间对象。支持真太阳时、经纬度配置。
- **Ruleset**: 规则集（流派配置）。包含安星、流运计算逻辑。

```dart
final date = ZiweiDate.fromSolar(DateTime.now());
final plate = ZiweiEngine.calculate(date, ConfigLoader.getDefault());
```

---

## 2. 流运推演 API (`TimelineProvider`)

这是我们最新版的核心模块，用于生成用于 UI 渲染的“时间线数据”。

### 生成概览摘要 (`generateManifest`)
返回当前年份下流限布局的摘要（包含大限列表、当前流年月份列表、历史熔断状态）。

### 详细表查询
除了摘要，你可以按需获取极高精度的详细表：
- `getDecades()`: 获取一生的 120 年大限表。
- `getYears(int decadeIdx)`: 获取指定大限内的 10 年流年表。
- `getMonths(int targetYear)`: 获取指定年份的 12 个流月（自动处理节气/农历边界）。
- `getDays(int year, int month)`: 获取一个月的日历及日干支。
- `getHours(GanZhi dayGanZhi)`: 获取某天的 12/13 个流时（含早晚子时）。

---

## 3. JSON 数据格式说明

为了方便前后端分离或跨语言调用，我们推荐使用 `Manifest` 结构作为导航核心。

### Manifest 结构示例
```json
{
  "decades": [...],
  "current_year_months": [
    {
      "month": 1,
      "stem": "丙",
      "branch": "寅",
      "solar_start": "2024-02-04 16:27:07",
      "solar_end": "2024-03-05 10:22:31"
    }
  ],
  "status": {
    "is_historical_red_zone": false,
    "note": "正常"
  }
}
```

---

## 4. 硬核特性指南

### 🛡️ 历史历法红区保护 (Historical Red Zones)
当 `enableHistorical` 为 `true` 时，引擎会自动监测历史历法突变期：
- **拦截区间**：公元前 721 年 - 前 104 年（先秦乱局）、王莽时期、魏明帝、武则天改历期。
- **行为**：流月/流日计算自动熔断，返回空列表，并在 `status.note` 中给出学术解释。

### 🕒 高精度节气流运 (Solar Boundaries)
系统提供秒级节气交割精度。在配置 `Boundary.solar` 时：
- 流月起点即为“立春、惊蛰...”的真实物理时刻。
- **历史鲁棒性**：采用“连续节令流水线”算法，完美解决儒略历万年平移导致的月份错位。

### 🐭 早晚子时支持
- 支持 23:00-01:00 的精准拆分。
- 在 `getDays` 和 `getHours` 中会自动处理跨天干支切换。

---

## 5. 常见问题 (FAQ)
- **为什么古代流月会返回空？** 请检查考据模式是否落入红区。
- **如何同步大限步进？** 建议使用 `ZiweiLimitManager` 进行状态管理。
