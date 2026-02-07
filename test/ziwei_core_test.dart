import 'dart:convert'; // ✅ 必须加这个，不然 jsonDecode 报错
import 'dart:io';
import 'package:test/test.dart';

// 把没用的 import 清理一下，只留必要的
import 'package:ziwei_core/src/config/loader.dart';
import 'package:ziwei_core/src/core/engine.dart';
import 'package:ziwei_core/src/data/star.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';
import 'package:ziwei_core/src/enums/config_enums.dart';

// 测试专用辅助函数
Future<CalendarOptions> loadAllConfigsForTest() async {
  // 1. 读取规则 (Config)
  final rulesFile = File('assets/config/default/main_rules.json');
  if (!rulesFile.existsSync()) throw Exception("❌ 找不到 main_rules.json");
  final rulesStr = rulesFile.readAsStringSync();

  // 这里 ConfigLoader 会解析 brightness_labels 到静态变量里
  final options = ConfigLoader.parse(rulesStr);

  // 2. 读取星星表 (Stars)
  final starsFile = File('assets/config/default/stars.json');
  if (!starsFile.existsSync()) throw Exception("❌ 找不到 stars.json");
  final starsStr = starsFile.readAsStringSync();

  // 3. 读取亮度表 (Brightness)
  final brightnessFile = File('assets/config/default/brightness.json');
  String brightnessStr = "{}";
  if (brightnessFile.existsSync()) {
    brightnessStr = brightnessFile.readAsStringSync();
  }

  // 4. 解析星星
  ConfigLoader.parseStars(starsStr, brightnessStr);

  return options;
}

void main() {
  test('核心排盘 - 14主星验证', () async {
    // 1. 加载配置
    final options = await loadAllConfigsForTest();

    // 2. 手动加载 i18n 文件 (为了测试能打印汉字)
    final i18nFile = File('assets/i18n/zh_CN.json');
    if (!i18nFile.existsSync()) throw Exception("❌ 找不到 zh_CN.json");
    final Map<String, dynamic> i18n = jsonDecode(i18nFile.readAsStringSync());

    // 3. 准备时间
    var date = ZiweiDate.fromSolar(
      DateTime(2026, 2, 4, 19, 18),
      options: options,
    );

    // 4. 排盘计算
    var plate = ZiWeiEngine.calculate(date, ConfigLoader.stars);

    // 5. 打印结果
    print("\n====== 排盘结果 (${date.lunar.toString()}) ======");
    print("五行局: ${plate.elementBureau.label}");

    // 找紫微星在哪
    int ziweiIndex = plate.palaces.indexWhere((p) => p.hasStar('ziwei'));
    print("紫微在: $ziweiIndex 宫");

    // 遍历打印每个宫位
    for (var p in plate.palaces) {
      var starsInfo = p.stars
          .map((s) {
            // 1. 先把星星名字翻译出来
            // 记得加上前缀 "star_" 去查字典
            String starName = i18n["star_${s.key}"] ?? s.key;
            if (s is StaticStar) {
              int level = s.getBrightness(p.branch);
              String labelKey =
                  ConfigLoader.brightnessLabels[level] ?? "level_none";
              String labelText = i18n[labelKey] ?? "";

              // 输出中文名 + 中文亮度: 紫微(庙)
              return "$starName($labelText)";
            }
            return starName; // 如果没亮度，就光显名字
          })
          .join(", ");

      // 打印：[寅] 丑 : ziwei(庙), tianfu(旺)
      print("[${p.stem!.label}${p.branch.label}]: $starsInfo");
    } // for循环结束
  });
}
