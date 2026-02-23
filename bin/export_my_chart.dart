import 'dart:convert';
import 'package:ziwei_core/ziwei_core.dart';

void main() {
  print("==================================================");
  print("🔮 紫微斗数排盘及流运 JSON 序列化 Demo");
  print("👤 出生信息: 2004-02-28 12:30 (公历)");
  print("==================================================\n");

  // 1. 加载默认引擎配置规则
  final ruleset = ConfigLoader.getDefault();

  // 2. 设定出生时间
  final birthTime = DateTime(1, 1, 28, 2, 30);
  final zDate = ZiweiDate.fromSolar(birthTime, gender: Gender.male);

  // 3. 驱动引擎计算命盘主体 (原局紫微盘)
  final plate = ZiweiEngine.calculate(zDate, ruleset);

  // 4. 使用 LimitManager 开启流运引擎
  final manager = ZiweiLimitManager(plate);

  // 设定推演时间：当前时刻
  manager.setPhysicalDate(AstroDateTime(9, 1, 28, 2, 30));

  // 5. 【核心展示】获取年度流运清单全家桶 (Full Manifest)
  // 现在可以直接调用 getFullManifest()，这套强类型结构体原生地包含了：童限、大限、流年展开、流月，全部自洽！
  final manifest = manager.getFullManifest();

  print("--- 综合流运状态清单 (JSON) ---");
  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(manifest.toJson()));

  print("\n==================================================");
  print("🚀 成功导出年度流运快照");
  print("==================================================");
}
