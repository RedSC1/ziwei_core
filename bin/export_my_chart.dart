import 'dart:convert';
import 'package:ziwei_core/ziwei_core.dart';
import 'package:bazi_core/bazi_core.dart';
import 'package:ziwei_core/src/data/limit.dart'; // 用于读取未公开的大限和流月工厂方法

void main() {
  print("==================================================");
  print("🔮 紫微斗数排盘及流运 JSON 序列化 Demo");
  print("👤 出生信息: 2003-08-28 02:30 (公历)");
  print("==================================================\n");

  // 1. 加载默认引擎配置规则
  final ruleset = ConfigLoader.getDefault();

  // 2. 设定出生时间
  final birthTime = DateTime(2003, 8, 28, 2, 30);
  final zDate = ZiweiDate.fromSolar(birthTime, gender: Gender.male);

  // 3. 驱动引擎计算命盘主体 (原局紫微盘)
  final plate = ZiweiEngine.calculate(zDate, ruleset);

  // 4. 时光机穿梭到此刻 DateTime.now()
  // 首先需要把当前的时间转化为紫微历法底层时间，以获取准确的年份和农历月份
  final now = DateTime.now();
  final zNowDate = ZiweiDate.fromSolar(
    now,
    gender: Gender.male,
    options: plate.date.options,
  );

  // 驱动流运切片引擎 (推演到：流年、流月、流日、流时)
  final limitContext = TimeMachine.travel(
    plate,
    year: zNowDate.lunar.lunarYear,
    month: zNowDate.lunar.month,
    day: zNowDate.lunar.day,
    dayGanZhi: zNowDate.bazi.day, // 推导流日和流时必须有当日的基础干支坐标
    hourIndex: zNowDate.timeIndex,
  );

  // 💥 关键点: 借助上下文计算得出附带流曜与流派四化的「动态流盘」
  final dynamicPlate = ZiweiEngine.calculateDynamic(limitContext);

  // 5. 组建给前端的时间导航条元数据 (Timeline Manifest)
  // 借助统一门面 TimelineProvider，让引擎依据底盘的历法规则，帮前端一键生成！
  final timeline = TimelineProvider(plate);
  int currentYear = limitContext.year!.year;

  // 6. 将结果转换为纯净数据字典
  final result = {
    // 实际业务中，你可以只输出 dynamic_plate，这是被贴满了流年四化的最终盘面
    "dynamic_plate": dynamicPlate.toJson(),

    // 附带流运的干支及游标坐标数据
    "flow_context": limitContext.toJson(),

    // 送给前端画“左右滑动导航栏”用的极简日历元数据
    "timeline_manifest": timeline.generateManifest(currentYear),
  };

  final prettyJson = JsonEncoder.withIndent('  ').convert(result);

  print(prettyJson);

  print("\n==================================================");
  print("✅ 控制台输出流盘完成！'flow_context' 里包含了精准此时此刻的漫游切片坐标。");
  print("==================================================");
}
