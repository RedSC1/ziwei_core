# JSON 字段值速查手册

本文档列出所有 JSON 配置文件中可使用的值，供编写自定义规则集时查阅。

配置文件的整体结构和加载方式详见 [配置文件说明](./03_config_file.md)。

---

## 1. `stars.json` / `flow_stars.json` — 安星规则字段

### `type`（星体分类）

星体在命盘中的分组归属。

| 值 | 说明 |
| :--- | :--- |
| `major` | 14 主星（紫微、天机、太阳...） |
| `lucky` | 六吉星及禄马（辅弼昌曲魁钺、禄存、天马） |
| `bad` | 六煞星（羊陀火铃空劫） |
| `minor` | 乙级及杂曜（红鸾、天喜、天刑、天姚、三台、八座、龙池、凤阁等，目前除主星/吉煞/十二神外的星曜均归此类） |
| `boshi12` | 博士十二神（跟禄存） |
| `suijian12` | 岁建十二神（跟太岁） |
| `jiangqian12` | 将前十二神 |
| `changsheng12` | 长生十二神（跟五行局） |
| `other` | 兜底分类（目前未使用） |
| `flow` | 流曜（动态星） |

### `rule.type`（安星规则类型）

| 值 | 别名 | 说明 |
| :--- | :--- | :--- |
| `anchor_offset` | — | 以某颗锚点星或时间参数为基准，顺/逆偏移若干宫 |
| `lookup` | — | 按年干/年支等查表，直接定位到某宫 |
| `lookup_offset` | `lookup_shift` | 查表后再叠加第二个锚点的偏移量 |
| `constant` | — | 固定数值（常用于 `pipeline` 的子步骤） |
| `pipeline` | — | 将多个规则串联执行，结果累加取模（复合规则） |

### `rule.anchor`（锚点）

锚点决定了安星计算的数据来源。引擎会根据 `boundary` 自动选择农历/节气版本。

| 值 | 类型 | 说明 |
| :--- | :--- | :--- |
| `ziwei` | int | 紫微星所在宫位索引 |
| `tianfu` | int | 天府星所在宫位索引 |
| `ming` | int | 命宫索引 |
| `body` | int | 身宫索引 |
| `year_stem` | string | 年天干（如 `"jia"`），受 `boundary` 影响取农历年干或八字年干 |
| `year_branch` | string | 年地支（如 `"zi"`），受 `boundary` 影响 |
| `month_stem` | string | 月天干 |
| `month_branch` | string | 月地支 |
| `month` | int | 月份数值，lunar→有效月份 / solar→节气月 |
| `hour` | int | 时辰索引 |
| `day` / `day_number` | int | 日数 |
| `year` | int | **物理年份原始值**（如 `2003` 就是 `2003`）。用于 `anchor_offset` 时会经过 `fixIndex`（mod 12）取模，效果等价于年份地支索引 |
| `zheng_kong` | int | 正空亡位 |
| `fu_kong` | int | 副空亡位 |

> [!TIP]
> 你还可以使用任何已安放的**星曜 key** 作为锚点（如 `"lucun"`），引擎会读取该星的当前宫位索引。
>
> 完整的 anchor 可选值列表请参考源码 `lib/src/core/star_locator.dart`。

### `rule.direction`（偏移方向）

| 值 | 说明 |
| :--- | :--- |
| `1`（或省略） | 顺行 |
| `-1` 或 `"ni"` | 逆行 |
| `"gender_shun_ni"` | 阳男阴女顺行，阴男阳女逆行 |

### `rule.boundary`（历法基准）

| 值 | 说明 |
| :--- | :--- |
| `"lunar"`（默认） | 使用农历参数 |
| `"solar"` | 使用节气/八字参数 |

---

## 2. `sihua.json` — 四化字段

### 天干 key

| key | 天干 |
| :--- | :--- |
| `jia` | 甲 |
| `yi` | 乙 |
| `bing` | 丙 |
| `ding` | 丁 |
| `wu` | 戊 |
| `ji` | 己 |
| `geng` | 庚 |
| `xin` | 辛 |
| `ren` | 壬 |
| `gui` | 癸 |

### 四化类型 key

| key | 四化 |
| :--- | :--- |
| `lu` | 化禄 |
| `quan` | 化权 |
| `ke` | 化科 |
| `ji` | 化忌 |

四化的值为**星曜 key**（见下方星曜 key 速查表）。

---

## 3. `main_rules.json` — 历法开关

| 字段 | 类型 | 可用值 | 说明 |
| :--- | :--- | :--- | :--- |
| `split_rat_hour` | bool | `true` / `false` | 是否区分早晚子时 |
| `leap_month_strategy` | string | `"split"` / `"current"` / `"as_next"` | `split`=15日前后分属，`current`=全算上月，`as_next`=全算下月 |
| `wu_hu_dun_boundary` | string | `"lunar"` / `"solar"` | 五虎遁推宫干的历法基准 |
| `sihua_boundary` | string | `"lunar"` / `"solar"` | 生年四化的历法基准 |
| `childhood_decade` | string | `"skip"` / `"regular"` | `skip`=口诀跳跃派，`regular`=一年一格顺延派 |
| `flowLimit_boundary` | string | `"lunar"` / `"solar"` | 流月/流日的分界线 |
| `enable_historical` | bool | `true` / `false` | 是否开启历史历法保护 |

`brightness_labels` 的 key 为整数字符串（如 `"6"`），value 为自定义标签字符串（如 `"level_miao"`）。特殊 key `-1` 表示无亮度标签。

---

## 4. `masters.json` — 命身主

命主和身主的查表规则由引擎硬编码处理，不经过 `StarLocator`：

- **命主** (`ming_zhu`)：以**命宫地支索引**（0=子, 1=丑...）查表
- **身主** (`shen_zhu`)：以**年地支索引**（0=子, 1=丑...）查表，`boundary` 决定取农历年支还是节气年支

| 字段 | 位置 | 可用值 | 说明 |
| :--- | :--- | :--- | :--- |
| `boundary` | `shen_zhu` | `"lunar"` / `"solar"` | 历法基准（可选，默认 `"lunar"`） |
| `table` | 两者皆有 | `{ "0": "星曜key", ... }` | 地支索引（0–11）→ 星曜 key |

---

## 5. 星曜 key 速查

以下为默认规则集中使用的星曜 key。自定义规则集可使用任意 key，只要在 `stars.json`、`sihua.json`、`brightness.json` 之间保持一致即可。

### 14 主星

| key | 星名 | key | 星名 |
| :--- | :--- | :--- | :--- |
| `ziwei` | 紫微 | `tianji` | 天机 |
| `taiyang` | 太阳 | `wuqu` | 武曲 |
| `tiantong` | 天同 | `lianzhen` | 廉贞 |
| `tianfu` | 天府 | `taiyin` | 太阴 |
| `tanlang` | 贪狼 | `jumen` | 巨门 |
| `tianxiang` | 天相 | `tianliang` | 天梁 |
| `qisha` | 七杀 | `pojun` | 破军 |

### 吉星、煞星与禄马

| key | 星名 | key | 星名 |
| :--- | :--- | :--- | :--- |
| `zuofu` | 左辅 | `youbi` | 右弼 |
| `wenqu` | 文曲 | `wenchang` | 文昌 |
| `tiankui` | 天魁 | `tianyue` | 天钺 |
| `lucun` | 禄存 | `tianma` | 天马 |
| `qingyang` | 擎羊 | `tuoluo` | 陀罗 |
| `huoxing` | 火星 | `lingxing` | 铃星 |
| `dikong` | 地空 | `dijie` | 地劫 |

### 其他常用星

完整列表如下（共 38 颗）：

| key | 星名 | key | 星名 |
| :--- | :--- | :--- | :--- |
| `hongluan` | 红鸾 | `tianxi` | 天喜 |
| `tianxing` | 天刑 | `tianyao` | 天姚 |
| `tianguan` | 天官 | `tianfu_minor` | 天福 |
| `jiekong` | 截空 | `xunkong` | 旬空 |
| `tiancai` | 天才 | `tianshou` | 天寿 |
| `feilian` | 蜚廉 | `posui` | 破碎 |
| `santai` | 三台 | `bazuo` | 八座 |
| `enguang` | 恩光 | `tiangui` | 天贵 |
| `tiande` | 天德 | `yuede` | 月德 |
| `longchi` | 龙池 | `fengge` | 凤阁 |
| `tiankong` | 天空 | `tianku` | 天哭 |
| `tianxu` | 天虚 | `huagai` | 华盖 |
| `xianchi` | 咸池 | `guchen` | 孤辰 |
| `guasu` | 寡宿 | `taifu` | 台辅 |
| `fenggao` | 封诰 | `yinsha` | 阴煞 |
| `tianwu` | 天巫 | `tianyue_minor` | 天月 |
| `tianchu` | 天厨 | `jieshen` | 解神 |
| `nianjie` | 年解 | `dahao` | 大耗 |
| `tianshang` | 天伤 | `tianshi` | 天使 |
| `fuxun` | 副旬 | `fujie` | 副截 |
