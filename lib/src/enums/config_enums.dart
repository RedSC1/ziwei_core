enum LeapMonthRule {
  asPrevious, // 算作本月 (闰四月 = 四月)
  asNext, // 算作下月 (闰四月 = 五月)
  splitAt15, // 按15日切分 (变态版)
}

enum PalaceName {
  life, // 命宫
  siblings, // 兄弟
  spouse, // 夫妻
  children, // 子女
  wealth, // 财帛
  health, // 疾厄
  travel, // 迁移
  friends, // 交友 (奴仆)
  career, // 官禄 (事业)
  property, // 田宅
  mental, // 福德 (Karma / Mental)
  parents; // 父母

  // 顺手写个中文翻译，方便之后打印
  String get label {
    switch (this) {
      case life:
        return '命宫';
      case siblings:
        return '兄弟';
      case spouse:
        return '夫妻';
      case children:
        return '子女';
      case wealth:
        return '财帛';
      case health:
        return '疾厄';
      case travel:
        return '迁移';
      case friends:
        return '交友';
      case career:
        return '官禄';
      case property:
        return '田宅';
      case mental:
        return '福德';
      case parents:
        return '父母';
    }
  }
}
enum Boundary {
  /// 以农历为界 [主流紫微]
  lunar,

  /// 节气为界 [八字]
  solar,
}
