import 'dart:convert';
import 'dart:io';
import 'package:ziwei_core/ziwei_core.dart'; 

// 简单的 i18n 缓存
Map<String, String> _i18nMap = {};

void main() async {
  // 🚩 1. 加载规则
  final options = await _loadConfig();

  final birthday = DateTime(2003, 8, 28, 2, 30);
  
  print('🔨 正在初始化日期引擎 (Options: 早晚子=${options.splitRatHour})...');
  final ziweiDate = ZiweiDate.fromSolar(
    birthday, 
    gender: Gender.male,
    options: options, 
  );

  // 3. 计算原盘
  print('🧱 正在安星布盘...');
  final basePlate = ZiweiEngine.calculate(ziweiDate);

  // 4. 时光穿梭
  final fy = 2026; 
  print('🚀 启动时光机前往 $fy 年...');
  final context = TimeMachine.travel(basePlate, year: fy);
  final dynamicPlate = ZiweiEngine.calculateDynamic(context);

  // 5. 打印摘要
  _printHeader(ziweiDate, context, basePlate, fy);

  print('----------------------------------------------------------------');

  // 6. 遍历 12 宫
  for (int i = 0; i < 12; i++) {
    _printPalaceInfo(dynamicPlate, dynamicPlate.palaces[i]);
  }
}

// --- 核心打印函数 ---

void _printPalaceInfo(ZiWeiPlate plate, Palace palace) {
  // ✅ 修正：stem 可能为 null，使用安全调用
  final ganzhi = "[${palace.stem?.label ?? ''}${palace.branch.label}]";

  // 1. 组合宫职信息
  final roles = <String>[];
  roles.add(_calculateRelativeName(plate.originMingIndex, palace.index, ""));
  if (plate.decadeMingIndex == palace.index) roles.add("★大限命");
  if (plate.smallLimitMingIndex == palace.index) roles.add("☆小限命");
  if (plate.yearMingIndex == palace.index) roles.add("▲流年命");

  String roleStr = "(${roles.join("/")})";

  // 🔥 核心重构修复：stars 现在是 Map，必须使用 allStars 摊平后才能 map()
  final starsOutput = palace.allStars.map((s) {
    final sb = StringBuffer();
    sb.write(_t("star_${s.key}")); 

    // 亮度计算
    int bLevel = -1;
    if (s is StaticStar) bLevel = s.getBrightness(palace.branch);
    if (s is FlowStar) bLevel = s.getBrightness(palace.branch);
    if (bLevel >= 0) sb.write("(${_getBrightnessLabel(bLevel)})");

    // 四化标记
    if (s is StaticStar) {
      if (s.siHuaBuff[ZiweiScope.origin] != null) sb.write("{生${_t("sihua_${s.siHuaBuff[ZiweiScope.origin]!.name}")}}");
      if (s.siHuaBuff[ZiweiScope.decade] != null) sb.write("{大${_t("sihua_${s.siHuaBuff[ZiweiScope.decade]!.name}")}}");
      if (s.siHuaBuff[ZiweiScope.year] != null) sb.write("{流${_t("sihua_${s.siHuaBuff[ZiweiScope.year]!.name}")}}");
    }

    // 流曜标记
    if (s is FlowStar) {
      if (s.key.contains("decade")) sb.write("[大]");
      if (s.key.contains("year")) sb.write("[年]");
    }

    return sb.toString();
  }).join(", ");

  print("$ganzhi ${roleStr.padRight(25)} : $starsOutput");
}

// --- 辅助逻辑函数 ---

void _printHeader(ZiweiDate date, LimitContext ctx, ZiWeiPlate plate, int fy) {
  print('\n=== 🔮 Ziwei Core 全维验证报告 🔮 ===');
  print('📅 公历生日: ${date.solar}');
  
  final yGZ = date.bazi.year;
  print('📋 判定八字: ${yGZ.gan.label}${yGZ.zhi.label} ... (完整八字: ${date.bazi})');
  print('🎯 五行局: ${_getBureauLabel(plate.elementBureau)}');
  
  if (ctx.hasDecade) {
    final gz = ctx.decade!.ganzhi;
    print('⏳ 大限: ${gz.gan.label}${gz.zhi.label} [${ctx.decade!.startTime}-${ctx.decade!.endTime}岁] (${_getSiHuaStr(gz.gan)})');
  }
  
  if (ctx.smallLimit != null) {
    final gz = ctx.smallLimit!.ganzhi;
    print('👶 小限: ${gz.gan.label}${gz.zhi.label} [${ctx.smallLimit!.age}岁] (${_getSiHuaStr(gz.gan)})');
  }
  
  if (ctx.hasYear) {
    final gz = ctx.year!.ganzhi;
    print('🐎 流年: ${gz.gan.label}${gz.zhi.label} ($fy) (${_getSiHuaStr(gz.gan)})');
  }
}

// 加载配置
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

String _getSiHuaStr(TianGan gan) {
  final rules = ConfigLoader.siHuaRules[gan];
  if (rules == null) return "未知";
  return "${rules[SiHuaType.lu]}禄 ${rules[SiHuaType.quan]}权 ${rules[SiHuaType.ke]}科 ${rules[SiHuaType.ji]}忌";
}

String _getBureauLabel(FiveElementBureau bureau) {
  switch (bureau) {
    case FiveElementBureau.water2: return "水二局";
    case FiveElementBureau.wood3:  return "木三局";
    case FiveElementBureau.metal4: return "金四局";
    case FiveElementBureau.earth5: return "土五局";
    case FiveElementBureau.fire6:  return "火六局";
    default: return "未知";
  }
}

String _getBrightnessLabel(int level) {
  const labels = ["陷", "不", "平", "利", "得", "旺", "庙"];
  return (level >= 0 && level < labels.length) ? labels[level] : "?";
}

String _calculateRelativeName(int mingIndex, int targetIndex, String prefix) {
  const names = ["命宫", "兄弟", "夫妻", "子女", "财帛", "疾厄", "迁移", "交友", "官禄", "田宅", "福德", "父母"];
  final nameIndex = (12 - (targetIndex - mingIndex + 12) % 12) % 12;
  return "$prefix${names[nameIndex]}";
}