import 'package:ziwei_core/ziwei_core.dart';

void main() {
  final ruleset = ConfigLoader.getDefault();

  final dt = AstroDateTime(2026, 2, 4, 19, 48);
  final date = ZiweiDate.fromSolar(
    dt,
    gender: Gender.male,
    useTrueSolarTime: false,
    options: ruleset.calendarOptions,
  );

  print('阳历: ${date.solar}');
  print('农历: ${date.lunar} 时辰:${date.timeIndex}');
  print('八字: ${date.bazi}');
  print('');

  for (final pan in TDRpan.values) {
    final label = switch (pan) {
      TDRpan.tianPan => '天盘',
      TDRpan.diPan => '地盘',
      TDRpan.renPan => '人盘',
    };

    final plate = ZiweiEngine.calculate(date, ruleset, tdrPan: pan);
    final ming = plate.originMingPalace;

    print('====== $label ======');
    print('命宫: ${ming.stem?.name ?? ""}${ming.branch.name} (index=${ming.index})');
    print('五行局: ${plate.elementBureau.label}');

    // 命宫星曜
    final stars = ming.allStars.map((s) => s.key).join(', ');
    print('命宫星曜: $stars');
    print('');
  }
}
