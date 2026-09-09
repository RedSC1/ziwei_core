# 验证与参考数据

## 当前测试

`dart test` 覆盖：

- 480 组手动安星快照：年干支独立输入、缺失规则、命身宫、五行局、四化与三种盘式。
- 27 组出生历法锚点：历史日期、闰月、子时和三档气朔精度。
- 21 组完整出生盘及每组连续修改、更新五行局、命宫平移、再次修改与复原。
- 序号边界、报数映射、随机拒绝采样、60 个干支年组合的序号展开。
- 9 组完整物理流盘，10 个现代/历史年度的月份与日列表。
- 自定义星曜、四化、JSON 规则和 20 个非默认规则变体。
- C++ 冻结参考数据的 1,200 组本命/流盘组合，覆盖 5 个流层 × 10 干 × 12 支 × 2 性别。
- 8 组 civil/true-solar、统一子时/分子时、直接/逐时辰反查的 JS 对拍。
- 管理器层级清空、童限、闰月分段、早晚子时步进、世纪范围反查、异常配置和不可变状态。

C++ 夹具直接复制自 JS 包的 `test/fixtures/flows-cpp.json`，文件内保留原参考程序与适配器 SHA-256。本次使用冻结数据，**未重新构建或运行 C++ 仓库**。JS 对拍证明移植一致性，不能代替对传统规则本身的独立判断。

## 重建 JS 夹具

先在 JS 仓库构建 `ziwei-lite`，然后在本包目录执行：

```sh
node tool/import_js_rules.mjs /path/to/taiyin-lite
node tool/generate_parity.mjs /path/to/taiyin-lite
node tool/generate_extra_parity.mjs /path/to/taiyin-lite
dart format lib/src/generated
```

输出由明确的固定输入生成，测试不需要 Node 或网络。修改规则数据后应重新对拍，并审查差异，不能只替换期望值。

## 跨运行时

`tool/portable_check.dart` 不使用 `dart:io`，验证真实盘、流盘、BigInt 高位星集合、随机拒绝采样及大整数报数。分别用 Dart VM 和 dart2js 编译后的 Node 运行，比较完整输出。

```sh
dart run tool/portable_check.dart > /tmp/ziwei-vm.json
dart compile js tool/portable_check.dart -o /tmp/ziwei-check.js
node /tmp/ziwei-check.js > /tmp/ziwei-js.json
cmp /tmp/ziwei-vm.json /tmp/ziwei-js.json
```

快照中整数、星位、宫位和变换标记逐项比较；浮点历法时刻容许 1e-8 天的差值，虚拟时钟的秒字段容许 1e-4 秒。跨运行时检查还要求选定用例的整份输出逐字一致。
