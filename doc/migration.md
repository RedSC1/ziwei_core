# 迁移说明

本分支从 `js-ephemeris-lite` 仓库的 `packages/ziwei` 移植，参考提交 `f4fbcb5`。沿用 `RedSC1/ziwei_core` 仓库和包名；旧 main 不受本 worktree 的改动影响。

## 已覆盖的功能

出生历法解析与锚点、完整本命盘、内置变体与自定义规则、庙旺与四化、流盘与运限、历史时间线与管理器、修改/平移/复原、手动/序号/报数/随机起盘、有限范围反查。测试同时使用 JS 快照和已冻结的 C++ 参考数据。

不存在等待实现的旧依赖适配层；新运行时只依赖 `ephemeris_lite`。本次没有移植旧 Dart UI、FFI 或旧版对象生命周期，也不要求旧 API 原样兼容。

## Dart API 的调整

- 配置与坐标采用构造函数的命名参数；枚举采用 Dart 命名。
- `toJSON()` 为 `toJson()`，规则模块的 `with()` 为 `withModule()`，配置的 `with()` 为 `copyWith()`。
- `options.rules.copyWith(...)` 深度合并规则选择映射；把结果传给 `options.copyWith(rules: ...)`。
- 共享底层历法选项放在 `ZiweiOptions.calendarOptions`。例如 `CalendarOptions(eventAccuracy: Accuracy.accurate)`。
- `ResolvedZiweiBirth` 将历法事实和出生解析结果放在一个类型中，不重复嵌套 JS 的 `facts` 对象。`chart.facts` 仍保留全部出生事实。
- `modify` 接收 `ZiweiModifyInput`。可选参数不提供即沿用原值；`reset()` 返回最初的对象。
- 小限落宫查询用 `smallLimit: true`，不在同一个参数里混合字符串与 `FlowLevel`。
- `dynamicChartForTime` 返回 Dart record；宫位星集合采用 `BigInt`，JSON 输出用星曜数组。
- JSON 快照字段与盘面数据尽量对齐 JS；`options` 使用 Dart 枚举名并显式保存可选空值，不承诺配置 JSON 可不经转换直接跨语言反序列化。
- 报数允许 `int`、`BigInt` 或十进制字符串；超过 JS 安全整数范围时用后两种。默认随机来源为 `Random.secure()`，缺少安全来源的平台可显式注入 uint32 生成器。

## 边界与安全

修改盘的生日、原始四柱、命身主、宫干保持不变。更新五行局会重算起运年龄；只平移命宫不改变星位和年龄。起盘类不继承出生盘，避免将无法定义的运限包装为 null 方法。

运行时 JSON 规则最多嵌套 128 层，编译表限制两百万格，防止不可信配置引起无限增长。命中反查公式所用星曜的自定义模块会禁用直接反解，转为有限区间验证；这避免用默认公式筛掉自定义规则的结果。管理器物理步进失败时保留原状态。

## 尚未进行的发布工作

功能移植已落地，但本分支未发布或合并。正式升级前需迁移真实应用调用点、选定公开依赖版本、确认新版本号与发布策略。目前保持 `publish_to: none` 和本地 sibling path 依赖；这不是可直接提交 pub.dev 的配置。
