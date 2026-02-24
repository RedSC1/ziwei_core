import 'package:ziwei_core/src/config/ruleset.dart';
import 'package:ziwei_core/src/core/logger.dart';
import 'package:ziwei_core/src/core/placer.dart';
import 'package:ziwei_core/src/core/sihua_decorator.dart';
import 'package:ziwei_core/src/core/star_locator.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/basic.dart';
import 'package:ziwei_core/src/enums/config_enums.dart'; // import gender
import 'package:ziwei_core/src/enums/consts.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

class ZiweiEngine {
  /// 1. 排本命盘
  static ZiWeiPlate calculate(ZiweiDate date, ZiweiRuleset ruleset) {
    ZiweiLogger.info("正在排盘: ${date.solar}...");

    if (date.options != ruleset.calendarOptions) {
      throw ArgumentError(
        '❌ ZiweiDate.options 与 ZiweiRuleset.calendarOptions 不一致！\n'
        '请先建好 ruleset，再将 ruleset.calendarOptions 传入 ZiweiDate.fromSolar/fromLunar，否则历法配置互相矛盾。\n'
        '例：ZiweiDate.fromSolar(dt, options: ruleset.calendarOptions)',
      );
    }

    // 1-1. 安十二宫 (地支位置是固定的)
    List<Palace> palaces = List.generate(
      ZiweiConsts.palaceCount,
      (i) => Palace.fromDiZhi(DiZhi.values[i]),
    );

    final calendarOptions = date.options; //获取日历选项

    // 1-2. 安命身宫
    // ⚠️ 传入农历月和时辰索引 (基于 LunarDate 取值)
    // 修正：从 ZiweiDate.lunar 获取 month 和 timeIndex
    // BaziCore.LunarDate has month, but we need timeIndex.
    // ZiweiDate has a getter for it.
    // 1. 基准点：物理历法的绝对年月
    int effectiveYear = date.lunar.lunarYear;
    int effectiveMonth = date.lunar.month;

    // 🚀 终极归一化：天下哪有正常的 13 月？有就是闰腊月，直接打回 12！
    if (effectiveMonth == 13) {
      effectiveMonth = 12;
    }

    // 2. 核心：闰月推导规则
    if (date.lunar.isLeap) {
      bool shouldAsNext = false;

      switch (calendarOptions.leapRule) {
        case LeapMonthRule.asNext:
          shouldAsNext = true;
          break;
        case LeapMonthRule.splitAt15:
          shouldAsNext = date.lunar.day > 15;
          break;
        case LeapMonthRule.asPrevious:
          //default:
          shouldAsNext = false;
          break;
      }

      // 3. 跨年进位
      if (shouldAsNext) {
        effectiveMonth++;

        // 进位拦截：13 变正月，年份 +1
        if (effectiveMonth > 12) {
          effectiveMonth = 1;
          effectiveYear++;
        }
      }
    }

    // step1: 安放命身宫
    final (int lifeIndex, int bodyIndex) = _calLifeAndBodyPalace(
      date,
      effectiveMonth,
    );

    // step2: 五虎遁安放干支
    // 1. 核心口诀：甲己之年丙作首...
    // 我们要算出“寅宫”（地支索引2）的天干是谁

    // ✅ Refactored: 使用 ZiweiDate.getGanZhi 统一获取年干
    // 这里使用 wuHuDunBasedOn 配置
    final yearGan = date
        .getGanZhi(ZiweiScope.origin, b: date.options.wuHuDunBasedOn)
        .gan;

    _assignPalaceStems(yearGan.index, palaces);

    // step3: 定五行局
    // 注意：命宫干支 now populated
    FiveElementBureau elementBureau = _calculateBureau(
      palaces[lifeIndex].stem!,
      palaces[lifeIndex].branch,
    );

    ZiweiLogger.info(
      "命宫: ${palaces[lifeIndex].branch.label}, 五行局: ${elementBureau.label}",
    );

    // step4: 安星
    // 1.计算紫微天府的位置
    final (
      int ziweiAnchor,
      int tianfuAnchor,
    ) = ZiweiAndTianfuPlacer.placeZiweiAndTianfu(
      date.lunar.day,
      elementBureau.number,
    );

    final solarYear = date.getGanZhi(ZiweiScope.year, b: Boundary.solar);
    final lunarYear = date.getGanZhi(ZiweiScope.year, b: Boundary.lunar);
    final solarKongWang = solarYear.getKongWang();
    final lunarKongWang = lunarYear.getKongWang();

    // 🔥 新增：解析命主与身主
    // ==========================================
    String? mingZhuKey;
    if (ruleset.mingZhuRule != null) {
      // 命主核心逻辑：查命宫(lifeIndex)所在的宫位
      mingZhuKey = ruleset.mingZhuRule!.table[lifeIndex];
    }

    String? shenZhuKey;
    if (ruleset.shenZhuRule != null) {
      // 身主核心逻辑：根据 JSON 里的 boundary，自动选农历年支还是节气年支！
      int yearZhiIndex;
      if (ruleset.shenZhuRule!.boundary == Boundary.lunar) {
        yearZhiIndex = lunarYear.zhi.index;
      } else {
        yearZhiIndex = solarYear.zhi.index;
      }
      shenZhuKey = ruleset.shenZhuRule!.table[yearZhiIndex];
    }
    // ==========================================

    // 2. 构建规则上下文 (RuleContext)
    // 所有的星曜定位都依赖这个上下文
    final contextData = {
      // === 核心锚点 (Indices) ===
      "ziwei": ziweiAnchor,
      "tianfu": tianfuAnchor,
      "ming": lifeIndex, // Ming Index
      "body": bodyIndex,
      "shen": bodyIndex, // Alias
      "wuxingjv": elementBureau.name, //water2,wood3....
      // === 农历数据源 (Lunar Source) ===
      // [Index] 用于数值计算 (e.g. month offset)
      "lunar_year_index": effectiveYear, // e.g. 2024
      "lunar_month": effectiveMonth - 1, // 0-based
      "effective_month": effectiveMonth - 1, // 用于 anchor_offset 规则
      "lunar_day": date.lunar.day - 1,
      "lunar_hour": date.timeIndex, // Using getter from ZiweiDate
      // [String] 用于查表 (e.g. year stem lookup)
      "lunar_year_stem": date
          .getGanZhi(ZiweiScope.year, b: Boundary.lunar)
          .gan
          .name,
      "lunar_year_branch": date
          .getGanZhi(ZiweiScope.year, b: Boundary.lunar)
          .zhi
          .name,
      "lunar_month_stem": date
          .getGanZhi(ZiweiScope.month, b: Boundary.lunar)
          .gan
          .name,
      "lunar_month_branch": date
          .getGanZhi(ZiweiScope.month, b: Boundary.lunar)
          .zhi
          .name,
      "lunar_zheng_kong": lunarKongWang[0].index,
      "lunar_fu_kong": lunarKongWang[1].index,
      // === 节气/八字数据源 (Solar/Bazi Source) ===
      // [Index]
      "solar_year_index": date.bazi.year.zhi.index,
      "solar_month": date.bazi.month.zhi.index - ZiweiConsts.yinIndex, // 寅=0
      "solar_day": date.solarDay - 1,
      "solar_hour": date.timeIndex, // 时辰通常通用
      // [String]
      "solar_year_stem": date.bazi.year.gan.name,
      "solar_year_branch": date.bazi.year.zhi.name,
      "solar_month_stem": date.bazi.month.gan.name,
      "solar_month_branch": date.bazi.month.zhi.name,

      "solar_zheng_kong": solarKongWang[0].index,
      "solar_fu_kong": solarKongWang[1].index,
      // === 默认/兼容键 (Default Keys) ===
      // 大部分传统星曜默认使用农历，这里提供 fallback
      // 这样 JSON 里如果没写 boundary，或者 key 写的是 "year_stem"，默认能取到农历数据
      "year_stem": date.getGanZhi(ZiweiScope.year, b: Boundary.lunar).gan.name,
      "year_branch": date
          .getGanZhi(ZiweiScope.year, b: Boundary.lunar)
          .zhi
          .name,
      "month": effectiveMonth - 1,
      "day": date.lunar.day - 1,
      "hour": date.timeIndex,
      // === 用户元数据 (Metadata) ===
      "gender": date.gender.name, // Use name string for context
    };

    final ruleContext = RuleContext(contextData, ruleset);

    // 3. 执行安星
    // We need to pass the ruleContext to the Placer
    StarPlacer placer = StarPlacer(ruleContext, palaces, date);
    placer.placeAll(ruleset.stars); // Use loaded stars

    // 1-4. 初始化盘面数据结构
    final plate = ZiWeiPlate(
      palaces: palaces,
      originMingIndex: lifeIndex,
      bodyPalaceIndex: bodyIndex,
      elementBureau: elementBureau, //五行局
      date: date,
      ruleset: ruleset,
      effectiveMonth: effectiveMonth,
      effectiveYear: effectiveYear,

      mingZhu: mingZhuKey,
      shenZhu: shenZhuKey,

      // 初始化状态机
      yearMingIndex: null,
      monthMingIndex: null,
      dayMingIndex: null,
      hourMingIndex: null,
    );

    // step5:安装生年四化&&向心四化
    // 原来的 decorateByDate 被废弃了，统一集成到 decorateBase 里
    SiHuaDecorator.decorateBase(plate, ruleset.siHuaRules);

    return plate;
  }

  /// 动态计算 (Time Travel)
  ///
  /// 根据传入的 [LimitContext] (时间胶囊)，在原盘的基础上叠加运限。
  /// 返回一个【全新克隆】的动态盘面，绝对不污染原盘。
  static ZiWeiPlate calculateDynamic(LimitContext context) {
    // 1. 克隆原盘 (Parallel Universe)
    ZiWeiPlate dynamicPlate = context.plate.clone();

    // 2. 依次应用各层级 (Layer by Layer)
    // === 大限 (Decade) ===
    if (context.decade != null) {
      dynamicPlate.decadeMingIndex = context.decade!.index;
      _applyLimit(dynamicPlate, context.decade!, ZiweiScope.decade);
    }

    // === 小限 (Small Limit) ===
    if (context.smallLimit != null) {
      dynamicPlate.smallLimitMingIndex = context.smallLimit!.index;
      _applyLimit(dynamicPlate, context.smallLimit!, ZiweiScope.smallLimit);
    }

    // === 流年 (Year) ===
    if (context.year != null) {
      dynamicPlate.yearMingIndex = context.year!.index;
      _applyLimit(dynamicPlate, context.year!, ZiweiScope.year);
    }

    // === 流月 (Month) ===
    if (context.month != null) {
      dynamicPlate.monthMingIndex = context.month!.index;
      _applyLimit(dynamicPlate, context.month!, ZiweiScope.month);
    }

    // === 流日 (Day) ===
    if (context.day != null) {
      dynamicPlate.dayMingIndex = context.day!.index;
      _applyLimit(dynamicPlate, context.day!, ZiweiScope.day);
    }

    // === 流时 (Hour) ===
    if (context.hour != null) {
      dynamicPlate.hourMingIndex = context.hour!.index;
      _applyLimit(dynamicPlate, context.hour!, ZiweiScope.hour);
    }

    // 3. 直接返回这块渲染好的全新克隆盘！不碰 context！
    return dynamicPlate;
  }

  static void _applyLimit(ZiWeiPlate plate, FlowLimit limit, ZiweiScope scope) {
    // 1. 安放四化 (Flying Si Hua)
    // 使用 limit.ganzhi.gan (时间天干) 查表
    SiHuaDecorator.decorateByStem(
      plate: plate,
      stem: limit.ganzhi.gan,
      siHuaTable: plate.ruleset.siHuaRules, // 使用盘内自带的规则
      scope: scope,
    );

    // 2. 安放流曜 (Flow Stars)
    // 核心思想：构建一个“谎言 Context”，把 limit 的干支伪装成 year_stem
    if (plate.ruleset.flowDefinitions.isEmpty) return;

    final flowContextData = {
      // === 伪装时间 (Time Masquerade) ===
      // 对于流曜来说，当前的 limit 就是它的"本命年"
      // 无论这是流年还是流月，我们都把它的干支填入 year_stem/branch
      // 这样像"禄存"这种依赖 year_stem 的规则就能正常工作
      "year_stem": limit.ganzhi.gan.name,
      "year_branch": limit.ganzhi.zhi.name,

      // 同时覆盖 Lunar/Solar 两个命名空间的 Key，确保万无一失
      "lunar_year_stem": limit.ganzhi.gan.name,
      "lunar_year_branch": limit.ganzhi.zhi.name,
      "solar_year_stem": limit.ganzhi.gan.name,
      "solar_year_branch": limit.ganzhi.zhi.name,

      // 保留原盘的一些锚点 (如紫微、天府、命宫)，万一有流曜依赖它们 (e.g. 某些派别的流年规则)
      // Plate 对象不直接存储紫微/天府的索引，需要去宫位里反查
      "ziwei": plate.palaces.indexWhere((p) => p.hasStar("ziwei")),
      "tianfu": plate.palaces.indexWhere((p) => p.hasStar("tianfu")),
      "ming": plate.originMingIndex,
      "body": plate.bodyPalaceIndex,
      // 传递 Gender，供 gender_shun_ni 使用
      "gender": plate.date.gender.name,
    };

    final flowContext = RuleContext(flowContextData, plate.ruleset);

    // 3. 遍历定义，直接使用独立规则生成流曜
    for (var def in plate.ruleset.flowDefinitions) {
      // 类型改为 int?，因为 locateByRule 现在可能返回 null 了
      int? rawIndex = StarLocator.locateByRule(def.rule, flowContext);

      //判断逻辑从“范围判断”改为“非空判断”
      // 只要不是 null，就代表规则算出了结果（哪怕结果是 -1 或 13）
      if (rawIndex != null) {
        //使用 fixIndex 修正索引，把负数或溢出数字转回 0-11
        int finalIndex = ZiweiConsts.fixIndex(rawIndex);

        // 动态生成 Key: flow_lucun -> flow_year_lucun
        String finalKey = def.key;
        if (finalKey.startsWith("flow_")) {
          finalKey = finalKey.replaceFirst("flow_", "flow_${scope.name}_");
        } else {
          finalKey = "flow_${scope.name}_$finalKey";
        }

        final flowStar = FlowStar(
          key: finalKey,
          brightnessTable: def.brightness,
          scope: scope,
        );

        //使用修正后的 finalIndex 塞入宫位
        plate.palaces[finalIndex].addStar(flowStar);
      } else {
        // 如果是 null，说明该流曜在此作用域（比如某流月）下不适用或计算失败
        // ZiweiLogger.warn("流曜 ${def.key} 在 ${scope.name} 级别计算失败，跳过");
      }
    }
  }

  static (int, int) _calLifeAndBodyPalace(ZiweiDate date, int effectiveMonth) {
    int monthOffset = effectiveMonth - 1; // 语义：相对于“正月”的偏移量
    int hourStep = date.timeIndex; // 子时=0, from getter
    int lifeIndex = ZiweiConsts.fixIndex(
      ZiweiConsts.yinIndex + monthOffset - hourStep,
    );
    // 寅起正月，顺数至生月，顺数生时为身宫。
    int bodyIndex = ZiweiConsts.fixIndex(
      ZiweiConsts.yinIndex + monthOffset + hourStep,
    );
    return (lifeIndex, bodyIndex);
  }

  static void _assignPalaceStems(int yearGanIndex, List<Palace> palaces) {
    // 五虎遁公式：(年干索引 % 5) * 2 + 2
    // 原理：
    // 甲(0)、己(5) -> 余0 -> *2+2 = 2 (丙) -> 丙寅
    // 乙(1)、庚(6) -> 余1 -> *2+2 = 4 (戊) -> 戊寅
    int startStemIndex = (yearGanIndex % 5) * 2 + 2;

    // 2. 顺时针填满 12 个宫位
    for (int i = 0; i < 12; i++) {
      // 按照寅宫(2)开始数
      // 这里的 i 代表从寅开始走的步数
      // 实际宫位索引 (0-11)
      int palaceIndex = (ZiweiConsts.yinIndex + i) % 12;

      // 计算宫干索引 (0-9)，超过10要回头
      int stemIndex = (startStemIndex + i) % 10;

      // 赋值！
      palaces[palaceIndex].stem = TianGan.values[stemIndex];
    }
  }

  static FiveElementBureau _calculateBureau(TianGan stem, DiZhi branch) {
    // 1. 天干系数 (每两个一组)
    // 甲乙=0, 丙丁=1, 戊己=2, 庚辛=3, 壬癸=4
    final stemScore = stem.index ~/ 2;
    // 2. 地支系数 (每两个一组，隔着来)
    // 子丑/午未=0, 寅卯/申酉=1, 辰巳/戌亥=2
    final branchScore = (branch.index ~/ 2) % 3;
    // 3. 核心公式：加起来求余
    final result = (stemScore + branchScore) % 5;
    switch (result) {
      case 0:
        return FiveElementBureau.metal4;
      case 1:
        return FiveElementBureau.water2;
      case 2:
        return FiveElementBureau.fire6;
      case 3:
        return FiveElementBureau.earth5;
      case 4:
        return FiveElementBureau.wood3;
      default:
        throw StateError('Invalid bureau remainder: $result');
    }
  }
}
