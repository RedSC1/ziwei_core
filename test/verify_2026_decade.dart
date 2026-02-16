import 'dart:convert';
import 'dart:io';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/data/limit.dart';
import 'package:ziwei_core/src/data/plate.dart';
import 'package:ziwei_core/src/data/palace.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/enums/star_enums.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/gan_zhi.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

// 简单的 i18n 缓存
Map<String, String> _i18nMap = {};

void main() async {
  await _loadConfig();

  // 1. 创建命主时间
  final birthday = AstroDateTime(-105, 6, 16, 11, 30);
  final ziweiDate = ZiweiDate.fromSolar(birthday, gender: Gender.male);

  // 2. 计算原盘
  final basePlate = ZiWeiEngine.calculate(
    ziweiDate,
    ConfigLoader.stars,
    ConfigLoader.siHuaRules,
  );

  // 3. 时光穿梭到 2026 年
  final context = TimeMachine.travel(basePlate, year: -100);
  final dynamicPlate = ZiWeiEngine.calculateDynamic(context);

  // 4. 打印头部信息
  print('\n=== 🔮 流年大限盘验证 🔮 ===');
  print(
    '📅 原局: ${ziweiDate.bazi.year.gan.label}${ziweiDate.bazi.year.zhi.label}年 (${birthday.year})',
  );
  print(
    '⏳ 大限: ${context.decade!.ganzhi.gan.label}${context.decade!.ganzhi.zhi.label} [${context.decade!.startTime}-${context.decade!.endTime}岁]',
  );
  print(
    '🐎 流年: ${context.year!.ganzhi.gan.label}${context.year!.ganzhi.zhi.label} ',
  );
  print('🎯 五行局: ${_getBureauName(basePlate.elementBureau)}');
  print('✨ 生年四化: ${ziweiDate.bazi.year.gan.label}干');
  print('📋 八字: ${ziweiDate.bazi}');
  print('');

  // 5. 遍历打印 12 宫
  // 从子宫(0)开始打印到亥宫(11)
  for (int i = 0; i < 12; i++) {
    _printPalaceInfo(dynamicPlate, dynamicPlate.palaces[i]);
  }
}

// 辅助：打印宫位详情
void _printPalaceInfo(ZiWeiPlate plate, Palace palace) {
  // A. 宫干支 [甲寅]
  final ganzhi = "[${palace.stem!.label}${palace.branch.label}]";

  // B. 宫名 (原局) + [身宫]
  String originName =
      "(${_calculateRelativeName(plate.originMingIndex, palace.index, "")})";
  if (palace.index == plate.bodyPalaceIndex) {
    originName += "[身宫]";
  }

  // C. 宫名 (大限) - 你的要求里有这个
  final decadeName = _calculateRelativeName(
    plate.decadeMingIndex!,
    palace.index,
    "大限",
  );

  // D. 星曜列表
  final starsOutput = palace.stars
      .where((s) => s is StaticStar)
      .map((s) {
        final star = s as StaticStar;
        final sb = StringBuffer();

        // 1. 星名 (汉化)
        sb.write(_t("star_${star.key}"));

        // 2. 亮度 (汉化)
        // brightnessTable 存的是 -1, 0, 1... 对应 brightness.json 里的 key
        final brightnessLevel = star.getBrightness(palace.branch);
        // 这里简单映射一下，实际应该用 brightnessLabels
        sb.write("(${_getBrightnessLabel(brightnessLevel)})");

        // 3. 四化 (生年/大限/流年)
        // 生年四化
        if (star.siHuaBuff[ZiweiScope.origin] != null) {
          sb.write(
            "(${_t("sihua_${star.siHuaBuff[ZiweiScope.origin]!.name}")})",
          );
        }
        // 向心四化
        if (star.centripetalSiHua != null) {
          sb.write("[向心${_t("sihua_${star.centripetalSiHua!.name}")}]");
        }
        // 自化
        if (star.selfSiHua != null) {
          sb.write("[自化${_t("sihua_${star.selfSiHua!.name}")}]");
        }
        // 大限四化
        if (star.siHuaBuff[ZiweiScope.decade] != null) {
          sb.write(
            "(大限${_t("sihua_${star.siHuaBuff[ZiweiScope.decade]!.name}")})",
          );
        }
        // 流年四化
        if (star.siHuaBuff[ZiweiScope.year] != null) {
          sb.write(
            "(流年${_t("sihua_${star.siHuaBuff[ZiweiScope.year]!.name}")})",
          );
        }

        return sb.toString();
      })
      .join(", ");

  // 格式化输出: [甲寅] (迁移)(大限财帛) : 贪狼(平)(忌)(大限禄)
  // 为了对齐好看一点，加点空格
  print(
    "$ganzhi $originName".padRight(12) +
        " ($decadeName)".padRight(8) +
        " : $starsOutput",
  );
}

String _t(String key) {
  return _i18nMap[key] ?? key;
}

// 模拟 brightnessLabels (需与 brightness.json 对应)
String _getBrightnessLabel(int level) {
  switch (level) {
    case 6:
      return "庙";
    case 5:
      return "旺";
    case 4:
      return "得";
    case 3:
      return "利";
    case 2:
      return "平";
    case 1:
      return "不";
    case 0:
      return "陷";
    default:
      return "";
  }
}

String _getBureauName(FiveElementBureau bureau) {
  switch (bureau) {
    case FiveElementBureau.wood3:
      return "木三局";
    case FiveElementBureau.fire6:
      return "火六局";
    case FiveElementBureau.earth5:
      return "土五局";
    case FiveElementBureau.metal4:
      return "金四局";
    case FiveElementBureau.water2:
      return "水二局";
  }
}

String _calculateRelativeName(int mingIndex, int targetIndex, String prefix) {
  final offset = (targetIndex - mingIndex + 12) % 12;
  final nameIndex = (12 - offset) % 12;
  final names = [
    "命宫",
    "兄弟",
    "夫妻",
    "子女",
    "财帛",
    "疾厄",
    "迁移",
    "交友",
    "官禄",
    "田宅",
    "福德",
    "父母",
  ];
  return "$prefix${names[nameIndex]}";
}

Future<void> _loadConfig() async {
  final starsJson = await File(
    'assets/config/default/stars.json',
  ).readAsString();
  final brightnessJson = await File(
    'assets/config/default/brightness.json',
  ).readAsString();
  final sihuaJson = await File(
    'assets/config/default/sihua.json',
  ).readAsString();

  // 加载 i18n
  final i18nJson = await File('assets/i18n/zh_CN.json').readAsString();
  _i18nMap = Map<String, String>.from(jsonDecode(i18nJson));

  ConfigLoader.parseStars(starsJson, brightnessJson);
  ConfigLoader.parseSiHua(sihuaJson);
}
