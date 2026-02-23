import 'dart:convert';
import 'package:ziwei_core/ziwei_core.dart';

void main() {
  print("==================================================");
  print("🔮 紫微斗数排盘及流运 JSON 序列化 Demo");
  print("==================================================\n");

  // 1. 加载默认引擎配置规则
  final ruleset = ConfigLoader.getDefault();

  // 2. 设定出生时间
  final birthTime = AstroDateTime(1, 1, 8, 7, 30);
  final zDate = ZiweiDate.fromSolar(birthTime, gender: Gender.male);

  // 3. 驱动引擎计算命盘主体 (原局紫微盘)
  final plate = ZiweiEngine.calculate(zDate, ruleset);

  // 4. 使用 LimitManager 开启流运引擎
  final manager = ZiweiLimitManager(plate);

  // 设定推演时间：当前时刻
  manager.setPhysicalDate(AstroDateTime(9, 8, 8, 7, 30));

  // 5. 【核心展示】获取年度流运清单全家桶 (Full Manifest)
  // 现在可以直接调用 getFullManifest()，这套强类型结构体原生地包含了：童限、大限、流年展开、流月，全部自洽！
  final manifest = manager.getFullManifest();

  print("--- 综合流运状态清单 (Timeline JSON) ---");
  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(manifest.toJson()));

  print("\n--- 2026年 流运当下的紫微星盘 (Dynamic Plate JSON) ---");
  // manager.dynamicPlate 就是叠加了此时此刻（2026年）的大限、流年化星及流曜的终极实盘
  print(encoder.convert(manager.dynamicPlate.toJson()));

  print("\n==================================================");
  print("🚀 成功导出年度流运快照");
  print("==================================================");
}
