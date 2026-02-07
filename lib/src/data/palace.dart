import '../enums/config_enums.dart';
import 'star.dart'; // 引用星星定义

class Palace {
  // 1. 地支索引 (0=子, 1=丑 ... 11=亥) - 这是死的，初始化后不可变
  final int index;

  // 2. 对应的地支枚举 (方便调试和显示，自动根据index算出来)
  DiZhi get branch => DiZhi.values[index];

  // 3. 宫干 (天干) - 活的，排盘时通过“五虎遁”算出来填进去
  TianGan? stem;

  // 5. 住在这里的星星列表 - 活的，安星时一颗颗塞进去
  List<Star> stars = [];

  // --- 构造函数 ---
  // 创建时只需要指定它是第几个格子(index)，其他的后面填
  Palace(this.index, {this.stem});

  // --- 辅助方法 ---

  // 往宫里安一颗星
  void addStar(Star star) {
    stars.add(star);
  }

  // 方便调试打印看结果，不仅看地支，还能看到里面的星星
  @override
  String toString() {
    // 效果：[丙子] 命宫: Star(紫微), Star(天府)
    String stemStr = stem?.label ?? "?"; // 如果没算出来显示?
    String branchStr = branch.label;
    return "[$stemStr$branchStr]: $stars";
  }
}
