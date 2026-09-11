# 迁移说明

本分支从 `js-ephemeris-lite` 仓库的 `packages/ziwei` 移植，参考提交 `f4fbcb5`。沿用 `RedSC1/ziwei_core` 仓库和包名；旧 main 不受本 worktree 的改动影响。

## 已覆盖的功能

出生历法解析与锚点、完整本命盘、内置变体与自定义规则、庙旺与四化、流盘与运限、历史时间线与管理器、修改/平移/复原、手动/序号/报数/随机起盘、有限范围反查。测试同时使用 JS 快照和已冻结的 C++ 参考数据。

不存在等待实现的旧依赖适配层；新运行时只依赖 `ephemeris_lite`。本次没有移植旧 Dart UI 或旧版对象生命周期，也不要求旧 API 原样兼容。

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

## `TimePack` 的替代方式

旧版通过 `bazi_core` 的 `TimePack` 同时承载钟表时间、UTC、真太阳时和排盘钟表。
新版直接使用 `ephemeris_lite` 的时间类型，并将时间策略放入 `ZiweiOptions`：

```dart
final clock = ZonedTime(
  year: 2026,
  month: 2,
  day: 18,
  hour: 12,
  offsetMinutes: 480,
);
final options = ZiweiOptions(
  gender: ZiweiGender.male,
  calendarOptions: CalendarOptions(utcOffsetMinutes: 480),
  clockMode: ZiweiClockMode.trueSolar,
  longitudeDeg: 116.4074,
  ratHourMode: RatHourMode.nextDay,
);
final chart = ZiweiChart.fromZonedTime(clock, options);

final instant = clock.toJulianTime();
final utc = instant.toZonedTime(0);
final apparentSolarClock = trueSolarTime(clock, 116.4074);
final chartClock = chart.facts.chartTime;
```

`ZonedTime` 负责“某个固定时区的墙上时间”，`JulianTime` 表示物理瞬间，
`chart.facts.chartTime` 是排盘采用的民用／平太阳／真太阳钟面；`virtualTime` 暂作兼容别名。旧 `timezone: 8`
现在写作 `offsetMinutes: 480`。旧 `location` 对排盘太阳时实际使用的是经度，因此新版在
`longitudeDeg` 中单独声明；纬度不参与此换算。

新版默认 `ZiweiClockMode.civil`。旧版 `TimeAdapter` 与 `ZiweiDate` 的公历、农历入口默认
启用真太阳时；要保持旧行为，必须像上例一样显式设置 `trueSolar` 和经度。

## 边界与安全

修改盘的生日、原始四柱、命身主、宫干保持不变。更新五行局会重算起运年龄；只平移命宫不改变星位和年龄。起盘类不继承出生盘，避免将无法定义的运限包装为 null 方法。

运行时 JSON 规则最多嵌套 128 层，编译表限制两百万格，防止不可信配置引起无限增长。命中反查公式所用星曜的自定义模块会禁用直接反解，转为有限区间验证；这避免用默认公式筛掉自定义规则的结果。管理器物理步进失败时保留原状态。

## 发布与升级

`1.0.0-beta.1` 已改用公开发布的 `ephemeris_lite`。从 `0.13.x` 升级时需要迁移真实应用调用点；
新版不提供旧对象生命周期、配置加载器或依赖链的兼容包装。
