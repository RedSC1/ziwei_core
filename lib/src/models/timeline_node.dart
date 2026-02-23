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
  final String solarStart;
  final String solarEnd;

  DecadeNode({
    required this.index,
    required this.startAge,
    required this.endAge,
    required this.startYear,
    required this.endYear,
    required this.stem,
    required this.branch,
    required this.solarStart,
    required this.solarEnd,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'start_age': startAge,
    'end_age': endAge,
    'start_year': startYear,
    'end_year': endYear,
    'stem': stem,
    'branch': branch,
    'solar_start': solarStart,
    'solar_end': solarEnd,
  };
}

/// 流运时间轴年度通行证
class TimelineManifest {
  final List<DecadeNode> decades;
  final List<MonthNode> currentYearMonths;
  final ManifestStatus status;

  TimelineManifest({
    required this.decades,
    required this.currentYearMonths,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'decades': decades.map((e) => e.toJson()).toList(),
    'current_year_months': currentYearMonths.map((e) => e.toJson()).toList(),
    'status': status.toJson(),
  };
}
