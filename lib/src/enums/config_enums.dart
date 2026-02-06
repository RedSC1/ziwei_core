//天干
enum TianGan {
  jia, // 甲 (0)
  yi, // 乙 (1)
  bing, // 丙 (2)
  ding, // 丁 (3)
  wu, // 戊 (4)
  ji, // 己 (5)
  geng, // 庚 (6)
  xin, // 辛 (7)
  ren, // 壬 (8)
  gui; // 癸 (9)

  String get label {
    List<String> labels = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
    return labels[index];
  }

  static TianGan fromName(String str) {
    return TianGan.values.firstWhere((e) => e.label == str);
  }
}

/// 地支 (12个)
enum DiZhi {
  zi, // 子 (0)
  chou, // 丑 (1)
  yin, // 寅 (2)
  mao, // 卯 (3)
  chen, // 辰 (4)
  si, // 巳 (5)
  wu, // 午 (6)
  wei, // 未 (7)
  shen, // 申 (8)
  you, // 酉 (9)
  xu, // 戌 (10)
  hai; // 亥 (11)

  String get label {
    List<String> labels = [
      '子',
      '丑',
      '寅',
      '卯',
      '辰',
      '巳',
      '午',
      '未',
      '申',
      '酉',
      '戌',
      '亥',
    ];
    return labels[index];
  }

  static DiZhi fromName(String str) {
    return DiZhi.values.firstWhere((e) => e.label == str);
  }
}

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

  /// 节气为界 [八字/钦天]
  solar,
}
