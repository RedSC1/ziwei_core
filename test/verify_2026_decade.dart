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
  // 🚩 核心修复：接住解析出来的全局选项
  final globalOptions = await _loadConfig();

  // 1. 创建命主时间 (2025-08-16 23:30 晚子时测试)
  final birthday = AstroDateTime(2025, 8, 16, 23, 30);

  // 🚩 核心修复：将 globalOptions 传入，否则早晚子逻辑不会生效
  final ziweiDate = ZiweiDate.fromSolar(
    birthday, 
    gender: Gender.male, 
    location: Location.beijing,
    options: globalOptions, // 🚀 注入灵魂
  );

  // 2. 计算原盘
  final basePlate = ZiweiEngine.calculate(ziweiDate);

  // 3. 时光穿梭到 2026 年
  final context = TimeMachine.travel(basePlate, year: 2026);
  final dynamicPlate = ZiweiEngine.calculateDynamic(context);

  // 4. 打印头部信息
  print('\n=== 🔮 Ziwei Engine 验证结果 🔮 ===');
  print('📅 出生时间: ${birthday.year}-${birthday.month}-${birthday.day} ${birthday.hour}:${birthday.minute}');
  print('📋 判定八字: ${ziweiDate.bazi}');
  print('🎯 五行局: ${_getBureauName(basePlate.elementBureau)}');
  print('⏳ 当前大限: ${context.decade!.ganzhi.gan.label}${context.decade!.ganzhi.zhi.label} [${context.decade!.startTime}-${context.decade!.endTime}岁]');
  print('🐎 流年: ${context.year!.ganzhi.gan.label}${context.year!.ganzhi.zhi.label}');
  print('-' * 60);

  // 5. 遍历打印 12 宫
  for (int i = 0; i < 12; i++) {
    _printPalaceInfo(dynamicPlate, dynamicPlate.palaces[i]);
  }
}

// --- 辅助打印函数 ---

void _printPalaceInfo(ZiWeiPlate plate, Palace palace) {
  final ganzhi = "[${palace.stem!.label}${palace.branch.label}]";

  // 计算原局宫名
  String originName = "(${_calculateRelativeName(plate.originMingIndex, palace.index, "")})";
  if (palace.index == plate.bodyPalaceIndex) {
    originName += "[身宫]";
  }

  // 计算大限宫名
  final decadeName = _calculateRelativeName(
    plate.decadeMingIndex!,
    palace.index,
    "大限",
  );

  // 提取静态星曜并格式化四化
  final starsOutput = palace.stars
      .whereType<StaticStar>()
      .map((star) {
        final sb = StringBuffer();
        sb.write(_t("star_${star.key}"));
        sb.write("(${_getBrightnessLabel(star.getBrightness(palace.branch))})");

        // 拼接各种四化标记
        if (star.siHuaBuff[ZiweiScope.origin] != null) {
          sb.write("(${_t("sihua_${star.siHuaBuff[ZiweiScope.origin]!.name}")})");
        }
        if (star.centripetalSiHua != null) {
          sb.write("[向心${_t("sihua_${star.centripetalSiHua!.name}")}]");
        }
        if (star.selfSiHua != null) {
          sb.write("[自化${_t("sihua_${star.selfSiHua!.name}")}]");
        }
        if (star.siHuaBuff[ZiweiScope.decade] != null) {
          sb.write("(大限${_t("sihua_${star.siHuaBuff[ZiweiScope.decade]!.name}")})");
        }
        if (star.siHuaBuff[ZiweiScope.year] != null) {
          sb.write("(流年${_t("sihua_${star.siHuaBuff[ZiweiScope.year]!.name}")})");
        }

        return sb.toString();
      })
      .join(", ");

  print(
    "$ganzhi $originName".padRight(15) +
    " ($decadeName)".padRight(10) +
    " : $starsOutput",
  );
}

// --- 配置加载与翻译 ---

Future<CalendarOptions> _loadConfig() async {
  // 1. 加载所有 JSON 文件内容
  final starsJson = await File('assets/config/default/stars.json').readAsString();
  final brightnessJson = await File('assets/config/default/brightness.json').readAsString();
  final sihuaJson = await File('assets/config/default/sihua.json').readAsString();
  final mainRulesJson = await File('assets/config/default/main_rules.json').readAsString();
  final i18nJson = await File('assets/i18n/zh_CN.json').readAsString();

  // 2. 初始化静态仓库
  _i18nMap = Map<String, String>.from(jsonDecode(i18nJson));
  ConfigLoader.parseStars(starsJson, brightnessJson);
  ConfigLoader.parseSiHua(sihuaJson);

  // 3. 🚩 解析并返回主规则对象
  return ConfigLoader.parse(mainRulesJson);
}

String _t(String key) => _i18nMap[key] ?? key;

String _getBrightnessLabel(int level) {
  const labels = ["陷", "不", "平", "利", "得", "旺", "庙"];
  return (level >= 0 && level < labels.length) ? labels[level] : "";
}

String _getBureauName(FiveElementBureau bureau) {
  switch (bureau) {
    case FiveElementBureau.water2:
      return "水二局";
    case FiveElementBureau.wood3:
      return "木三局";
    case FiveElementBureau.metal4:
      return "金四局";
    case FiveElementBureau.earth5:
      return "土五局";
    case FiveElementBureau.fire6:
      return "火六局";
    default:
      return "未知局";
  }
}

String _calculateRelativeName(int mingIndex, int targetIndex, String prefix) {
  const names = ["命宫", "兄弟", "夫妻", "子女", "财帛", "疾厄", "迁移", "交友", "官禄", "田宅", "福德", "父母"];
  final nameIndex = (12 - (targetIndex - mingIndex + 12) % 12) % 12;
  return "$prefix${names[nameIndex]}";
}