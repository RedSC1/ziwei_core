import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';
import 'package:sxwnl_spa_dart/src/sxwnl/ssq.dart';

void main() {
  var ssq = SSQ();

  // 关键年份对比
  var years = [7, 8, 9, 10, 22, 23, 24, 25];

  for (var year in years) {
    // 用年初和年中两个时间点
    var dt1 = AstroDateTime(year, 1, 1, 12, 0);
    var dt2 = AstroDateTime(year, 6, 15, 12, 0);

    var result1 = ssq.calcY(dt1.toJ2000());
    var result2 = ssq.calcY(dt2.toJ2000());

    print("=== 公元${year}年 ===");
    print("1月1日 月名: ${result1.ym}");
    print("6月15日 月名: ${result2.ym}");
    print("");
  }
}
