import 'dart:convert';
import 'dart:io';
import 'package:ziwei_core/ziwei_core.dart';

// 简单的 i18n 缓存
Map<String, String> _i18nMap = {};

void main() async {
  // 🚩 1. 加载规则
  final ruleset = await _loadConfig();
  final options = ruleset.calendarOptions;

  final birthday = DateTime(2003, 7, 26, 23, 30);

  print('🔨 正在初始化日期引擎 (Options: 早晚子=${options.splitRatHour})...');
  final ziweiDate = ZiweiDate.fromSolar(
    birthday,
    gender: Gender.male,
    options: options,
  );

  // 3. 计算原盘
  print('🧱 正在安星布盘...');
  final basePlate = ZiweiEngine.calculate(ziweiDate, ruleset);

  // 4. 交给状态管理器托管
  print('🔮 初始化时间流驱动引擎 (ZiweiLimitManager)...');
  final manager = ZiweiLimitManager(basePlate);

  // 5. 将时光抛瞄到任意绝对流运时刻 (这里测试极端的 23:30 晚子跨天截点)
  final targetTime1 = DateTime(2024, 7, 10, 23, 30);
  print('🚀 启动时光机前往时刻 [一]: $targetTime1...');
  manager.setPhysicalDate(targetTime1);
  final dynamicPlate1 = manager.dynamicPlate;
  _printHeader(manager, dynamicPlate1);

  print('----------------------------------------------------------------');

  // 6. 演示流时步进，直接 + 1 个时辰 (2小时) 跳入早子时或者下个时区
  print('⏭️ UI 触发: 点击【下一时辰】按钮...');
  manager.nextHour();

  final targetTime2 = manager.currentDate!.solar.toDateTime();
  print('🚀 此时物理时钟已变为 [二]: $targetTime2...');
  final dynamicPlate2 = manager.dynamicPlate;
  _printHeader(manager, dynamicPlate2);

  print('======================== [最终流运盘面] ========================');

  print('----------------------------------------------------------------');

  // 7. 遍历 12 宫 (打印最新盘面)
  for (int i = 0; i < 12; i++) {
    _printPalaceInfo(dynamicPlate2, dynamicPlate2.palaces[i]);
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
  final starsOutput = palace.allStars
      .map((s) {
        final sb = StringBuffer();
        sb.write(_t("star_${s.key}"));

        // 亮度计算
        int bLevel = -1;
        if (s is StaticStar) bLevel = s.getBrightness(palace.branch);
        if (s is FlowStar) bLevel = s.getBrightness(palace.branch);
        if (bLevel >= 0) sb.write("(${_getBrightnessLabel(bLevel)})");

        // 四化标记
        if (s is StaticStar) {
          if (s.siHuaBuff[ZiweiScope.origin] != null)
            sb.write(
              "{生${_t("sihua_${s.siHuaBuff[ZiweiScope.origin]!.name}")}}",
            );
          if (s.siHuaBuff[ZiweiScope.decade] != null)
            sb.write(
              "{大${_t("sihua_${s.siHuaBuff[ZiweiScope.decade]!.name}")}}",
            );
          if (s.siHuaBuff[ZiweiScope.year] != null)
            sb.write("{流${_t("sihua_${s.siHuaBuff[ZiweiScope.year]!.name}")}}");
        }

        // 流曜标记
        if (s is FlowStar) {
          if (s.key.contains("decade")) sb.write("[大]");
          if (s.key.contains("year")) sb.write("[年]");
        }

        return sb.toString();
      })
      .join(", ");

  print("$ganzhi ${roleStr.padRight(25)} : $starsOutput");
}

// --- 辅助逻辑函数 ---

void _printHeader(ZiweiLimitManager manager, ZiWeiPlate plate) {
  final ctx = manager.limitContext;
  final d = manager.currentDate!;

  print('\n=== [当前时光快照: ${d.solar.toString()}] ===');
  print('📌 流传八字: ${d.bazi}');

  if (ctx.hasYear) {
    final gz = ctx.year!.ganzhi;
    print(
      '🐎 流年: ${gz.gan.label}${gz.zhi.label} [索引:${gz.zhi.index}] (${_getSiHuaStr(gz.gan, plate.ruleset)})',
    );
  }
  if (ctx.hasMonth) {
    final gz = ctx.month!.ganzhi;
    print(
      '🌙 流月: ${gz.gan.label}${gz.zhi.label} (${_getSiHuaStr(gz.gan, plate.ruleset)})',
    );
  }
  if (ctx.hasDay) {
    final gz = ctx.day!.ganzhi;
    print(
      '☀️ 流日: ${gz.gan.label}${gz.zhi.label} (${_getSiHuaStr(gz.gan, plate.ruleset)})',
    );
  }
  if (ctx.hasHour) {
    final gz = ctx.hour!.ganzhi;
    print(
      '⏳ 流时: ${gz.gan.label}${gz.zhi.label} (${_getSiHuaStr(gz.gan, plate.ruleset)})',
    );
  }
}

// 加载配置
Future<ZiweiRuleset> _loadConfig() async {
  final i18nJson = await File('assets/i18n/zh_CN.json').readAsString();
  _i18nMap = Map<String, String>.from(jsonDecode(i18nJson));

  return ConfigLoader.getDefault();
}

String _t(String key) => _i18nMap[key] ?? key;

String _getSiHuaStr(TianGan gan, ZiweiRuleset ruleset) {
  final rules = ruleset.siHuaRules[gan];
  if (rules == null) return "未知";
  return "${rules[SiHuaType.lu]}禄 ${rules[SiHuaType.quan]}权 ${rules[SiHuaType.ke]}科 ${rules[SiHuaType.ji]}忌";
}

String _getBureauLabel(FiveElementBureau bureau) {
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
  }
}

String _getBrightnessLabel(int level) {
  const labels = ["陷", "不", "平", "利", "得", "旺", "庙"];
  return (level >= 0 && level < labels.length) ? labels[level] : "?";
}

String _calculateRelativeName(int mingIndex, int targetIndex, String prefix) {
  const names = [
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
  final nameIndex = (12 - (targetIndex - mingIndex + 12) % 12) % 12;
  return "$prefix${names[nameIndex]}";
}
