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

  // 5. 【核心展示】获取年度流运清单 (Manifest)
  final manifest = manager.currentManifest;

  // 额外福利：获取当前大限内的 10 个流年列表（通常是用户点击某个大限后动态拉取）
  final timeline = TimelineProvider(plate);
  final currentDecadeIndex = manager.limitContext.decade?.decadeIndex ?? 1;
  final decadeYears = timeline.getYears(currentDecadeIndex);

  // 拼装一个给前端看的终极响应包，注意顺序：童限 -> 大限 -> 流年 -> 流月
  final responsePayload = {
    'childhoods': manifest.childhoods.map((e) => e.toJson()).toList(),
    'decades': manifest.decades.map((e) => e.toJson()).toList(),
    'current_decade_years': decadeYears.map((e) => e.toJson()).toList(),
    'current_year_months': manifest.currentYearMonths
        .map((e) => e.toJson())
        .toList(),
    'status': manifest.status.toJson(),
  };

  print("--- 综合流运状态清单 (JSON) ---");
  final encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(responsePayload));

  print("\n==================================================");
  print("🚀 成功导出年度流运快照");
  print("==================================================");
}
