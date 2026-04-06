## 0.12.9

- **[流时修复]** 修复区分早晚子时时，时间轴末尾晚子节点的天干始终按次日计算的问题，现已正确区分 `todayGan` 与 `tomorrowGan` 两种模式。
- **[时间轴语义]** 保留晚子节点为独立流时入口，便于上层应用正确显示“早子/晚子”并避免把晚子误当普通 `12` 号时辰处理。

## 0.12.8

- **[状态污染修复]** 修复静态星曜实例在多次重排盘过程中被重复复用的问题，避免 `selfSiHua / centripetalSiHua / siHuaBuff` 回写污染规则模板。
- **[排盘稳定性]** 修复紫微盘在切换上下时辰、上下日期后再回退时，自化小箭头可能错乱的回归问题。

## 0.12.7

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.18.4`，`bazi_core` 至 `^0.6.5`。
- **[历法修复]** 同步底层 `LunarDate` 在公元前古历区间与公元后历史改历时期的农历归年修复，进一步稳定流月到流日的时间轴衔接。

## 0.12.6

- **[依赖升级]** 切回远程依赖 `sxwnl_spa_dart ^0.18.3`，移除本地调试用 `dependency_overrides`。
- **[BCE 修复]** 正式同步底层 BCE 农历归年修复，恢复公元前流月全年展开流日。
- **[测试补充]** 保留 BCE 流日时间轴回归测试，覆盖 `-100` 年 12 个流月全部可展开流日的场景。

## 0.12.5

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.18.3`。
- **[BCE 修复]** 同步底层 `LunarDate.fromString()` 对 BCE 年内前段月份的归年修复，恢复公元前流月全年展开流日。
- **[测试补充]** 保留 BCE 流日时间轴回归测试，覆盖 `-100` 年 12 个流月全部可展开流日的场景。

## 0.12.4

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.18.2`。
- **[BCE 修复]** 同步底层 `LunarDate.fromString()` 的 BCE 归年修复，恢复公元前流月到流日的正常衔接。
- **[测试补充]** 新增 BCE 流日时间轴回归测试，覆盖 `-100` 年流月逐月展开流日的场景。

## 0.12.3

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.18.1`，`bazi_core` 至 `^0.6.3`。
- **[兼容修复]** 对齐底层 `LunarDate` 天文纪年重大修复与历史纪年辅助 API，确保 BCE 场景下紫微日期与八字日期语义一致。

## 0.12.2

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.18.0`，`bazi_core` 至 `^0.6.2`，适配天文纪年 breaking change。

## 0.12.1

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.17.0`，`bazi_core` 至 `^0.6.1`。

## 0.12.0

- **[功能增强]** 重构 `ConfigLoader.overrideWith` 亮度表覆盖逻辑，支持分层结构化配置（`brightness_labels`/`static_stars`/`flow_stars`）。
- **[健壮性]** 新增亮度表格式校验，确保必须为12个整数的数组。
- **[健壮性]** 星曜和流曜覆盖时现在使用深拷贝，避免污染基础规则集对象。

## 0.11.0

- **[依赖升级]** 升级 `sxwnl_spa_dart` 至 `^0.16.0`，`bazi_core` 至 `^0.6.0`，对齐 OpenDestiny 0.1.0 发布。
- **[工程化]** 将 `sxwnl_spa_dart` 和 `bazi_core` 依赖从本地路径 (`path`) 切换为 pub.dev 云端版本，正式支持独立发布。
- **[元数据]** 完善 `pubspec.yaml`：新增 `issue_tracker`、`topics` 以提升 pub.dev 评分与可发现性。

## 0.10.0

- 新增天地人盘支持：`ZiweiEngine.calculate` 新增可选参数 `tdrPan`，支持天盘（默认）、地盘（身宫为命宫）、人盘（福德宫为命宫）。
- 新增 `TDRpan` 枚举（`tianPan` / `diPan` / `renPan`）。
- `ZiWeiPlate` 新增 `tdrPan` 字段。
- 升级依赖 `bazi_core` 至 `^0.4.5`，`sxwnl_spa_dart` 至 `^0.15.1`。

## 0.9.3

- 优化文档：修复 README 及示例代码中 JSON 规则注入的格式错误（`param` → `anchor`, `mapping` → `table`）。

## 0.9.2

- 升级依赖 `bazi_core` 至 `^0.1.3`
- 升级依赖 `sxwnl_spa_dart` 至 `^0.10.0`
- 修复因 `bazi_core` 模型文件重构导致的内部引用路径问题。

## 0.9.1

- 修复 pub.dev 目录命名问题（`docs` 重命名为 `doc`）。
- 在主入口导出 `sxwnl_spa_dart` 的 `Location` 类。

## 0.9.0

- 首次公开发布至 pub.dev。
- 完整支持原局静态排盘（`ZiweiEngine.calculate`）。
- 有状态流运管理器（`ZiweiLimitManager`），支持大限、流年、流月、流日、流时。
- 无状态时光机排盘（`TimeMachine.travel`）。
- 完整支持自定义规则集与历法 JSON 热补丁注入（`ConfigLoader`）。
- 集成高精度天文历法，支持约 6000 年时间跨度（基于 `sxwnl_spa_dart`）。
