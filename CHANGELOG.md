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
