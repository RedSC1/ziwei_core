/// 历史红区熔断状态对象
class ManifestStatus {
  final bool isHistoricalRedZone;
  final String note;

  ManifestStatus({required this.isHistoricalRedZone, required this.note});

  Map<String, dynamic> toJson() => {
    'is_historical_red_zone': isHistoricalRedZone,
    'note': note,
  };
}

/// 流月节点
class MonthNode {
  final int month;
  final String stem;
  final String branch;
  final String? solarStart;
  final String? solarEnd;

  MonthNode({
    required this.month,
    required this.stem,
    required this.branch,
    this.solarStart,
    this.solarEnd,
  });

  Map<String, dynamic> toJson() => {
    'month': month,
    'stem': stem,
    'branch': branch,
    if (solarStart != null) 'solar_start': solarStart,
    if (solarEnd != null) 'solar_end': solarEnd,
  };
}

/// 大限节点
class DecadeNode {
  final int index;
  final int startAge;
  final int endAge;
  final int startYear;
  final int endYear;
  final String stem;
  final String branch;

  DecadeNode({
    required this.index,
    required this.startAge,
    required this.endAge,
    required this.startYear,
    required this.endYear,
    required this.stem,
    required this.branch,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'start_age': startAge,
    'end_age': endAge,
    'start_year': startYear,
    'end_year': endYear,
    'stem': stem,
    'branch': branch,
  };
}

/// 童限节点（起大限前）
class ChildhoodNode {
  final int age;
  final int year;
  final String stem;
  final String branch;

  ChildhoodNode({
    required this.age,
    required this.year,
    required this.stem,
    required this.branch,
  });

  Map<String, dynamic> toJson() => {
    'age': age,
    'year': year,
    'stem': stem,
    'branch': branch,
  };
}

/// 流运时间轴年度通行证
class TimelineManifest {
  final List<ChildhoodNode> childhoods;
  final List<DecadeNode> decades;
  final List<MonthNode> currentYearMonths;
  final ManifestStatus status;

  TimelineManifest({
    required this.childhoods,
    required this.decades,
    required this.currentYearMonths,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'childhoods': childhoods.map((e) => e.toJson()).toList(),
    'decades': decades.map((e) => e.toJson()).toList(),
    'current_year_months': currentYearMonths.map((e) => e.toJson()).toList(),
    'status': status.toJson(),
  };
}

/// 流年节点
class YearNode {
  final int year;
  final String stem;
  final String branch;

  YearNode({required this.year, required this.stem, required this.branch});

  Map<String, dynamic> toJson() => {
    'year': year,
    'stem': stem,
    'branch': branch,
  };
}

/// 流日节点
class DayNode {
  final int day;
  final String stem;
  final String branch;
  final String solarDate;

  DayNode({
    required this.day,
    required this.stem,
    required this.branch,
    required this.solarDate,
  });

  Map<String, dynamic> toJson() => {
    'day': day,
    'stem': stem,
    'branch': branch,
    'solar_date': solarDate,
  };
}

/// 流时节点
class HourNode {
  final int hourIndex;
  final String label;
  final String stem;
  final String branch;
  final bool isEarlyRat;
  final bool isLateRat;

  HourNode({
    required this.hourIndex,
    required this.label,
    required this.stem,
    required this.branch,
    this.isEarlyRat = false,
    this.isLateRat = false,
  });

  Map<String, dynamic> toJson() => {
    'hour_index': hourIndex,
    'label': label,
    'stem': stem,
    'branch': branch,
    if (isEarlyRat) 'is_early_rat': true,
    if (isLateRat) 'is_late_rat': true,
  };
}
