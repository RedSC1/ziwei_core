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
