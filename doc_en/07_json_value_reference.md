# JSON Value Reference Dictionary

This document enumerates all permissible values across the JSON configuration files, acting as a lookup dictionary when authoring custom rulesets.

For sweeping structural explanations regarding these files, please consult the [Configuration File Guide](./03_config_file.md).

---

## 1. `stars.json` / `flow_stars.json` — Star Rule Fields

### `type` (Star Categorization)

Determines the foundational grouping a star belongs to on the chart.

| Value | Description |
| :--- | :--- |
| `major` | The 14 Major Stars (e.g., Ziwei, Tianji, Taiyang...) |
| `lucky` | The 6 Auspicious Stars + Lu/Ma (Zuo/You, Chang/Qu, Kui/Yue, Lucun, Tianma) |
| `bad` | The 6 Malefic Stars (Yang/Tuo, Huo/Ling, Kong/Jie) |
| `minor` | Minor/Auxiliary Stars (e.g., Hongluan, Tianxi, Tianxing, Tianyao, Santai, Bazuo, Longchi, Fengge. Currently, any stars not fitting the others default here).|
| `boshi12` | 12 Gods of Boshi (Follows Lucun) |
| `suijian12` | 12 Gods of Sui Jian (Follows Tai Sui / Flowing Year) |
| `jiangqian12` | 12 Gods of Jiang Qian |
| `changsheng12` | 12 Phases of Life (Follows the Heaven stems / Five Elements Bureau) |
| `flow` | Flowing dynamic limit stars |
| `other` | Abstract fallback (Unused by default) |

### `rule.type` (Placement Rule Archetype)

| Value | Alias | Description |
| :--- | :--- | :--- |
| `anchor_offset` | — | Employs a foundational anchor star or time metric, shifting forwards/backwards by an integer margin |
| `lookup` | — | Executes a table lookup yielding a direct target index |
| `lookup_offset` | `lookup_shift` | Executes a table lookup, then immediately stacks a secondary offset shift |
| `constant` | — | Absolute grid integer (Often deployed inside parallel `pipeline` steps) |
| `pipeline` | — | Strings multiple disparate rules chaining them consecutively into an aggregate location |

### `rule.anchor` (Base Anchors)

Anchors mandate the root coordinate the mathematical placement originates from. The engine parses Lunar/Solar properties automatically via your `boundary` configurations.

| Value | Type | Description |
| :--- | :--- | :--- |
| `ziwei` | int | The physical palace grid index occupied by the Ziwei star |
| `tianfu` | int | The physical palace grid index occupied by the Tianfu star |
| `ming` | int | Life Palace index |
| `body` | int | Body (Shen) Palace index |
| `year_stem` | string | Year Sky Stem (e.g., `"jia"`). Influenced by `boundary` grabbing Lunar or BaZi parameters |
| `year_branch` | string | Year Earthly Branch (e.g., `"zi"`). Influenced by `boundary` |
| `month_stem` | string | Month Sky Stem |
| `month_branch` | string | Month Earthly Branch |
| `month` | int | Literal numerical month. Lunar→Valid Lunar Month / Solar→Solar Term Month Sequence |
| `hour` | int | Chronological Hour index |
| `day` / `day_number` | int | The literal calendar day numerical |
| `year` | int | **The naked physical chronological year integer** (e.g. `2003` becomes `2003`). When run inside an `anchor_offset`, it undergoes a `fixIndex` (mod 12) becoming mathematically equivalent to a year branch index |
| `zheng_kong` | int | Zheng Kong Wang bounding position |
| `fu_kong` | int | Fu Kong Wang bounding position |

> [!TIP]
> You can additionally utilize **any valid Star Key** previously instantiated as an anchor (e.g., `"lucun"`), and the engine fetches that star's current palace index.

### `rule.direction` (Trajectory Vector)

| Value | Description |
| :--- | :--- |
| `1` (or omitted) | Clockwise |
| `-1` or `"ni"` | Counter-Clockwise |
| `"gender_shun_ni"` | Direction mimics Decade Flow: Yang Male/Yin Female go Clockwise, Yin Male/Yang Female go Counter-Clockwise |

### `rule.boundary` (Celestial Threshold)

| Value | Description |
| :--- | :--- |
| `"lunar"` (Default) | Targets lunar metric inputs |
| `"solar"` | Targets Solar Term / BaZi metric inputs |

---

## 2. `sihua.json` — SiHua (Four Transformers) Dictionary

### Sky Stem Index Keys

| Key | Stem |
| :--- | :--- |
| `jia` | Jia (甲) |
| `yi` | Yi (乙) |
| `bing` | Bing (丙) |
| `ding` | Ding (丁) |
| `wu` | Wu (戊) |
| `ji` | Ji (己) |
| `geng` | Geng (庚) |
| `xin` | Xin (辛) |
| `ren` | Ren (壬) |
| `gui` | Gui (癸) |

### SiHua Transformer Keys

| Key | SiHua |
| :--- | :--- |
| `lu` | Hua Lu (Wealth/Abundance) |
| `quan` | Hua Quan (Power/Authority) |
| `ke` | Hua Ke (Fame/Academics) |
| `ji` | Hua Ji (Obstacle/Annoyance) |

The payload values map perfectly back to **Star Keys** (e.g., mapping `"lu": "ziwei"` dictating Ziwei transforms into Lu).

---

## 3. `main_rules.json` — Configuration Toggles

| Field | Type | Options | Description |
| :--- | :--- | :--- | :--- |
| `split_rat_hour` | bool | `true` / `false` | Distinguish Early/Late Zi hour |
| `leap_month_strategy` | string | `"split"` / `"current"` / `"as_next"` | `split`=Divided by 15th, `current`=Counted to prev month, `as_next`=Counted to next month |
| `wu_hu_dun_boundary` | string | `"lunar"` / `"solar"` | Five-Tigers-Chasing base boundary |
| `sihua_boundary` | string | `"lunar"` / `"solar"` | SiHua Generation Base boundary |
| `childhood_decade` | string | `"skip"` / `"regular"` | `skip`=Rhythmic Jump Sect, `regular`=Annual Progress Sect |
| `flowLimit_boundary` | string | `"lunar"` / `"solar"` | Base calendar choice for boundary divisions impacting Flowing Months/Days |
| `enable_historical` | bool | `true` / `false` | Enable safeguards blocking erratic ancient calendar zones |

The `brightness_labels` object mandates keys formatted as integer strings (e.g., `"6"`), and values acting as your custom output tag payloads (e.g., `"level_miao"`). The paramount exception is `-1` dropping brightness assignments entirely.

---

## 4. `masters.json` — Ming & Body Masters

Retrieving Ming and Body master placements avoids the dynamic `StarLocator` and employs direct engine rigid mapping logic:

- **Ming Master** (`ming_zhu`): Probed via the **Ming Palace Earthly Branch Index** (0=Zi, 1=Chou...)
- **Shen (Body) Master** (`shen_zhu`): Probed via the **Year Earthly Branch Index** (0=Zi, 1=Chou...). The `boundary` controls whether it harvests Lunar or BaZi branches.

| Field | Location | Array / Options | Description |
| :--- | :--- | :--- | :--- |
| `boundary` | `shen_zhu` | `"lunar"` / `"solar"` | Base calendar choice (Defaults to `"lunar"`) |
| `table` | Present in Both | `{ "0": "StarKey", ... }` | Earthly Branch Index (0–11) mapped exclusively to Star Keys |

---

## 5. Universal Default Star Key Glossary

Below resides the pre-fabricated star keys running throughout the default shipped JSONs. Custom rulesets aren't bound to this list and may introduce limitless arbitrary keys, provided that nomenclature links correctly across `stars.json`, `sihua.json`, and `brightness.json` symmetrically.

### The 14 Major Protagonists

| Key | Translation | Key | Translation |
| :--- | :--- | :--- | :--- |
| `ziwei` | Zi Wei (Emperor) | `tianji` | Tian Ji (Advisor) |
| `taiyang` | Tai Yang (Sun) | `wuqu` | Wu Qu (Finance) |
| `tiantong` | Tian Tong (Lucky) | `lianzhen` | Lian Zhen (Diplomat) |
| `tianfu` | Tian Fu (Vault) | `taiyin` | Tai Yin (Moon) |
| `tanlang` | Tan Lang (Wolf) | `jumen` | Ju Men (Gate) |
| `tianxiang` | Tian Xiang (Minister)| `tianliang` | Tian Liang (Elder) |
| `qisha` | Qi Sha (Marshal) | `pojun` | Po Jun (Pioneer) |

### The Auspicious, Malefic, & Lu/Ma Clusters

| Key | Translation | Key | Translation |
| :--- | :--- | :--- | :--- |
| `zuofu` | Zuo Fu (Left Deputy) | `youbi` | You Bi (Right Deputy) |
| `wenqu` | Wen Qu (Arts) | `wenchang` | Wen Chang (Intellect) |
| `tiankui` | Tian Kui (Noble) | `tianyue` | Tian Yue (Angel) |
| `lucun` | Lu Cun (Treasure) | `tianma` | Tian Ma (Steed) |
| `qingyang` | Qing Yang (Sword) | `tuoluo` | Tuo Luo (Drill) |
| `huoxing` | Huo Xing (Fire) | `lingxing` | Ling Xing (Bell) |
| `dikong` | Di Kong (Void) | `dijie` | Di Jie (Robber) |

### Minor and Auxiliary Stars

Complete list of all 38 minor stars:

| Key | Translation | Key | Translation |
| :--- | :--- | :--- | :--- |
| `hongluan` | Hong Luan (Wedding) | `tianxi` | Tian Xi (Joy) |
| `tianxing` | Tian Xing (Justice)| `tianyao` | Tian Yao (Romance)|
| `tianguan` | Tian Guan (Promote)| `tianfu_minor`| Tian Fu (Blessing) |
| `jiekong` | Jie Kong (Shatter)| `xunkong` | Xun Kong (Empty) |
| `tiancai` | Tian Cai (Talent)| `tianshou` | Tian Shou (Age) |
| `feilian` | Fei Lian (Gossip)| `posui` | Po Sui (Shatter) |
| `santai` | San Tai (Three Steps)| `bazuo` | Ba Zuo (Eight Seats)|
| `enguang` | En Guang (Grace)| `tiangui` | Tian Gui (Honor) |
| `tiande` | Tian De (Heaven De)| `yuede` | Yue De (Moon De) |
| `longchi` | Long Chi (Dragon) | `fengge` | Feng Ge (Phoenix) |
| `tiankong` | Tian Kong (Sky) | `tianku` | Tian Ku (Cry) |
| `tianxu` | Tian Xu (Void) | `huagai` | Hua Gai (Canopy) |
| `xianchi`| Xian Chi (Pool) | `guchen` | Gu Chen (Solitude) |
| `guasu` | Gua Su (Widow) | `taifu` | Tai Fu (Platform) |
| `fenggao` | Feng Gao (Seal) | `yinsha` | Yin Sha (Shadow) |
| `tianwu` | Tian Wu (Shaman) | `tianyue_minor` | Tian Yue (Minor Moon) |
| `tianchu` | Tian Chu (Kitchen) | `jieshen` | Jie Shen (Resolver) |
| `nianjie` | Nian Jie (Year Resolver) | `dahao` | Da Hao (Great Depletion) |
| `tianshang` | Tian Shang (Heavenly Damage) | `tianshi` | Tian Shi (Heavenly Messenger) |
| `fuxun` | Fu Xun (Deputy Void) | `fujie` | Fu Jie (Deputy Intercept) |
