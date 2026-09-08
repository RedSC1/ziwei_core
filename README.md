# ziwei_core

[English](README_EN.md)

纯 Dart 紫微斗数核心。以 `ziwei-lite` 为源实现，提供出生盘、运限与流盘、时间线、规则配置、修改盘和无生日起盘；底层使用 `ephemeris_lite`，不依赖 FFI、`sxwnl_spa_dart` 或 `bazi_core`。

本次重写沿用 `RedSC1/ziwei_core` 仓库与包名。当前为开发分支，**尚未发布，不是旧版 0.13.0 的直接兼容升级**。旧版实现和授权保留在 Git 历史及原主分支中。

## 功能

- 公历时刻、农历日期或已经解析的历法信息排盘；天盘、地盘、人盘。
- 历史/现代历法、气朔 fast/mid/accurate、子时与闰月策略、平太阳时和真太阳时。
- 115 颗内置本命星、44 颗流曜；命身宫、五行局、庙旺、命身主、年四化、离心与向心自化。
- 大限、童限、小限、流年/月/日/时，历史月份时间线与联动选择管理器。
- 内置规则变体、JSON 规则编译、有序规则模块、自定义星曜与四化。
- 不改变原始生日的 `modify`、命宫平移、`reset`；可选择重新计算五行局与起运年龄。
- 无生日的 `ZiweiCastingChart`，支持手动坐标、序号回放、报数映射和随机采样。
- 星位条件反查，支持直接反解与有限区间逐时辰验证。

## 开发依赖

暂不发包。将两个仓库放在同一目录：

```text
workspace/
  ephemeris_lite/
  ziwei_core-next/
```

`pubspec.yaml` 当前通过 `../ephemeris_lite` 引用底层，`publish_to: none` 阻止误发布。接入应用时可用本地 path 依赖；正式发布前再确定版本与依赖地址。

## 出生盘

```dart
import 'package:ziwei_core/ziwei_core.dart';

final options = ZiweiOptions(
  gender: ZiweiGender.male,
  calendarOptions: CalendarOptions(eventAccuracy: Accuracy.mid),
);
final chart = ZiweiChart.fromZonedTime(
  ZonedTime(
    year: 2000, month: 1, day: 1, hour: 12,
    offsetMinutes: 480,
  ),
  options,
);
final life = chart.getPalace(Palace.life);
final ziwei = chart.getStarPosition(requireStarId('ziwei'));
final snapshot = chart.toJson();
```

`eventAccuracy` 控制底层定气定朔求解，不是给紫微安星算法增设精度档位。默认 `mid`，子时默认 `RatHourMode.nextDay`，闰月默认十五日后按下月处理。

平/真太阳时用 `clockMode` 与 `longitudeDeg` 配置；原始出生时刻与用于排盘的虚拟时钟分开保存。

## 修改与复原

```dart
final modified = chart.modify(ZiweiModifyInput(
  yearGanIndex: 9,
  yearZhiIndex: 7,
  month: 8,
  updateBureau: true,
));
final shifted = modified.shiftLifePalace(2);
final original = shifted.reset();
```

修改返回新盘。生日、出生历法事实、宫干与命身主不被覆写；年干、年支可以独立指定。缺少合法干支等输入的规则会列在 `omittedPlacements` 中。

`updateBureau` 默认关闭，打开后五行局和起运年龄随新输入改变。命宫平移只移动宫位角色与大限落宫，不移动星曜、身宫，也不改变起运时间。连续修改可一次 `reset()` 回到最初的盘。

## 运限与时间线

```dart
final manager = chart.createLimitManager();
manager.setYear(2023);
manager.setMonth(2, isLeap: true, effectiveMonth: 2);
manager.setDay(10);
manager.setHour(0);
final dynamicChart = manager.dynamicChart;
final manifest = manager.manifest;

manager.setPhysicalTime(
  ZonedTime(year: 2023, month: 5, day: 1, hour: 22,
    minute: 15, offsetMinutes: 480),
);
manager.nextHour();
```

`setMonth/setDay` 等按时间线选择；`nextHour/nextDay` 等物理步进需要先调用 `setPhysicalTime`。变更上层会清除下层。童限可以在选择流年之前单独选择。

## 无生日起盘

```dart
final casting = ZiweiCastingChart.fromInput(
  ZiweiPlacementInput(yearGanIndex: 9, yearZhiIndex: 7,
    month: 3, day: 14, hourZhiIndex: 4),
  options,
);
final reported = ZiweiCastingChart.fromNumber('123', options);
final random = ZiweiCastingChart.random(options);
final replay = ZiweiCastingChart.fromIndex(
  random.casting['index'] as int, options,
);
```

起盘类只提供盘面 API，不伪造生日或提供无法定义的年龄/运限。序号范围是 `0..259199`：60 个干支年组合 × 12 月 × 30 日 × 12 时支。随机方法用均匀 uint32 来源加拒绝采样，避免取模偏差；可注入随机来源。报数采用与 JS 一致的 `number-v1` 确定性映射，**不能把有偏的用户报数变成均匀随机分布**。

## 自定义规则

```dart
final ruleset = ZiweiConfigLoader.overrideWith(
  ZiweiRuleset(),
  label: 'custom',
  starsJson: '[{"key":"extra","type":"minor",'
      '"rule":{"type":"constant","value":4}}]',
);
final customOptions = options.copyWith(
  rules: options.rules.copyWith(ruleset: ruleset),
);
```

更多内容见 [API 对照](doc/api-map.md)、[迁移说明](doc/migration.md) 和 [验证说明](doc/testing.md)。示例位于 [example](example/)。

## 开发检查

```sh
dart pub get
dart analyze
dart test
dart run example/basic.dart
dart run example/advanced.dart
dart run tool/portable_check.dart
dart compile js tool/portable_check.dart -o /tmp/ziwei-check.js
node /tmp/ziwei-check.js
```

## 许可证

本重写分支移植自 `ziwei-lite`，采用 MPL-2.0。旧版 0.13.0 的代码仍以其发布时的 MIT 许可证为准；本次更改不改变旧版授权。底层依赖的第三方来源说明由 `ephemeris_lite` 维护。
