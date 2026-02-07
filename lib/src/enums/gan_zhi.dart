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
enum FiveElementBureau {
  water2, // index 0
  wood3, // index 1
  metal4, // index 2
  earth5, // index 3
  fire6; // index 4

  int get number => const [2, 3, 4, 5, 6][index];
  String get label => const ['水二局', '木三局', '金四局', '土五局', '火六局'][index];
}
