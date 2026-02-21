import 'dart:convert';
import 'dart:io';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/core/logger.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/basic.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

// 简单的 i18n 缓存
Map<String, String> _i18nMap = {};

void main() async {
  // 1. 加载所有规则 (含主规则、流曜等)
  final globalOptions = await _loadConfig();

  // 2. 创建命主时间 (2025-08-16 23:30 晚子时测试)
  final birthday = AstroDateTime(2003, 8, 28, 2, 30);
  final ziweiDate = ZiweiDate.fromSolar(
    birthday, 
    gender: Gender.male, 
    location: Location.beijing,
    options: globalOptions,
  );

  // 3. 计算原盘
  final basePlate = ZiweiEngine.calculate(ziweiDate);

  // 🚀 4. 五维时空穿梭！
  final targetDayGanzhi = GanZhi(TianGan.yi, DiZhi.chou); 

  final context = TimeMachine.travel(
    basePlate, 
    year: 2026, 
    month: 1,
    day: 4,
    hourIndex: DiZhi.shen.index, 
    dayGanZhi: targetDayGanzhi, // 🔑 注入灵魂参数：激活流日与流时！
  );
  
  final dynamicPlate = ZiweiEngine.calculateDynamic(context);

  // 5. 打印头部五维时空信息
  print('\n=== 🌌 Ziwei Engine 终极五维时空穿梭 🌌 ===');
  print('📅 出生时间: ${birthday.year}-${birthday.month}-${birthday.day} ${birthday.hour}:${birthday.minute}');
  print('📋 判定八字: ${ziweiDate.bazi.year.gan.label}${ziweiDate.bazi.year.zhi.label} '
        '${ziweiDate.bazi.month.gan.label}${ziweiDate.bazi.month.zhi.label} '
        '${ziweiDate.bazi.day.gan.label}${ziweiDate.bazi.day.zhi.label} '
        '${ziweiDate.bazi.time.gan.label}${ziweiDate.bazi.time.zhi.label}');
  print('🎯 五行局: ${_getBureauName(basePlate.elementBureau)}');
  print('-' * 40);
  
  // 打印各维度干支信息
  if (context.hasDecade) print('⏳ [大限]: ${context.decade!.ganzhi.gan.label}${context.decade!.ganzhi.zhi.label}');
  if (context.smallLimit != null) print('👶 [小限]: ${context.smallLimit!.ganzhi.gan.label}${context.smallLimit!.ganzhi.zhi.label}');
  if (context.hasYear) print('🐎 [流年]: ${context.year!.ganzhi.gan.label}${context.year!.ganzhi.zhi.label}');
  if (context.month != null) print('🌙 [流月]: ${context.month!.ganzhi.gan.label}${context.month!.ganzhi.zhi.label}');
  if (context.day != null) print('☀️ [流日]: ${context.day!.ganzhi.gan.label}${context.day!.ganzhi.zhi.label}');
  if (context.hour != null) print('⏰ [流时]: ${context.hour!.ganzhi.gan.label}${context.hour!.ganzhi.zhi.label}');
  print('-' * 60);

  // 6. 遍历打印 12 宫
  for (int i = 0; i < 12; i++) {
    _printPalaceInfo(dynamicPlate, dynamicPlate.palaces[i]);
  }
}

// --- 辅助打印函数 ---

void _printPalaceInfo(ZiWeiPlate plate, Palace palace) {
  // ✅ 修正 Null 安全调用
  final ganzhi = "[${palace.stem?.label ?? ''}${palace.branch.label}]";

  // 🚩 多维叠宫信息 (大/小/年/月/日/时)
  final roles = <String>[];
  roles.add("原${_calculateRelativeName(plate.originMingIndex, palace.index, "")}");
  
  if (palace.index == plate.bodyPalaceIndex) roles.add("身宫");
  if (plate.decadeMingIndex != null) roles.add(_calculateRelativeName(plate.decadeMingIndex!, palace.index, "大"));
  if (plate.smallLimitMingIndex != null) roles.add(_calculateRelativeName(plate.smallLimitMingIndex!, palace.index, "小"));
  if (plate.yearMingIndex != null) roles.add(_calculateRelativeName(plate.yearMingIndex!, palace.index, "年"));
  if (plate.monthMingIndex != null) roles.add(_calculateRelativeName(plate.monthMingIndex!, palace.index, "月"));
  if (plate.dayMingIndex != null) roles.add(_calculateRelativeName(plate.dayMingIndex!, palace.index, "日"));
  if (plate.hourMingIndex != null) roles.add(_calculateRelativeName(plate.hourMingIndex!, palace.index, "时"));

  final roleStr = "(${roles.join("/")})";

  // 🔥 核心重构：使用 .allStars 代替原本的 Map 类型 stars
  final starsOutput = palace.allStars.map((star) {
    final sb = StringBuffer();
    
    // 1. 名字汉化
    String starName = _t("star_${star.key}");
    if (starName.startsWith("star_flow_")) {
       starName = star.key.replaceAll("flow_", "");
    }
    sb.write(starName);

    // 2. 亮度
    int bLevel = -1;
    if (star is StaticStar) bLevel = star.getBrightness(palace.branch);
    if (star is FlowStar) bLevel = star.getBrightness(palace.branch);
    if (bLevel >= 0) sb.write("(${_getBrightnessLabel(bLevel)})");

    // 3. 多维四化 (原/向心/自化/大/小/年/月/日/时)
    if (star is StaticStar) {
      if (star.siHuaBuff[ZiweiScope.origin] != null) sb.write("{生${_t("sihua_${star.siHuaBuff[ZiweiScope.origin]!.name}")}}");
      if (star.centripetalSiHua != null) sb.write("[向心${_t("sihua_${star.centripetalSiHua!.name}")}]");
      if (star.selfSiHua != null) sb.write("[自化${_t("sihua_${star.selfSiHua!.name}")}]");
      if (star.siHuaBuff[ZiweiScope.decade] != null) sb.write("{大${_t("sihua_${star.siHuaBuff[ZiweiScope.decade]!.name}")}}");
      if (star.siHuaBuff[ZiweiScope.smallLimit] != null) sb.write("{小${_t("sihua_${star.siHuaBuff[ZiweiScope.smallLimit]!.name}")}}");
      if (star.siHuaBuff[ZiweiScope.year] != null) sb.write("{年${_t("sihua_${star.siHuaBuff[ZiweiScope.year]!.name}")}}");
      if (star.siHuaBuff[ZiweiScope.month] != null) sb.write("{月${_t("sihua_${star.siHuaBuff[ZiweiScope.month]!.name}")}}");
      if (star.siHuaBuff[ZiweiScope.day] != null) sb.write("{日${_t("sihua_${star.siHuaBuff[ZiweiScope.day]!.name}")}}");
      if (star.siHuaBuff[ZiweiScope.hour] != null) sb.write("{时${_t("sihua_${star.siHuaBuff[ZiweiScope.hour]!.name}")}}");
    }

    // 4. 流曜角标分类
    if (star is FlowStar) {
      if (star.key.contains("decade")) sb.write("[大]");
      if (star.key.contains("smallLimit")) sb.write("[小]");
      if (star.key.contains("year")) sb.write("[年]");
      if (star.key.contains("month")) sb.write("[月]");
      if (star.key.contains("day")) sb.write("[日]");
      if (star.key.contains("hour")) sb.write("[时]");
    }

    return sb.toString();
  }).join(", ");

  print("$ganzhi ${roleStr.padRight(50)} : $starsOutput");
}

// ... 剩下的辅助函数 (_loadConfig, _t, _getBrightnessLabel 等) 保持不变 ...
// --- 配置加载与翻译 ---

Future<CalendarOptions> _loadConfig() async {
  final starsJson = await File('assets/config/default/stars.json').readAsString();
  final brightnessJson = await File('assets/config/default/brightness.json').readAsString();
  final sihuaJson = await File('assets/config/default/sihua.json').readAsString();
  final flowJson = await File('assets/config/default/flow_stars.json').readAsString();
  final mainRulesJson = await File('assets/config/default/main_rules.json').readAsString();
  final i18nJson = await File('assets/i18n/zh_CN.json').readAsString();

  _i18nMap = Map<String, String>.from(jsonDecode(i18nJson));
  ConfigLoader.parseStars(starsJson, brightnessJson);
  ConfigLoader.parseSiHua(sihuaJson);
  ConfigLoader.parseFlowStars(flowJson);

  return ConfigLoader.parse(mainRulesJson);
}

String _t(String key) => _i18nMap[key] ?? key;

String _getBrightnessLabel(int level) {
  const labels = ["陷", "不", "平", "利", "得", "旺", "庙"];
  return (level >= 0 && level < labels.length) ? labels[level] : "";
}

String _getBureauName(FiveElementBureau bureau) {
  switch (bureau) {
    case FiveElementBureau.water2: return "水二局";
    case FiveElementBureau.wood3: return "木三局";
    case FiveElementBureau.metal4: return "金四局";
    case FiveElementBureau.earth5: return "土五局";
    case FiveElementBureau.fire6: return "火六局";
    default: return "未知局";
  }
}

String _calculateRelativeName(int mingIndex, int targetIndex, String prefix) {
  const names = ["命宫", "兄弟", "夫妻", "子女", "财帛", "疾厄", "迁移", "交友", "官禄", "田宅", "福德", "父母"];
  final nameIndex = (12 - (targetIndex - mingIndex + 12) % 12) % 12;
  return "$prefix${names[nameIndex]}";
}