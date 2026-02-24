# Experimental Features

The following features are fully implemented and available for use. However, due to a lack of broad sect consensus or historical validation data, they are marked as "Experimental." Their behavior or interfaces might be adjusted in future versions.

---

## 1. Five-Tigers-Chasing-Month Base (`wuHuDunBasedOn`)

**Configuration Key**: `CalendarOptions.wuHuDunBasedOn` (Dart) / `main_rules.json` → `wu_hu_dun_boundary` (JSON)

**Available Options**: `lunar` (Default) / `solar`

**Impact**: The "Five Tigers Chasing Month" formula calculates Palace Sky Stems around the 12 boxes. Its core input is the "Year Stem." This toggle determines exactly *which* Year Stem to use:

| Value | Behavior |
| :--- | :--- |
| `lunar` | Uses the **Lunar Year Stem**. A person born after the start of Spring (Li Chun) but before Lunar New Year's Day stays tied to the old Lunar Year Stem. |
| `solar` | Uses the **Solar Term Year Stem (BaZi Year Pillar Sky Stem)**. Once Li Chun (Start of Spring) hits, it adopts the new Year Stem. |

For individuals born in the narrow window between Li Chun and the Lunar New Year, this seemingly minuscule shift triggers a **butterfly effect across the entire chart**:
Change the **Year Stem** → All 12 **Palace Stems** change → The **Life Palace Stem** changes → The **Five Elements Bureau** changes (e.g., Water 2nd Bureau becomes Wood 3rd Bureau) → The locations of **Ziwei Star** and all 14 major stars completely shift → Also affects the starting age of Destiny, Decade Limit arrangements, and all Flying SiHua (Transformers). Essentially, changing this base yields a radically different chart.

---

## 2. Flow Bound Divide (`flowLimitBasedOn`)

**Configuration Key**: `CalendarOptions.flowLimitBasedOn` (Dart) / `main_rules.json` → `flowLimit_boundary` (JSON)

**Available Options**: `lunar` (Default) / `solar`

**Impact**: Controls how the engine delineates time boundaries for Flowing Years, Flowing Months, etc.:

| Value | Behavior |
| :--- | :--- |
| `lunar` | Flowing Years observe the **Lunar Year boundary**, Flowing Months observe **Lunar Month 1st days**. |
| `solar` | Flowing Years observe **Li Chun (Start of Spring)** as the boundary (aligning with the BaZi pillar), Flowing Months observe **Solar Term thresholds** as boundaries. |

Selecting `solar` drives the entire Flowing Limit system much closer to BaZi's predictive logic, pushing people born before Li Chun solidly into the preceding year's limits.

---

## 3. Historical Calendar Safeguard (`enableHistorical`)

**Configuration Key**: `CalendarOptions.enableHistorical` (Dart) / `main_rules.json` → `enable_historical` (JSON)

**Available Options**: `true` (Default) / `false`

**Impact**: Chinese history underwent numerous calendar reforms. In certain chaotic eras (e.g., pre-Taichu calendar, Wu Zetian's Zhou calendar), leap months and month sequences deviate wildly from modern extrapolations. This toggle affects both **Origin Chart generation** and **Flowing Timeline traversals**:

| Value | Behavior |
| :--- | :--- |
| `true` | **Origin Chart**: Enables parsing of erratic historical calendars (e.g., correctly acknowledging the "Latter 9th Month" leap month under the Zhuanxu calendar from 366~104 BC).<br>**Flowing Charts**: If a historical "Red Zone" is detected during time travel, the engine **automatically trips a circuit breaker halting Flowing Month and lower-tier calculations**. (Due to historical uncertainty, it only calculates the Origin chart, Decades, and Flowing Years). `TimelineManifest.status.isHistoricalRedZone` flags `true`. |
| `false` | Disables safeguards, forcefully employing modern algorithmic extrapolations across all eras. Results during chaotic historical periods may severely deviate from documented reality. |

> [!WARNING]
> Disabling this safeguard implies Flowing Month/Day results for ancient eras are strictly for abstract reference and carry no guarantee of matching actual historical dates.

---

## 4. Childhood Limit Rule (`childhoodRule`)

**Configuration Key**: `CalendarOptions.childhoodRule` (Dart) / `main_rules.json` → `childhood_decade` (JSON)

**Available Options**: `skip` (Default) / `regular`

**Impact**: How the "Childhood Limit" phase (before the first major Decade Limit triggers) is calculated:

| Value | Behavior |
| :--- | :--- |
| `skip` | **Jumping Rhyme Sect**. Calculates the childhood tile annually based on traditional memorization rhymes ("1 Life, 2 Wealth, 3 Health, 4 Spouse, 5 Fortune, 6 Career..."). The active palace jumps violently each year. |
| `regular` | **Sequential Sect**. Starts from the Life Palace and moves sequentially one tile per nominal year. The **direction (clockwise/counter-clockwise)** observes the standard Decade Limit flow rules (i.e. Yang Male/Yin Female go forward, Yin Male/Yang Female go backward). |
