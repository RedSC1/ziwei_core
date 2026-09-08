import 'package:ziwei_core/ziwei_core.dart';

void main() {
  final options = ZiweiOptions(gender: ZiweiGender.male);
  final chart = ZiweiChart.fromZonedTime(
    ZonedTime(year: 2000, month: 1, day: 1, hour: 12, offsetMinutes: 480),
    options,
  );
  final changed = chart
      .modify(ZiweiModifyInput(month: 8, updateBureau: true))
      .shiftLifePalace(2);
  print(
    '原五行局 ${chart.anchors.bureau.number}，修改后 ${changed.anchors.bureau.number}',
  );
  print('复原到原对象：${identical(changed.reset(), chart)}');
  final manager = chart.createLimitManager();
  manager.setYear(2023);
  manager.setMonth(2, isLeap: true, effectiveMonth: 2);
  manager.setDay(10);
  manager.setHour(0);
  print('动态盘层数：${manager.dynamicChart.flowStack.length}');
  final cast = ZiweiCastingChart.fromNumber('123', options);
  print('报数对应序号：${cast.casting['index']}');
  final ruleset = ZiweiConfigLoader.overrideWith(
    ZiweiRuleset(),
    label: 'extra',
    starsJson:
        '[{"key":"extra","type":"minor","rule":{"type":"constant","value":4}}]',
  );
  final custom = ZiweiChart.fromZonedTime(
    chart.birthClockTime!,
    options.copyWith(rules: options.rules.copyWith(ruleset: ruleset)),
  );
  print(
    '自定义星位置：${custom.getStarPosition(custom.findStarId('extra')!)!.branch}',
  );
}
