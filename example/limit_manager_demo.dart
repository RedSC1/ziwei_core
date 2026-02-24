import 'package:ziwei_core/ziwei_core.dart';

/// **状态推演引擎交互式演示 (ZiweiLimitManager API)**
///
/// 展示如何利用 `ZiweiLimitManager` 进行时间状态托管，
/// 动态输入物理时间，并连续推演（例如逐个时辰递进）。
void main() async {
  print("==================================================");
  print("[ZiweiLimitManager] 流运状态机演示");
  print("==================================================\n");

  // 1. 初始化引擎配置
  final ruleset = ConfigLoader.getDefault();
  final options = ruleset.calendarOptions;

  final birthday = DateTime(2003, 7, 26, 23, 30);
  print('初始化引擎配置 (基准时间: $birthday)...');

  final ziweiDate = ZiweiDate.fromSolar(
    birthday,
    gender: Gender.male,
    options: options,
  );

  // 2. 生成静态原局命盘
  print('预计算静态原局命盘...');
  final basePlate = ZiweiEngine.calculate(ziweiDate, ruleset);

  // 3. 将原局托管给时间流状态机
  print('挂载至 ZiweiLimitManager 状态机...');
  final manager = ZiweiLimitManager(basePlate);

  // 4. 定位至特定绝对时间推演点
  // 示例: 定位至 2024年7月10日 23:30 (测试子时切割)
  final targetTime1 = DateTime(2024, 7, 10, 23, 30);
  print('\n[步骤 1] 定位至物理时间: $targetTime1');

  // 引擎将根据给定物理时间，逆向求解所有层级的流运维度信息（大限、流年、流月、流日、流时）
  manager.setPhysicalDate(targetTime1);
  final dynamicPlate1 = manager.dynamicPlate; // 获取包含完整流曜的叠加星盘

  _printSnapshotInfo(manager, dynamicPlate1);

  // 5. 交互式流运推演 (步进控制)
  print('\n[步骤 2] 触发时间推演: 时辰前进 1 步 (nextHour)...');

  // 状态机往前步进一个时辰，引擎内部将自动处理：
  // 跨越子时（早子/晚子）、日界线、以及相应的跨月或跨年逻辑。
  manager.nextHour();

  final targetTime2 = manager.currentDate!.solar.toDateTime();
  print('当前内部物理时间变更为: $targetTime2');

  final dynamicPlate2 = manager.dynamicPlate;
  _printSnapshotInfo(manager, dynamicPlate2);

  print('\n✅ 演示结束。');
}

/// 打印特定时间快照下的流运信息
void _printSnapshotInfo(ZiweiLimitManager manager, ZiWeiPlate plate) {
  final ctx = manager.limitContext;
  final d = manager.currentDate!;

  print('--------------------------------------------------');
  print('时间快照: ${d.solar.toString()}');
  print('解析八字: ${d.bazi}');

  if (ctx.hasYear) {
    print('当前流年: ${ctx.year!.ganzhi.gan.name}${ctx.year!.ganzhi.zhi.name}');
  }
  if (ctx.hasMonth) {
    print('当前流月: ${ctx.month!.ganzhi.gan.name}${ctx.month!.ganzhi.zhi.name}');
  }
  if (ctx.hasDay) {
    print('当前流日: ${ctx.day!.ganzhi.gan.name}${ctx.day!.ganzhi.zhi.name}');
  }
  if (ctx.hasHour) {
    print('当前流时: ${ctx.hour!.ganzhi.gan.name}${ctx.hour!.ganzhi.zhi.name}');
  }

  // 获取当前命盘计算上下文中，流时所在的命宫
  final currentHourPalace = plate.palaces[plate.hourMingIndex ?? 0];
  print(
    '流时命宫驻扎地: 地支${currentHourPalace.branch.name}宫 (该宫位内叠加星曜总数: ${currentHourPalace.allStars.length})',
  );
  print('--------------------------------------------------');
}
