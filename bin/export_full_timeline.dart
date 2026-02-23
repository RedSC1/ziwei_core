import 'dart:convert';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/ziwei_core.dart';

/// 完整时间线输出 Demo
/// 输出：大限表 → 流年表 → 流月表 → 流日表 → 流时表
void main() {
  final encoder = JsonEncoder.withIndent('  ');
  final ruleset = ConfigLoader.getDefault();

  // 出生时间：2004年1月8日 辰时
  final birthTime = AstroDateTime(2004, 1, 8, 7, 30);
  final zDate = ZiweiDate.fromSolar(birthTime, gender: Gender.male);
  final plate = ZiweiEngine.calculate(zDate, ruleset);
  final provider = TimelineProvider(plate);

  // ========== 1. 大限表 (12个十年大限) ==========
  print("========== 1. 大限表 ==========");
  final decades = provider.getDecades();
  print(encoder.convert(decades.map((d) => d.toJson()).toList()));

  // ========== 2. 童限表 ==========
  print("\n========== 2. 童限表 ==========");
  final childhoods = provider.getChildhood();
  print(encoder.convert(childhoods.map((c) => c.toJson()).toList()));

  // ========== 3. 流年表 (第一大限的10个流年) ==========
  print("\n========== 3. 流年表 (第一大限) ==========");
  final years = provider.getYears(1);
  print(encoder.convert(years.map((y) => y.toJson()).toList()));

  // ========== 4. 流月表 (2026年的12个月) ==========
  print("\n========== 4. 流月表 (2026年) ==========");
  final months = provider.getMonths(2026);
  print(encoder.convert(months.map((m) => m.toJson()).toList()));

  // ========== 5. 流日表 (2026年正月) ==========
  print("\n========== 5. 流日表 (2026年 正月) ==========");
  final days = provider.getDays(2026, 1);
  print(encoder.convert(days.map((d) => d.toJson()).toList()));

  // ========== 6. 流时表 (取第一天的日干支来推时辰) ==========
  print("\n========== 6. 流时表 (基于正月第一天的日柱) ==========");
  if (days.isNotEmpty) {
    // 用第一天的日干支来推算该日的 12/13 个时辰
    final firstDayGanZhi = GanZhi(
      TianGan.values.firstWhere((g) => g.name == days.first.stem),
      DiZhi.values.firstWhere((z) => z.name == days.first.branch),
    );
    final hours = provider.getHours(firstDayGanZhi);
    print(
      "时辰总数: ${hours.length} (splitRatHour=${plate.ruleset.calendarOptions.splitRatHour})",
    );
    print(encoder.convert(hours.map((h) => h.toJson()).toList()));
  }
}
