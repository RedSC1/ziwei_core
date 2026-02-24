## 0.9.0

- Initial public release on pub.dev.
- Complete support for static chart generation (`ZiweiEngine.calculate`).
- Stateful lifecycle tracking (`ZiweiLimitManager`) for decade, year, month, day, and hour.
- Stateless, direct time-travel chart generation (`TimeMachine.travel`).
- Full support for custom rulesets and calendar patch injections via JSON (`ConfigLoader`).
- High-precision ephemeris integration supporting a 6000-year timespan (via `sxwnl_spa_dart`).
