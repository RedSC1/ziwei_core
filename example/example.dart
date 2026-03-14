import 'package:ziwei_core/ziwei_core.dart';

void main() {
  final ruleset = ConfigLoader.getDefault();

  print("====== 命盘推演 (测试) ======");

  final dt = AstroDateTime(2026, 2, 4, 19, 48);

  final date = ZiweiDate.fromSolar(
    dt,
    gender: Gender.male,
    useTrueSolarTime: false,
    options: ruleset.calendarOptions,
  );

  print('【历法解析结果】');
  print('阳历: ${date.solar}');
  print('农历: ${date.lunar.toString()} 时辰:${date.timeIndex}');
  print('八字: ${date.bazi}');
  print('');

  // 排盘
  final plate = ZiweiEngine.calculate(date, ruleset);

  print('【核心命盘信息】');
  print('命主: ${plate.mingZhu} | 身主: ${plate.shenZhu}');
  print('五行局: ${plate.elementBureau.name}');
  print('');

  // 打印该宫位内的所有星
  print('【十二宫分布】');
  for (var palace in plate.palaces) {
    // 判断该宫是不是命宫、身宫
    String tags = "";
    if (palace.index == plate.originMingPalace.index) tags += "[命宫] ";
    if (palace.index == plate.bodyPalace.index) tags += "[身宫] ";

    var allStarKeys = palace.allStars
        .map((s) => '${s.key}(${s.type.name})')
        .toList();
    print('地支[${palace.branch.name}] 宫干[${palace.stem?.name ?? ""}] $tags');
    print('  - 星曜: $allStarKeys');
  }
}
