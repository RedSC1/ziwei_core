# JS → Dart API 对照

| JS 入口或模块 | Dart 入口 |
| --- | --- |
| `ZiweiChart.fromZonedTime/fromLunar/fromResolvedBirth` | 同名工厂，`fromLunar` 的时分秒使用命名参数 |
| `ZiweiPlate` 的宫位、星位、庙旺、自化查询 | 同名查询；宫位编号见 `Palace`，四化标记见 `StarTransformMark` |
| `ZiweiOptions`, `options.with` | `ZiweiOptions`, `copyWith`；底层选项用 `CalendarOptions` |
| `resolveZiweiOptions` | Dart 使用已经类型化的 `ZiweiOptions`，无需对象归一化包装 |
| `resolveZiweiBirth/FromInstant` | 同名函数；时刻使用 UT1 JD 或 `ZonedTime` |
| `resolveZiweiVirtualTime/LogicalLunarDate` | 同名函数 |
| `resolveEffectiveLunarMonth` | 输入 `LunarDate`，返回 `(year, month)` record |
| `computePlacementAnchors/computeZiweiAnchors/computePalaceStems` | 同名函数，手动坐标用 `ZiweiPlacementInput` |
| `flattenZiweiAnchors`, `solarDayFromPreviousJie` | 同名函数 |
| `arrangeZiweiStars` | 同名函数，可指定 `rules`、`retainedBureau`、性别和盘式 |
| `modify`, `shiftLifePalace`, `reset`, `resetModification` | 同名方法；`modify` 接收 `ZiweiModifyInput` |
| `ZiweiCastingChart.fromInput/fromIndex/fromNumber/random` | 同名工厂；`randomUint32` 为命名回调参数 |
| `makeFlowLayer/makeSmallLimitLayer` | 同名函数 |
| `ZiweiDynamicChart` 查询、push/truncate/withSmallLimit | 同名功能；小限查询通过 `smallLimit: true` 选择 |
| `resolveZiweiFlow/FromInstant` | 同名函数，可覆盖 `boundary` |
| `dynamicChartFromResolvedFlow/dynamicChartForTime` | 同名函数，`deepestLevel` 为命名参数 |
| `stepZiweiFlowDayTarget/HourTarget` | 同名函数 |
| `getEffectiveBirthYear/getStartDecadeYear` | 同名函数，可选参数命名化 |
| 全部 `makeDecade* / makeChildhoodDecade / makeSmallLimit` | 同名函数 |
| 全部 `makeFlowYear/Month/Day/Hour*` | 同名函数，物理月建、有效年月和历法月名分开传递 |
| `ZiweiTimelineProvider` | `getChildhood/getDecades/getYears/getMonths/getDays/getHours/getManifest` |
| `ZiweiLimitManager` | 同名层级选择、清除、物理步进与动态盘功能 |
| `ZiweiRuleModule/ZiweiRuleset` | 不可变模块与规则集；追加模块用 `withModule` |
| `ZiweiConfigLoader` | `getDefault/withOptions/compileJson/overrideWith` |
| `compileZiweiJsonPlacement` | 同名函数，结果为 `ZiweiCompiledPlacement` |
| `selectZiweiRules`, `evaluate*Placement`, `evaluatePlacementInputs`, `readNatalRuleInput`, `brightnessAt` | 同名底层函数 |
| `getStar/findStarId/requireStarId` | 同名函数；默认目录为 `starCatalogDefault` |
| `STAR_COUNT/NATAL_STAR_COUNT` | `starCount/natalStarCount` |
| `ZIWEI_CASTING_SPACE_SIZE` | `ziweiCastingSpaceSize` |
| `BUREAU/GENDER/FLOW_LEVEL/RAT_HOUR_SEGMENT` 等 | `Bureau/ZiweiGender/FlowLevel/RatHourSegment` 等枚举 |
| `PALACE/BRIGHTNESS/STAR_TRANSFORM_MARK` | `Palace/Brightness/StarTransformMark` 编号常量 |
| `brightnessName/bureauNumber/advanceBranch/isForward` | 同名辅助函数 |
| `reverseLookupZiweiTier1` | 命名参数 `start/end/options/query/maxCandidatesToExamine` |

`TransformSet` 在 Dart 中用不可变 `Map<String, int>` 表示（`lu/quan/ke/ji`）。数据模型公开明确的字段与 `toJson()`；运行时无 JS 解释器，也不执行 JS 代码。


底层步进函数新增可选命名参数 `options`：

```dart
stepZiweiFlowHourTarget(target, options.ratHourMode, 1, options: options);
stepZiweiFlowDayTarget(target, 1, options: options);
```

真太阳时／平太阳时应传入出生盘的选项，以保留虚拟时钟位置并重新换算 UT1。
管理器自动传入，无需调用方额外处理。省略参数保留固定时差步进语义。


民用时钟模式以 `ZiweiOptions.utcOffsetMinutes` 为排盘时区；传入其他时区的 `ZonedTime` 时保持实际瞬间不变，转换到配置时区后排盘。
拆分子时模式下，`targetHourIndex` 和 `FlowHourLimit.hourIndex` 的晚子索引为 12，早子为 0；地支索引仍为 0。
公开返回值类型 `LunarCalendarDate` 可直接从 `ziwei_core.dart` 导入。
