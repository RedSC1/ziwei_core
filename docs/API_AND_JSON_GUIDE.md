# 紫微斗数排盘引擎 (Ziwei Core) - API 与 JSON 配置指南

本指南主要面向希望将 `ziwei_core` 算力集成到 Web/客户端/Serverless 的工程师，或是希望自定义排盘流派规则的命理研究者。

---

## 一、 核心架构哲学

`ziwei_core` 采用 **“数据与逻辑极度解耦”** 的流水线设计（Pipeline Pattern）。
引擎不包含任何业务层的硬编码汉字或固定推演表，所有的安星逻辑、四化变化全部来源于 `JSON` 配置的注入。

- **核心动作**： `(生辰 + 历法配置) -> 引擎 (查 JSON 表) -> 纯英文 Key 的游标字典树 (JSON)`
- **主要优势**： 
  1. 瞬间零成本支持前端 i18n 多语言无缝切换。
  2. 实现流派高度定制（如三合派、飞星派、中州派等，只需一套代码核心，换不同的 JSON 配置载入即可）。

---

## 二、 基础 API 调用指南

要使用本引擎算出某个生辰的命盘，主要分为四步：

### 1. 载入规则上下文 (ConfigLoader)
引擎需要世界观规则，使用 `ConfigLoader` 读取 `assets/config/` 下的文件作为基础骨架：
```dart
import 'package:ziwei_core/ziwei_core.dart';

// 获取默认打包的排盘规则字典
final ruleset = ConfigLoader.getDefault();
```

### 2. 构造历法基底 (ZiweiDate)
所有物理时间戳进入引擎前，必须通过 `ZiweiDate` 降维，支持直接从农历或阳历载入。
```dart
import 'package:bazi_core/bazi_core.dart'; // 用于 Gender (Male/Female)

// 从阳历实例化 (自动兼容早晚子时、真太阳时、复杂闰月拆分等，均受 ruleset 内历法影响)
final birthTime = DateTime(2003, 8, 28, 2, 30);
final zDate = ZiweiDate.fromSolar(birthTime, gender: Gender.male);
```

### 3. 生成大底盘 (ZiweiEngine)
直接把时间投入主副引擎计算：
```dart
// 这里的 plate 本质是个只读静态巨型对象
final ZiWeiPlate plate = ZiweiEngine.calculate(zDate, ruleset);
```

### 4. 时空漫游获取当前流运切片 (TimeMachine)
对于需要展示流年大运的 UI：
```dart
// 时光穿梭：获取 2026年 5月 的全四柱游标切片
final limitContext = TimeMachine.travel(
  plate, 
  year: 2026, 
  month: 5
);
```

### 5. 交给系统网络层或 UI 层映射 (toJson)
这是本架构最迷人的设计，你只需要：
```dart
final jsonOutput = {
  "base_plate": plate.toJson(),
  "flow_context": limitContext.toJson(),
};

// 扔给网络 Socket 或是本地 JSON 持久化，前端只会拿到毫无计算压力的纯标识符字典树
print(jsonEncode(jsonOutput));
```

---

## 三、 输出结果 JSON 结构剖析

为了达到最大解析效率和零中文污染，JSON 的树节点规范如下：

### 1. Base Plate (原命盘原局结构)
```json
{
  "meta": {
    "element_bureau": "earth5", // 五行局，例如 earth5/wood3/fire6
    "effective_year": 1999,     // 系统自动纠正后真实的排盘历法生效年份
    "ming_zhu": "pojun",        // 命主星
    "shen_zhu": "tiantong"      // 身主星
  },
  "time_cursors": {
    "origin_ming": 11,          // 原局命宫落在的【地支绝对索引】(0=子, 11=亥)
    "body_palace": 1            // 身宫落在的【地支绝对索引】
  },
  "palaces": [                  // 固定的 12 个对象
    {
      "index": 0,
      "branch": "zi",
      "stem": "jia",
      "stars": {                // 前端福音：所有星曜已按性质强行分组装载
        "major": [ ... ],       // 14单星列表
        "lucky": [ ... ],       // 辅曜/吉星列表
        "minor": [ ... ]        // 煞曜/杂曜以及所有神煞流曜
      }
    }
    // ...
  ]
}
```

### 2. 星曜结构 (Star)
遇到 `ZweStar` 的输出都是这个形状：
```json
{
  "key": "tianji",           // 唯一英文名
  "type": "major",           // 大类标签
  "brightness": "level_ping", // 若有亮度，必为 level_xxx 
  "sihua": {                 // 非常干净的四化投影字典，前端遇此即可直接在星标旁加个“科/忌”的 Tag
    "origin": "lu",          // 生年引发它化禄
    "decade": "quan",        // 大限引发它化权
    "centrifugal": "ji",     // 离心自化忌 (本宫天干引发它化忌)
    "centripetal": "ke"      // 向心自化科 (对宫天干撞迫引发它化科)
  }
}
```

### 3. 流运切片 (Limit Context)
时光机的 `toJson` 输出，它不会把上面的整个重型盘再复制一遍，而是只抛出 **游标结构**：
```json
{
  "decade": {
    "type": "decade",
    "stem": "xin",
    "branch": "wei",        // 告诉前端：大限走到了未(Wei)宫，请点亮那个格子
    "role": "career",       // 告诉前端：这个大限把未宫照成了流运官禄宫
    "startTime": 22,
    "endTime": 31
  },
  "flow_year": {
    "type": "flow_year",
    "stem": "bing",
    "branch": "wu",         // 告诉前端：流年走到了午(Wu)宫，画个红框
    "role": "travel",
    "year": 2026
  }
  // 如果输入了流月与流日数据，同理也会包含 "flow_month", "flow_day" 游标
}
```

### 4. 导航条日历骨架 (Timeline Manifest)
为了解决前后端彻底分离后“前端无法计算干支历法”的痛点，建议在 JSON 尾部附带 `timeline_manifest` 数据：
```json
"timeline_manifest": {
  "decades": [
    {
      "index": 1,
      "start_age": 2,
      "end_age": 11,
      "start_year": 2004,
      "end_year": 2013,
      "stem": "xin",
      "branch": "you"
    }
    // ...共 12 个大限
  ],
  "current_year_months": [
    {
      "month": 1,
      "stem": "geng",
      "branch": "yin"
    }
    // ...共 12 个流月
  ]
}
```
通过附带这个极小的数据块（约 `2KB`），前端就能毫无波澜地画出底部的“大限滑动条”和“流月点选器”了。

---

## 四、 高级自创流派指南 (编写规则 JSON)

如果你对命理的推算法则不满意（比如你所在门派认为“太阴”在子时不属于“庙”而是“平”），**请不要动任何 `.dart` 源码**。本引擎通过 JSON 提供最高级别的流派拦截（Patch）机制。

所有源文件存在于：`assets/config/default/`。

### 核心可修补文件

1. **`main_rules.json` (引擎物理宇宙规则)**
   - 控制全引擎的通用数学计算规律。
   - `brightness_labels` 包含了所有引擎认可的亮度值 Enum (比如 `10:庙`)。
   - `calendar` 包含了引擎时间拆解规则（`split_rat_hour`: 是否拆分早晚子，`childhood_decade`: 未起运的童限推算法则）。

2. **`stars.json` (极重磅：星系总排布宪法)**
   在这个文件里定义了一切星星该如何根据原局密码计算位置！
   - 支持强大的抽象 DSL 语法规则查询。如 `locator: "basic"` 或 `locator: "month"`。
   - 你通过修改里面的数组元素（如下方的 `brightness_table`），可以直接窜改任何一颗星星在 12 地支上的表现值！
   ```json
   "wenchang": {
      "type": "lucky",
      "locator": "time",     // 使用生时寻址
      "route": "shun",       // 顺数推演
      "start_index": 10,     // 从戌宫起数
      "brightness_table": [10, 8, 5, 5, 8, 10, 5, 5, 8, 8, 5, 10] // 子丑寅卯...
   }
   ```

3. **`sihua.json` (四化飞星表)**
   里面定义了 `jia` (甲天干) 究竟引发的是哪几颗星的 禄、权、科、忌。例如中州派可能认为庚干是“太阴化忌”，而飞星派认为是“天同化忌”，你仅需在这个字典将 `geng -> ji` 的键值更改即可。

### 动态补丁接口技术：Override (热加载)
要在运行时打上某部分流派补丁，不需要重做 JSON，而是利用基底进行 Deep Merge 补丁：

```dart
final baseRuleset = ConfigLoader.getDefault();

// 比如我只针对四化流派不认可，其他的排盘机制我全盘吸收
final mySchoolSihua = '''
{
  "lu": {
    "jia": "lianzhen",
    // 你的私服规则...
  }
}
''';

// 通过 overrideWith 派生出一套变异体规则，交给引擎
final variantRuleset = ConfigLoader.overrideWith(
  baseRuleset,
  sihuaJson: mySchoolSihua
);

// 生成出来的盘，所有的四化系统将全部变成你自定义的样式
final customPlate = ZiweiEngine.calculate(zDate, variantRuleset);
```

这就是 `ziwei_core` 最可怕的设计理念，开发者不仅在写一个命盘工具，更在建立一个关于时间、方位与星曜投射的开放物理沙盒！
