## 0.9.3

- 优化文档：修复 README 及示例代码中 JSON 规则注入的格式错误（`param` → `anchor`, `mapping` → `table`）。
- Docs: Fixed JSON rule injection format errors in README and examples (`param` → `anchor`, `mapping` → `table`).

## 0.9.2

- 升级依赖 `bazi_core` 至 `^0.1.3`
- 升级依赖 `sxwnl_spa_dart` 至 `^0.10.0`
- 修复因 `bazi_core` 模型文件重构导致的内部引用路径问题。

## 0.9.1

- Fixed pub.dev directory naming issue (renamed `docs` to `doc`).
- Exported `Location` class from `sxwnl_spa_dart` in main entry.

## 0.9.0

- Initial public release on pub.dev.
- Complete support for static chart generation (`ZiweiEngine.calculate`).
- Stateful lifecycle tracking (`ZiweiLimitManager`) for decade, year, month, day, and hour.
- Stateless, direct time-travel chart generation (`TimeMachine.travel`).
- Full support for custom rulesets and calendar patch injections via JSON (`ConfigLoader`).
- High-precision ephemeris integration supporting a 6000-year timespan (via `sxwnl_spa_dart`).
