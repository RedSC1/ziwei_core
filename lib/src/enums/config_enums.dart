//天干
enum TianGan {
  jia,  // 甲 (0)
  yi,   // 乙 (1)
  bing, // 丙 (2)
  ding, // 丁 (3)
  wu,   // 戊 (4)
  ji,   // 己 (5)
  geng, // 庚 (6)
  xin,  // 辛 (7)
  ren,  // 壬 (8)
  gui;  // 癸 (9)

  String get name{
    List<String> name = ['甲','乙','丙','丁','戊','己','庚','辛','壬','癸'];
    return name[index];
  }

  static TianGan fromName(String str) {
    return TianGan.values.firstWhere((e) => e.name == str);
  }
}

/// 地支 (12个)
enum DiZhi{
  zi,   // 子 (0)
  chou, // 丑 (1)
  yin,  // 寅 (2)
  mao,  // 卯 (3)
  chen, // 辰 (4)
  si,   // 巳 (5)
  wu,   // 午 (6)
  wei,  // 未 (7)
  shen, // 申 (8)
  you,  // 酉 (9)
  xu,   // 戌 (10)
  hai;  // 亥 (11)
  String get name{
    List<String> name = ['子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'];
    return name[index];
  }
  
  static DiZhi fromName(String str) {
    return DiZhi.values.firstWhere((e) => e.name == str);
  }
}

enum LeapMonthRule {
  asPrevious, // 算作本月 (闰四月 = 四月)
  asNext,     // 算作下月 (闰四月 = 五月)
  splitAt15,   // 按15日切分 (变态版)
}
