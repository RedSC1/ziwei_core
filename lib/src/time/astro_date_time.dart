/// 支持公元前的天文日期时间类。
///
/// [year] 采用天文纪年（Astronomical Year Numbering）：
///   1 = 公元1年, 0 = 公元前1年, -1 = 公元前2年, ...
///
/// 构造函数签名与 Dart [DateTime] 保持一致，方便迁移：
///   `AstroDateTime(year, [month, day, hour, minute, second])`
///
/// 内部通过儒略日（Julian Day）进行日期运算，
/// 所有天文/历法计算均基于 J2000.0 相对儒略日。
class AstroDateTime implements Comparable<AstroDateTime> {
  /// 天文纪年年份（有0年：0 = 公元前1年）
  final int year;

  /// 月 (1-12)
  final int month;

  /// 日 (1-31)
  final int day;

  /// 时 (0-23)
  final int hour;

  /// 分 (0-59)
  final int minute;

  /// 秒 (0-59)
  final int second;

  /// 构造函数，参数顺序与 [DateTime] 一致。
  const AstroDateTime(
    this.year, [
    this.month = 1,
    this.day = 1,
    this.hour = 0,
    this.minute = 0,
    this.second = 0,
  ]);

  // --------------- 与 DateTime 兼容的属性 ---------------

  /// 是否公元前
  bool get isBCE => year <= 0;

  /// 公元前的传统纪年（公元前1年 → 1, 公元前2年 → 2）。
  /// 公元后返回 null。
  int? get bceYear => isBCE ? 1 - year : null;

  /// 星期几 (1 = Monday, 7 = Sunday)，与 [DateTime.weekday] 一致。
  int get weekday {
    // 从儒略日计算星期
    final jd = toJulianDay();
    // JD 0 是星期一，JD 的小数部分从正午开始
    // 标准公式：(floor(JD + 1.5)) mod 7 → 0=Mon, 1=Tue, ..., 6=Sun
    final w = ((jd + 1.5).floor()) % 7;
    // 转为 1=Mon ~ 7=Sun
    return w == 0 ? 7 : w;
  }

  // --------------- 核心：儒略日转换 ---------------

  /// 绝对儒略日常量 J2000.0 = 2451545.0 (2000-01-01 12:00 TT)
  static const double j2000 = 2451545.0;

  /// 转为绝对儒略日（Absolute Julian Day Number）。
  ///
  /// 使用标准 Meeus 算法，正确处理 Julian/Gregorian 历法切换
  /// （1582-10-15 及之后使用格里历，之前使用儒略历）。
  double toJulianDay() {
    return _gregorianToJD(year, month, day, hour, minute, second);
  }

  /// 转为 J2000.0 相对儒略日（sxwnl 内部使用的时间表示）。
  ///
  /// `j2000Relative = absoluteJD - 2451545.0`
  double toJ2000() {
    return toJulianDay() - j2000;
  }

  /// 从绝对儒略日构造。
  factory AstroDateTime.fromJulianDay(double jd) {
    return _jdToGregorian(jd);
  }

  /// 从 J2000.0 相对儒略日构造。
  factory AstroDateTime.fromJ2000(double j2k) {
    return _jdToGregorian(j2k + j2000);
  }

  // --------------- 与 Dart DateTime 互转 ---------------

  /// 从 Dart [DateTime] 构造（现代日期的便捷入口）。
  factory AstroDateTime.fromDateTime(DateTime dt) {
    return AstroDateTime(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    );
  }

  /// 转为 Dart [DateTime]。
  ///
  /// 如果日期在公元前（[isBCE] == true），返回 null，
  /// 因为 Dart 的 [DateTime] 不支持公元前。
  DateTime? toDateTime() {
    if (isBCE) return null;
    return DateTime(year, month, day, hour, minute, second);
  }

  // --------------- 运算 ---------------

  /// 加上一段时间，返回新的 [AstroDateTime]。
  ///
  /// 与 [DateTime.add] 行为一致。
  /// 内部通过儒略日运算，天然支持跨公元前后。
  AstroDateTime add(Duration duration) {
    final jd = toJulianDay() + duration.inSeconds / 86400.0;
    return AstroDateTime.fromJulianDay(jd);
  }

  /// 减去一段时间，返回新的 [AstroDateTime]。
  AstroDateTime subtract(Duration duration) {
    return add(Duration(seconds: -duration.inSeconds));
  }

  /// 两个日期之间的时间差。
  Duration difference(AstroDateTime other) {
    final diffDays = toJulianDay() - other.toJulianDay();
    return Duration(seconds: (diffDays * 86400).round());
  }

  /// 是否在 [other] 之后。
  bool isAfter(AstroDateTime other) => toJulianDay() > other.toJulianDay();

  /// 是否在 [other] 之前。
  bool isBefore(AstroDateTime other) => toJulianDay() < other.toJulianDay();

  // --------------- Comparable / Object ---------------

  @override
  int compareTo(AstroDateTime other) {
    return toJulianDay().compareTo(other.toJulianDay());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AstroDateTime &&
        other.year == year &&
        other.month == month &&
        other.day == day &&
        other.hour == hour &&
        other.minute == minute &&
        other.second == second;
  }

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute, second);

  @override
  String toString() {
    final y = isBCE ? '公元前${1 - year}' : '$year';
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    final h = hour.toString().padLeft(2, '0');
    final mi = minute.toString().padLeft(2, '0');
    final s = second.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$mi:$s';
  }

  // --------------- 内部：JD 转换算法 (Meeus) ---------------

  /// 公历 → 绝对儒略日。
  ///
  /// 基于 Jean Meeus《Astronomical Algorithms》标准算法。
  /// 正确处理 Julian/Gregorian 历法切换（1582-10-15）。
  static double _gregorianToJD(int y, int m, int d, int h, int mi, int s) {
    final dayFraction = d + h / 24.0 + mi / 1440.0 + s / 86400.0;

    int year = y;
    int month = m;
    if (month <= 2) {
      year -= 1;
      month += 12;
    }

    // 判断是否在格里历生效之后（1582-10-15）
    // 使用线性比较避免多重条件
    final double isGregorian = (y * 10000.0 + m * 100.0 + d) >= 15821015.0
        ? 1.0
        : 0.0;

    final a = (year / 100).floor();
    // 格里历修正项：格里历时 B = 2 - A + floor(A/4)，儒略历时 B = 0
    final b = isGregorian * (2 - a + (a / 4).floor());

    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        dayFraction +
        b -
        1524.5;
  }

  /// 绝对儒略日 → 公历。
  ///
  /// 基于 Meeus 逆算法。
  static AstroDateTime _jdToGregorian(double jd) {
    jd += 0.5;
    final z = jd.floor();
    final f = jd - z;

    int a;
    if (z < 2299161) {
      // 儒略历
      a = z;
    } else {
      // 格里历
      final alpha = ((z - 1867216.25) / 36524.25).floor();
      a = z + 1 + alpha - (alpha / 4).floor();
    }

    final b = a + 1524;
    final c = ((b - 122.1) / 365.25).floor();
    final d = (365.25 * c).floor();
    final e = ((b - d) / 30.6001).floor();

    final dayFraction = b - d - (30.6001 * e).floor() + f;
    final day = dayFraction.floor();
    final timeFraction = dayFraction - day;

    final month = e < 14 ? e - 1 : e - 13;
    final year = month > 2 ? c - 4716 : c - 4715;

    // 从日的小数部分提取时分秒
    final totalSeconds = (timeFraction * 86400).round();
    final hour = totalSeconds ~/ 3600;
    final minute = (totalSeconds % 3600) ~/ 60;
    final second = totalSeconds % 60;

    return AstroDateTime(year, month, day, hour, minute, second);
  }
}
