import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:ziwei_core/ziwei_core.dart';

/// **🔥 基础/无状态 API 演示 (TimeMachine Demo)**
///
/// **💡 核心设计与使用建议：**
/// `TimeMachine.travel` 是底层纯函数（无状态），传入参数即一次性生成某个流运层级的静态上下文。
///
/// 而对于前端 UI 或需要持续流转推演的应用，强烈建议使用 `ZiweiLimitManager` (详见 `limit_manager_demo.dart`)。
/// `ZiweiLimitManager` 内部封装了 `TimeMachine`，但它是有状态的“时间播放器”，支持状态托管、
/// 从特定时间点自动提取干支（包含复杂的节气日时干支切割）以及“下一时辰/下一月”等步进操作。
///
/// `TimeMachine` 本身更适合单纯的数据提取或纯算法后端的高并发只读查询。
void main() async {
  print("==================================================");
  print("[TimeMachine] 动态星盘推演演示");
  print("==================================================\n");

  // 1. 初始化排盘配置与引擎规则
  final ruleset = ConfigLoader.getDefault();
  final options = ruleset.calendarOptions;

  // 2. 构建出生时间对象 (基准原点)
  final birthTime = AstroDateTime(2026, 2, 4, 19, 48);
  final ziweiDate = ZiweiDate.fromSolar(
    birthTime,
    gender: Gender.male,
    location: Location.beijing, // 若开启真太阳时需传入经纬度
    options: options,
  );

  // 3. 计算静态原局星盘
  final basePlate = ZiweiEngine.calculate(ziweiDate, ruleset);
  print('✅ [原局初始化完成] 命主五行局: ${basePlate.elementBureau.name}');

  // 4. 定义目标推演时刻的参数上下文
  // 示例场景:
  // 获取命主在 "2027年" 的 "农历正月 04日" 的 "申时" 运势盘。
  //
  // 【关键注意】：由于流日的干支排列（六十甲子）并不与“初一、初二”这种数字强绑定，
  // 流时的天干又必须通过“五鼠遁日”以当日日干作为基准来推演，
  // 所以，若想让引擎运算出真正的【流日盘】和【流时盘】，
  // 必须手动注入当日的真实物理八字干支 (dayGanZhi)。如果不传，推演将提前截止于流月。
  final targetDayGanzhi = GanZhi(TianGan.yi, DiZhi.chou);

  // 触发推演引擎
  // 这里传入的时间是农历时间
  final context = TimeMachine.travel(
    basePlate,
    year: 2027, // 目标流年
    month: 1, // 目标流月
    day: 4, // 目标流日
    hourIndex: DiZhi.shen.index, // 目标流时地支索引
    dayGanZhi: targetDayGanzhi, // 必须注入日柱干支，方可激活日、时流曜计算！
  );

  // 5. 生成最终的动态叠加星盘
  final dynamicPlate = ZiweiEngine.calculateDynamic(context);

  print('\n>>> 动态流运上下文构建成功 <<<');

  if (context.hasDecade) {
    print(
      '当前大限: ${context.decade!.ganzhi.gan.name}${context.decade!.ganzhi.zhi.name} (虚岁 ${context.decade!.startTime}~${context.decade!.endTime})',
    );
  }
  if (context.hasYear) {
    print(
      '当前流年: ${context.year!.ganzhi.gan.name}${context.year!.ganzhi.zhi.name}',
    );
  }
  if (context.hasMonth) {
    print(
      '当前流月: ${context.month!.ganzhi.gan.name}${context.month!.ganzhi.zhi.name}',
    );
  }
  if (context.hasDay) {
    print(
      '当前流日: ${context.day!.ganzhi.gan.name}${context.day!.ganzhi.zhi.name}',
    );
  }
  if (context.hasHour) {
    print(
      '当前流时: ${context.hour!.ganzhi.gan.name}${context.hour!.ganzhi.zhi.name}',
    );
  }

  print('\n--- [指定宫位星曜叠加枚举: 寅宫 (Index 2)] ---');
  final targetPalace = dynamicPlate.palaces[DiZhi.yin.index];

  // 遍历并打印该宫位内的所有星曜（静态本命星 + 动态流曜）及其亮度评级
  for (var star in targetPalace.allStars) {
    int brightness = -1;
    if (star is StaticStar) {
      brightness = star.getBrightness(targetPalace.branch);
    }
    if (star is FlowStar) {
      brightness = star.getBrightness(targetPalace.branch);
    }

    print("- ${star.key} (亮度: $brightness)");
  }

  print('\n✅ 演示结束。');
}
