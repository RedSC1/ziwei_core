import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/enums/scope.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

Future<CalendarOptions> loadAllConfigsForTest() async {
  // ... 代码同上 ...
  final rulesFile = File('assets/config/default/main_rules.json');
  final starsFile = File('assets/config/default/stars.json');
  final brightnessFile = File('assets/config/default/brightness.json');
  final sihuaFile = File('assets/config/default/sihua.json'); // ✅ 新增

  if (!rulesFile.existsSync() || !starsFile.existsSync()) {
    throw Exception("❌ 配置文件缺失！");
  }

  // 1. 加载规则
  final options = ConfigLoader.parse(rulesFile.readAsStringSync());

  // 2. 加载星星和亮度
  String brightnessStr = brightnessFile.existsSync()
      ? brightnessFile.readAsStringSync()
      : "{}";
  ConfigLoader.parseStars(starsFile.readAsStringSync(), brightnessStr);

  // 3. ✅ 加载四化规则
  if (sihuaFile.existsSync()) {
    ConfigLoader.parseSiHua(sihuaFile.readAsStringSync());
    print("✅ Test Loaded SiHua Rules: ${ConfigLoader.siHuaRules.length} stems");
  } else {
    print("❌ Error: SiHua file not found at ${sihuaFile.path}");
  }

  return options;
}

void main() {
  test('v0.0.2', () async {
    // 1. 加载配置
    final options = await loadAllConfigsForTest();

    // 2. 加载翻译
    final i18nFile = File('assets/i18n/zh_CN.json');
    if (!i18nFile.existsSync()) throw Exception("❌ 找不到 zh_CN.json");
    final Map<String, dynamic> i18n = jsonDecode(i18nFile.readAsStringSync());

    // 3. 设定时间
    var date = ZiweiDate.fromSolar(
      DateTime(2026, 2, 4, 19, 48),
      options: options,
    );

    // 4. 计算排盘 (✅ 修复调用参数)
    var plate = ZiWeiEngine.calculate(
      date,
      ConfigLoader.stars,
      ConfigLoader.siHuaRules,
    );

    // 5. 打印报表
    print("\n====== 🟣 排盘结果 (${date.lunar}) ======");
    print("🎯 五行局: ${plate.elementBureau.label}");
    print(
      "✨ 生年四化: ${date.getGanZhi(ZiweiScope.origin)!.gan.name}干",
    ); // 打印一下年干方便核对

    // 遍历12宫 (我们需要 index 来反查角色)
    for (int i = 0; i < 12; i++) {
      var p = plate.palaces[i];

      // 🔥 核心修改：动态查询这一格是干嘛的 (查本命盘 Origin)
      PalaceRole role = plate.getRole(ZiweiScope.origin, i);

      // 查翻译: role_life -> "命宫"
      String roleKey = "role_${role.name}";
      String roleName = i18n[roleKey] ?? role.debugLabel; // 查不到就用默认label

      // 处理星星信息
      var starsInfo = p.stars
          .map((s) {
            String starName = i18n["star_${s.key}"] ?? s.key;
            if (s is StaticStar) {
              // 1. 亮度
              int level = s.getBrightness(p.branch);
              String labelKey = ConfigLoader.brightnessLabels[level] ?? "";
              String labelText = i18n[labelKey] ?? "";

              // 2. ✅ 四化 (查原局) - 动态 i18n 写法
              String sihuaText = "";
              if (s.siHuaBuff.containsKey(ZiweiScope.origin)) {
                var type = s.siHuaBuff[ZiweiScope.origin]!;
                // 拼接 key: sihua_lu, sihua_quan ...
                String key = "sihua_${type.name}";
                // 查表，查不到就显示默认 name
                String label = i18n[key] ?? type.name;
                sihuaText = "($label)";
              }

              return "$starName($labelText)$sihuaText";
            }
            return starName;
          })
          .join(", ");

      // 打印：[寅] (命宫) : 紫微(庙)(权)...
      print("[${p.stem?.label}${p.branch.label}] ($roleName) : $starsInfo");
    } // for循环结束
  });
}
