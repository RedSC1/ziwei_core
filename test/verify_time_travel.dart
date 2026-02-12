import 'dart:convert';
import 'dart:io';
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

  // 1. 创建命主时间 (1990年出生，方便看大运)
  final birthday = DateTime(1990, 7, 29, 2, 23);
  final ziweiDate = ZiweiDate.fromSolar(birthday, gender: Gender.male);

  // 2. 计算原盘
  print('🔨 计算原盘...');
  final basePlate = ZiWeiEngine.calculate(
    ziweiDate,
    ConfigLoader.stars,
    ConfigLoader.siHuaRules,
  );

  // 3. 时光穿梭到 2026 年 (丙午年)
  // 1990生，2026年虚岁约 37岁
  print('🚀 启动时光机前往 2026 (丙午年)...');
  final context = TimeMachine.travel(basePlate, year: 2026);
  final dynamicPlate = ZiWeiEngine.calculateDynamic(context);

  // 4. 打印头部信息
  print('\n=== 🔮 2026 全维流运验证 🔮 ===');
  print(
    '📅 生日: ${birthday.toString()} (${ziweiDate.bazi.year.gan.label}${ziweiDate.bazi.year.zhi.label}命)',
  );

  if (context.hasDecade) {
    print(
      '⏳ 大限: ${context.decade!.ganzhi.gan.label}${context.decade!.ganzhi.zhi.label} [${context.decade!.startTime}-${context.decade!.endTime}岁] (大限四化: ${_getSiHuaString(context.decade!.ganzhi.gan)})',
    );
  }

  if (context.smallLimit != null) {
    print(
      '👶 小限: ${context.smallLimit!.ganzhi.gan.label}${context.smallLimit!.ganzhi.zhi.label} [${context.smallLimit!.age}岁] (小限四化: ${_getSiHuaString(context.smallLimit!.ganzhi.gan)})',
    );
  }

  if (context.hasYear) {
    print(
      '🐎 流年: ${context.year!.ganzhi.gan.label}${context.year!.ganzhi.zhi.label} (2026) (流年四化: ${_getSiHuaString(context.year!.ganzhi.gan)})',
    );
  }

  print('----------------------------------------------------------------');

  // 5. 遍历打印 12 宫
  for (int i = 0; i < 12; i++) {
    _printPalaceInfo(dynamicPlate, dynamicPlate.palaces[i]);
  }
}

// 辅助：打印宫位详情
void _printPalaceInfo(ZiWeiPlate plate, Palace palace) {
  final ganzhi = "[${palace.stem!.label}${palace.branch.label}]";

  // 1. 宫职信息
  final roles = <String>[];
  // 原局
  roles.add(_calculateRelativeName(plate.originMingIndex, palace.index, ""));
  // 大限
  if (plate.decadeMingIndex != null && plate.decadeMingIndex == palace.index)
    roles.add("★大限命宫");
  // 小限
  if (plate.smallLimitMingIndex != null &&
      plate.smallLimitMingIndex == palace.index)
    roles.add("☆小限命宫");
  // 流年
  if (plate.yearMingIndex != null && plate.yearMingIndex == palace.index)
    roles.add("▲流年命宫");

  String roleStr = "(${roles.join("/")})";

  // 2. 星曜列表
  final starsOutput = palace.stars
      .map((s) {
        final sb = StringBuffer();

        // --- 名字 ---
        // 如果是流曜，key 类似 flow_year_lucun
        // 我们尝试从 i18n 取，取不到就显示 key
        String displayName = _t("star_${s.key}");
        // 没翻译的话，手动美化一下以便调试
        if (displayName.startsWith("star_flow_")) {
          displayName = s.key.replaceAll("flow_", "").replaceAll("_", ".");
        }
        sb.write(displayName);

        // --- 亮度 ---
        if (s is StaticStar || s is FlowStar) {
          int bLevel = 0;
          if (s is StaticStar) bLevel = s.getBrightness(palace.branch);
          if (s is FlowStar) bLevel = s.getBrightness(palace.branch);
          sb.write("(${_getBrightnessLabel(bLevel)})");
        }

        // --- 四化 (只针对原局星) ---
        if (s is StaticStar) {
          if (s.siHuaBuff[ZiweiScope.decade] != null)
            sb.write(
              "{大限${_t("sihua_${s.siHuaBuff[ZiweiScope.decade]!.name}")}}",
            );
          if (s.siHuaBuff[ZiweiScope.year] != null)
            sb.write(
              "{流年${_t("sihua_${s.siHuaBuff[ZiweiScope.year]!.name}")}}",
            );
          if (s.siHuaBuff[ZiweiScope.smallLimit] != null)
            sb.write(
              "{小限${_t("sihua_${s.siHuaBuff[ZiweiScope.smallLimit]!.name}")}}",
            );
        }

        // 标记一下流曜类型
        if (s is FlowStar) {
          if (s.key.contains("decade")) sb.write("[大]");
          if (s.key.contains("year")) sb.write("[年]");
          if (s.key.contains("smallLimit")) sb.write("[小]");
        }

        return sb.toString();
      })
      .join(", ");

  print("$ganzhi ${roleStr.padRight(25)} : $starsOutput");
}

String _t(String key) {
  return _i18nMap[key] ?? key;
}

String _getSiHuaString(TianGan gan) {
  if (!ConfigLoader.siHuaRules.containsKey(gan)) return "";
  final map = ConfigLoader.siHuaRules[gan]!;
  return "${map[SiHuaType.lu]}禄 ${map[SiHuaType.quan]}权 ${map[SiHuaType.ke]}科 ${map[SiHuaType.ji]}忌";
}

String _getBrightnessLabel(int level) {
  switch (level) {
    case 6:
      return "庙"; // flow_stars.json 里我配的 6
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
    case -1:
      return "?";
    default:
      return "$level";
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
  final flowJson = await File(
    'assets/config/default/flow_stars.json',
  ).readAsString(); // 🔥 加载流曜配置

  // 加载 i18n
  final i18nJson = await File('assets/i18n/zh_CN.json').readAsString();
  _i18nMap = Map<String, String>.from(jsonDecode(i18nJson));

  ConfigLoader.parseStars(starsJson, brightnessJson);
  ConfigLoader.parseSiHua(sihuaJson);
  ConfigLoader.parseFlowStars(flowJson); // 🔥 解析流曜
}
