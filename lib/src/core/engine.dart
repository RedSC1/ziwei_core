import 'package:ziwei_core/src/config/loader.dart'; // 引入Loader
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/src/core/placer.dart';
import 'package:ziwei_core/src/core/star_locator.dart';
import 'package:ziwei_core/src/core/sihua_decorator.dart';
import 'package:ziwei_core/src/enums/consts.dart';

class ZiWeiEngine {
  static ZiWeiPlate calculate(
    ZiweiDate date,
    List<StaticStar> stars,
    Map<TianGan, Map<SiHuaType, String>> siHuaRules,
  ) {
    //(0=子, 1=丑 ... 11=亥)
    List<Palace> palaces = List.generate(
      ZiweiConsts.palaceCount,
      (i) => Palace(i),
    );

    final calendarOptions = date.options; //获取日历选项
    int effectiveMonth =
        date.lunar.month; //effectiveMonth是指实际计算的月份，会因为闰月的处理方式不一样
    if (date.lunar.isLeap) {
      switch (calendarOptions.leapRule) {
        case LeapMonthRule.asNext:
          effectiveMonth++;
          break;
        case LeapMonthRule.asPrevious:
          break;
        case LeapMonthRule.splitAt15:
          effectiveMonth += date.lunar.day > 15 ? 1 : 0;
          break;
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
    // TianGan.jia.index 是 0

    // ✅ Refactored: 使用 ZiweiDate.getGanZhi 统一获取年干
    // 这里使用 wuHuDunBasedOn 配置
    final yearGan = date
        .getGanZhi(ZiweiScope.origin, b: date.options.wuHuDunBasedOn)
        .gan;

    _assignPalaceStems(yearGan.index, palaces);

    // step3: 定五行局
    FiveElementBureau elementBureau = _calculateBureau(
      palaces[lifeIndex].stem!,
      palaces[lifeIndex].branch,
    );

    // step4: 安星
    // 大部分星曜都可以按照先查表+偏移的方式来计算
    // 1.计算紫微天府的位置
    final (
      int ziweiAnchor,
      int tianfuAnchor,
    ) = ZiweiAndTianfuPlacer.placeZiweiAndTianfu(
      date.lunar.day,
      elementBureau.number,
    );

    // 2. 构建规则上下文 (RuleContext)
    // 所有的星曜定位都依赖这个上下文
    // 核心思想：Context 只负责提供“全量数据”，具体的取用逻辑(Lunar/Solar)由 StarLocator 根据 JSON 规则决定
    final contextData = {
      // === 核心锚点 (Indices) ===
      "ziwei": ziweiAnchor,
      "tianfu": tianfuAnchor,
      "ming": lifeIndex,
      "body": bodyIndex,
      "shen": bodyIndex, // Alias
      // === 农历数据源 (Lunar Source) ===
      // [Index] 用于数值计算 (e.g. month offset)
      "lunar_year_index": date.lunar.year, // e.g. 2024
      "lunar_month": effectiveMonth - 1, // 0-based
      "lunar_day": date.lunar.day - 1,
      "lunar_hour": date.lunar.timeIndex,
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

      // === 节气/八字数据源 (Solar/Bazi Source) ===
      // [Index]
      "solar_year_index": date.bazi.year.zhi.index,
      "solar_month": date.bazi.month.zhi.index - ZiweiConsts.yinIndex, // 寅=0
      "solar_day": date.solarDay - 1,
      "solar_hour": date.lunar.timeIndex, // 时辰通常通用
      // [String]
      "solar_year_stem": date.bazi.year.gan.name,
      "solar_year_branch": date.bazi.year.zhi.name,
      "solar_month_stem": date.bazi.month.gan.name,
      "solar_month_branch": date.bazi.month.zhi.name,

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
      "hour": date.lunar.timeIndex,
    };

    final ruleContext = RuleContext(contextData);

    // 3. 执行安星
    StarPlacer placer = StarPlacer(ruleContext, palaces, date);
    placer.placeAll(stars);

    ZiWeiPlate plate = ZiWeiPlate(
      palaces: palaces, // 这里面已经是带天干的了
      originMingIndex: lifeIndex, // 命宫位置
      bodyPalaceIndex: bodyIndex, // 身宫位置
      elementBureau: elementBureau, // 五行局
      date: date, //birthDate
      siHuaRules: siHuaRules,
    );

    //step5:安装生年四化&&向心四化
    // 原来的 decorateByDate 被废弃了，统一集成到 decorateBase 里
    SiHuaDecorator.decorateBase(plate, siHuaRules);

    return plate;
  }

  /// 动态计算 (Time Travel)
  ///
  /// 根据传入的 [LimitContext] (时间胶囊)，在原盘的基础上叠加运限。
  /// 包含：
  /// 1. 设置各层级的命宫位置 (Ming Index)
  /// 2. 叠加四化 (Si Hua)
  /// 3. 叠加流曜 (Flow Stars) - TODO
  static ZiWeiPlate calculateDynamic(LimitContext context) {
    // 1. 克隆原盘 (Parallel Universe)
    ZiWeiPlate dynamicPlate = context.plate.clone();

    // 2. 依次应用各层级 (Layer by Layer)
    // 每一层都需要：
    // a. 设置命宫索引 (Set Ming Index)
    // b. 触发该层级的四化/流星 (Apply Decorators)

    // === 大限 (Decade) ===
    if (context.hasDecade) {
      dynamicPlate.decadeMingIndex = context.decade!.index;
      _applyLimit(dynamicPlate, context.decade!, ZiweiScope.decade);
    }

    // === 小限 (Small Limit) ===
    if (context.smallLimit != null) {
      dynamicPlate.smallLimitMingIndex = context.smallLimit!.index;
      // 启用小限四化 (根据小限宫干)
      _applyLimit(dynamicPlate, context.smallLimit!, ZiweiScope.smallLimit);
    }

    // === 流年 (Year) ===
    if (context.hasYear) {
      dynamicPlate.yearMingIndex = context.year!.index;
      _applyLimit(dynamicPlate, context.year!, ZiweiScope.year);
    }

    // === 流月 (Month) ===
    if (context.hasMonth) {
      dynamicPlate.monthMingIndex = context.month!.index;
      _applyLimit(dynamicPlate, context.month!, ZiweiScope.month);
    }

    // === 流日 (Day) ===
    if (context.hasDay) {
      dynamicPlate.dayMingIndex = context.day!.index;
      _applyLimit(dynamicPlate, context.day!, ZiweiScope.day);
    }

    // === 流时 (Hour) ===
    if (context.hasHour) {
      dynamicPlate.hourMingIndex = context.hour!.index;
      _applyLimit(dynamicPlate, context.hour!, ZiweiScope.hour);
    }

    return dynamicPlate;
  }

  static void _applyLimit(ZiWeiPlate plate, FlowLimit limit, ZiweiScope scope) {
    // 1. 安放四化 (Flying Si Hua)
    // 使用 limit.ganzhi.gan (时间天干) 查表
    SiHuaDecorator.decorateByStem(
      plate: plate,
      stem: limit.ganzhi.gan,
      siHuaTable: plate.siHuaRules, // 使用盘内自带的规则
      scope: scope,
    );

    // 2. 安放流曜 (Flow Stars)
    // 核心思想：构建一个“谎言 Context”，把 limit 的干支伪装成 year_stem
    if (ConfigLoader.flowDefinitions.isEmpty) return;

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
    };

    final flowContext = RuleContext(flowContextData);

    // 3. 遍历定义，直接使用独立规则生成流曜
    for (var def in ConfigLoader.flowDefinitions) {
      // 🔥 核心变更：不再查 Key，而是直接把 JSON 里定义的 Rule 扔给 Locator 算
      int index = StarLocator.locateByRule(def.rule, flowContext);

      if (index >= 0 && index < 12) {
        // 动态生成 Key: flow_lucun -> flow_year_lucun
        // 这样可以区分流年、流月、流日
        String finalKey = def.key;
        if (finalKey.startsWith("flow_")) {
          finalKey = finalKey.replaceFirst("flow_", "flow_${scope.name}_");
        } else {
          finalKey = "flow_${scope.name}_$finalKey";
        }

        final flowStar = FlowStar(
          key: finalKey,
          brightnessTable: def.brightness, // 直接使用独立的亮度表
        );

        plate.palaces[index].addStar(flowStar);
      }
    }
  }

  static (int, int) _calLifeAndBodyPalace(ZiweiDate date, int effectiveMonth) {
    int monthOffset = effectiveMonth - 1; // 语义：相对于“正月”的偏移量
    int hourStep = date.lunar.timeIndex; // 子时=0
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
