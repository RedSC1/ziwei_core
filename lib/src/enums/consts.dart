/// 紫微斗数核心常量表
class ZiweiConsts {
  // --- 宫位索引 ---

  /// 寅宫索引 (常驻位置)
  /// 紫微斗数排盘通常以寅宫为地支序列的开始或重要参考点
  static const int yinIndex = 2;

  /// 宫位总数
  static const int palaceCount = 12;

  // --- 时间计算 ---

  /// 早子时开始时间 (23:00)
  static const int earlyRatHourStart = 23;

  /// 晚子时结束时间 (01:00)
  static const int lateRatHourEnd = 1;

  /// 安全取模：将索引归入 [0, 12) 范围，处理负数情况
  static int fixIndex(int index) {
    int result = index % palaceCount;
    if (result < 0) result += palaceCount;
    return result;
  }
}
