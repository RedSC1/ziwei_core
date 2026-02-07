class ZiweiPlacer {
  /// 安紫微星
  /// [day] 农历生日 (1-30)
  /// [bureau] 五行局数 (2,3,4,5,6)
  /// 返回: 紫微星的宫位索引 (0-11, 0是子宫)
  static int placeZiwei(int day, int bureau) {
    int quotient; // 商
    int remainder; // 补数 (注意：这里我们算的不是余数，是这就差多少能整除)

    if (day % bureau == 0) {
      // 1. 能整除：商直接定宫位
      quotient = day ~/ bureau;
      remainder = 0;
    } else {
      // 2. 不能整除：需要“补”到一个能整除的数
      // 比如 木三局(3) 生日初五(5) -> 补 1 变成 6
      int toAdd = bureau - (day % bureau);
      quotient = (day + toAdd) ~/ bureau;
      remainder = (toAdd % 2 == 1) ? -toAdd : toAdd; // 奇减偶加
    }

    // 公式：商 + 余 + 寅宫基准(1)
    //商数1对应寅宫(index 2)
    // (quotient + remainder - 1 + 2) % 12
    int index = (quotient + remainder + 1) % 12;

    // 防止负数
    if (index < 0) index += 12;

    return index;
  }
}
