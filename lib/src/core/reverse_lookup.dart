import 'package:bazi_core/bazi_core.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

import '../enums/basic.dart';
import '../enums/consts.dart';
import '../core/engine.dart';
import '../data/plate.dart';
import '../config/ruleset.dart';
import '../time/ziwei_date.dart';

// ═══════════════════════════════════════════════════════════════
// 查询 & 结果
// ═══════════════════════════════════════════════════════════════

/// Tier 1 反查查询：通过指定星曜宫位，直接反推出生时间参数。
///
/// 每个字段对应一颗"钥匙星"，提供即可瞬间脱壳对应的出生参数。
/// 至少需要覆盖：年干、年支、月、日、时 五个维度才能唯一定位。
class ZiweiTier1Query {
  // ─── 年干 (from 禄存 / 化禄) ───
  /// 禄存所在宫位索引 (0-11)
  final int? lucunIndex;

  // ─── 年支 (from 红鸾) ───
  /// 红鸾所在宫位索引 (0-11)
  final int? hongluanIndex;

  // ─── 月份 (from 左辅 / 右弼) ───
  /// 左辅所在宫位索引 (0-11)
  final int? zuofuIndex;
  /// 右弼所在宫位索引 (0-11)
  final int? youbiIndex;

  // ─── 时辰 (from 文昌 / 文曲) ───
  /// 文昌所在宫位索引 (0-11)
  final int? wenchangIndex;
  /// 文曲所在宫位索引 (0-11)
  final int? wenquIndex;

  // ─── 农历日 (from 三台 / 八座) ───
  /// 三台所在宫位索引 (0-11)
  final int? santaiIndex;
  /// 八座所在宫位索引 (0-11)
  final int? bazuoIndex;

  // ─── 搜索范围 ───
  /// 搜索起始公历日期
  final AstroDateTime startDate;
  /// 搜索结束公历日期
  final AstroDateTime endDate;

  // ─── 配置 ───
  final ZiweiRuleset ruleset;
  final Gender gender;
  final TDRpan tdrPan;
  final Location location;
  final double timeZone;
  final bool useTrueSolarTime;

  const ZiweiTier1Query({
    this.lucunIndex,
    this.hongluanIndex,
    this.zuofuIndex,
    this.youbiIndex,
    this.wenchangIndex,
    this.wenquIndex,
    this.santaiIndex,
    this.bazuoIndex,
    required this.startDate,
    required this.endDate,
    required this.ruleset,
    this.gender = Gender.male,
    this.tdrPan = TDRpan.tianPan,
    this.location = defaultLoc,
    this.timeZone = 8,
    this.useTrueSolarTime = true,
  });
}

/// 反查候选结果
class ZiweiReverseCandidate {
  /// 候选公历出生时间
  final AstroDateTime solarDate;

  /// 农历年
  final int lunarYear;

  /// 农历月 (1-12)
  final int lunarMonth;

  /// 农历日 (1-30)
  final int lunarDay;

  /// 时辰索引 (0-11，子=0)
  final int hourIndex;

  /// 是否为闰月
  final bool isLeapMonth;

  /// 正向排盘验证后的完整命盘
  final ZiWeiPlate plate;

  const ZiweiReverseCandidate({
    required this.solarDate,
    required this.lunarYear,
    required this.lunarMonth,
    required this.lunarDay,
    required this.hourIndex,
    required this.isLeapMonth,
    required this.plate,
  });
}

// ═══════════════════════════════════════════════════════════════
// 反查引擎
// ═══════════════════════════════════════════════════════════════

class ZiweiReverseLookup {
  /// ─── 禄存反查表 ───
  /// 正向: year_stem → palace;  反向: palace → `[TianGan]`
  static final Map<int, List<TianGan>> _lucunReverse = _buildLucunReverse();

  static Map<int, List<TianGan>> _buildLucunReverse() {
    const forward = <TianGan, int>{
      TianGan.jia: 2,
      TianGan.yi: 3,
      TianGan.bing: 5,
      TianGan.ding: 6,
      TianGan.wu: 5,
      TianGan.ji: 6,
      TianGan.geng: 8,
      TianGan.xin: 9,
      TianGan.ren: 11,
      TianGan.gui: 0,
    };
    final reverse = <int, List<TianGan>>{};
    for (final e in forward.entries) {
      reverse.putIfAbsent(e.value, () => []).add(e.key);
    }
    return reverse;
  }

  /// ─── 红鸾反查表 ───
  /// 正向: year_branch → palace;  反向: palace → year_branch (一对一)
  static final Map<int, DiZhi> _hongluanReverse = _buildHongluanReverse();

  static Map<int, DiZhi> _buildHongluanReverse() {
    // 红鸾口诀: 子年卯, 丑年寅, 寅年丑, 卯年子, 辰年亥, 巳年戌,
    //           午年酉, 未年申, 申年未, 酉年午, 戌年巳, 亥年辰
    const forward = <DiZhi, int>{
      DiZhi.zi: 3, DiZhi.chou: 2, DiZhi.yin: 1, DiZhi.mao: 0,
      DiZhi.chen: 11, DiZhi.si: 10, DiZhi.wu: 9, DiZhi.wei: 8,
      DiZhi.shen: 7, DiZhi.you: 6, DiZhi.xu: 5, DiZhi.hai: 4,
    };
    return {for (final e in forward.entries) e.value: e.key};
  }

  // ─────────────────────────────────────────────────────────────
  // Tier 1 主入口
  // ─────────────────────────────────────────────────────────────

  /// Tier 1 反查：用星曜宫位直接反推出生时间。
  ///
  /// 至少需要提供能覆盖 年干、年支、月、日、时 五个维度的星曜。
  static List<ZiweiReverseCandidate> searchTier1(ZiweiTier1Query query) {
    // Step 1: 反推各维度候选
    final yearStemCandidates = _deriveYearStem(query);
    final yearBranchCandidates = _deriveYearBranch(query);
    final monthCandidates = _deriveMonth(query);
    final hourCandidates = _deriveHour(query);

    if (yearStemCandidates == null) {
      throw ArgumentError('无法确定年干：请提供 lucunIndex');
    }
    if (yearBranchCandidates == null) {
      throw ArgumentError('无法确定年支：请提供 hongluanIndex');
    }
    if (monthCandidates == null) {
      throw ArgumentError('无法确定月份：请提供 zuofuIndex 或 youbiIndex');
    }
    if (hourCandidates == null) {
      throw ArgumentError('无法确定时辰：请提供 wenchangIndex 或 wenquIndex');
    }

    // Step 2: 枚举年份
    final candidateYears = _enumerateYears(
      yearStemCandidates,
      yearBranchCandidates,
      query.startDate,
      query.endDate,
    );

    // Step 3: 逐年在阅
    final ssq = SSQ();
    final results = <ZiweiReverseCandidate>[];
    final seen = <String>{};

    for (final year in candidateYears) {
      // 一个农历年的月份可能跨越两个 ssq 年度:
      // - calcY(year, July) → 覆盖上年冬至~当年冬至 (约11月前)
      // - calcY(year+1, Jan) → 覆盖当年冬至~下年冬至 (含腊月)
      final ssqResults = <SSQResult>[
        ssq.calcY(
          AstroDateTime(year, 7, 1).toJ2000(),
          enableHistoricalRules: query.ruleset.calendarOptions.enableHistorical,
        ),
        ssq.calcY(
          AstroDateTime(year + 1, 1, 15).toJ2000(),
          enableHistoricalRules: query.ruleset.calendarOptions.enableHistorical,
        ),
      ];

      for (final effectiveMonth in monthCandidates) {
        // 反推农历日候选
        final dayCandidates = _deriveDayCandidates(
          query,
          effectiveMonth - 1, // 转为 0-based
        );

        if (dayCandidates == null || dayCandidates.isEmpty) continue;

        for (final ssqResult in ssqResults) {
          // 枚举该月所有物理形态 (常规月 + 闰月邻居)
          final monthForms = _enumerateMonthForms(ssqResult, effectiveMonth);

          for (final form in monthForms) {
            final physicalMonthIndex = form.index;
            final isLeap = form.isLeap;

            if (physicalMonthIndex < 0 || physicalMonthIndex >= ssqResult.dx.length) continue;
            final maxDay = ssqResult.dx[physicalMonthIndex];

            for (final day in dayCandidates) {
              if (day < 1 || day > maxDay) continue;

              for (final hour in hourCandidates) {
                // 构建候选并正向验证
                final candidate = _buildAndVerify(
                  year: year,
                  month: form.lunarMonth,
                  day: day,
                  hour: hour,
                  isLeap: isLeap,
                  query: query,
                );
                if (candidate != null) {
                  final key = '${candidate.solarDate.toJ2000()}-${candidate.hourIndex}-${candidate.isLeapMonth}';
                  if (seen.add(key)) results.add(candidate);
                }
              }
            }
          }
        }
      }
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // 反推各维度
  // ─────────────────────────────────────────────────────────────

  /// 禄存 → 年干候选
  static List<TianGan>? _deriveYearStem(ZiweiTier1Query query) {
    if (query.lucunIndex == null) return null;
    return _lucunReverse[query.lucunIndex!];
  }

  /// 红鸾 → 年支候选 (一对一)
  static List<DiZhi>? _deriveYearBranch(ZiweiTier1Query query) {
    if (query.hongluanIndex == null) return null;
    final branch = _hongluanReverse[query.hongluanIndex!];
    if (branch == null) return null;
    return [branch];
  }

  /// 左辅/右弼 → 月份候选 (1-based)
  ///
  /// 左辅: zuofu = fixIndex(4 + month) → month = zuofu - 4
  /// 右弼: youbi  = fixIndex(10 - month) → month = 10 - youbi
  static List<int>? _deriveMonth(ZiweiTier1Query query) {
    final months = <int>{};

    if (query.zuofuIndex != null) {
      months.add(ZiweiConsts.fixIndex(query.zuofuIndex! - 4) + 1);
    }
    if (query.youbiIndex != null) {
      months.add(ZiweiConsts.fixIndex(10 - query.youbiIndex!) + 1);
    }

    if (months.isEmpty) return null;
    return months.toList();
  }

  /// 文昌/文曲 → 时辰候选
  ///
  /// 文昌: wenchang = fixIndex(10 - hour) → hour = fixIndex(10 - wenchang)
  /// 文曲: wenqu    = fixIndex(4 + hour)  → hour = fixIndex(wenqu - 4)
  static List<int>? _deriveHour(ZiweiTier1Query query) {
    final hours = <int>{};

    if (query.wenchangIndex != null) {
      hours.add(ZiweiConsts.fixIndex(10 - query.wenchangIndex!));
    }
    if (query.wenquIndex != null) {
      hours.add(ZiweiConsts.fixIndex(query.wenquIndex! - 4));
    }

    if (hours.isEmpty) return null;
    return hours.toList();
  }

  /// 三台/八座 → 农历日候选 (1-based)
  ///
  /// 三台 = fixIndex(4 + month - day%12)  → day%12 = fixIndex(4 + month - santai)
  /// 八座 = fixIndex(10 - month - day%12)  → day%12 = fixIndex(10 - month - bazuo)
  static List<int>? _deriveDayCandidates(ZiweiTier1Query query, int month0) {
    final dayMods = <int>{};

    if (query.santaiIndex != null) {
      dayMods.add(ZiweiConsts.fixIndex(4 + month0 - query.santaiIndex!));
    }
    if (query.bazuoIndex != null) {
      dayMods.add(ZiweiConsts.fixIndex(10 - month0 - query.bazuoIndex!));
    }

    if (dayMods.isEmpty) return null;

    // 取交集：如果两个星都给了，day%12 必须一致
    if (query.santaiIndex != null && query.bazuoIndex != null && dayMods.length > 1) {
      return const []; // 矛盾，无解
    }

    final mod = dayMods.first;

    // day 范围 0-29 (0-based)，展开为 1-based
    final candidates = <int>[];
    for (var d = mod; d < 30; d += 12) {
      candidates.add(d + 1); // 转 1-based
    }
    return candidates;
  }

  // ─────────────────────────────────────────────────────────────
  // 年份枚举
  // ─────────────────────────────────────────────────────────────

  /// 在时间范围内枚举匹配指定年干+年支的年份
  static List<int> _enumerateYears(
    List<TianGan> stemCandidates,
    List<DiZhi> branchCandidates,
    AstroDateTime start,
    AstroDateTime end,
  ) {
    final results = <int>[];
    // ±1: 公历1-2月的农历年可能还在上一年
    for (var y = start.year - 1; y <= end.year + 1; y++) {
      final stemIdx = (y - 4) % 10;
      final branchIdx = (y - 4) % 12;
      if (stemIdx < 0 || branchIdx < 0) continue;

      final stem = TianGan.values[stemIdx % 10];
      final branch = DiZhi.values[branchIdx % 12];

      if (stemCandidates.contains(stem) && branchCandidates.contains(branch)) {
        results.add(y);
      }
    }
    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // 闰月邻居枚举
  // ─────────────────────────────────────────────────────────────

  /// 枚举 effectiveMonth 对应的所有物理月形态 (常规 + 闰月邻居)
  ///
  /// ssq 的月份排列规律 (无闰月):
  ///   index:  0    1    2   3   4   ... 11   12   13
  ///   month: 十一 十二  正  二  三  ... 十  十一  十二
  ///
  /// 有闰月时 leap=L: L 是闰月，L 之后月序 -1
  /// 例如 leap=5 表示 index=5 是闰四月，之后 index=6→五, index=7→六...
  static List<_MonthForm> _enumerateMonthForms(SSQResult ssqResult, int effectiveMonth) {
    final forms = <_MonthForm>[];
    final L = ssqResult.leap;

    // 1. 常规月本身
    final regularIdx = _monthToIndex(effectiveMonth, L);
    if (regularIdx >= 0 && regularIdx < ssqResult.dx.length) {
      forms.add(_MonthForm(
        index: regularIdx,
        lunarMonth: effectiveMonth,
        isLeap: false,
      ));
    }

    // 2. 如果有闰月，检查邻居
    if (L > 0) {
      // 闰月前面那个常规月是几月？
      // L 位置的闰月 = 闰(L-1月之后) = 闰(leapMonthNum月)
      // 无闰时 L 位置的月号 = _indexToMonth(L)
      final leapMonthNum = _indexToMonth(L, 0); // 假设没闰月时 L 位置的月号
      // 有闰月时，L 就是闰月，月号 = leapMonthNum
      // 所以 ssqResult.leap = L 表示闰的是 leapMonthNum 月

      // 闰(leapMonthNum) 在 asNext 下 effective = leapMonthNum+1
      if (leapMonthNum + 1 == effectiveMonth) {
        if (L < ssqResult.dx.length) {
          forms.add(_MonthForm(
            index: L,
            lunarMonth: leapMonthNum,
            isLeap: true,
          ));
        }
      }

      // 闰(effectiveMonth) 本身
      if (leapMonthNum == effectiveMonth) {
        if (L < ssqResult.dx.length) {
          forms.add(_MonthForm(
            index: L,
            lunarMonth: effectiveMonth,
            isLeap: true,
          ));
        }
      }
    }

    return forms;
  }

  /// 月号 (1-based) → ssq dx[] 索引
  ///
  /// ssq 索引排列: 0→十一, 1→十二, 2→正, 3→二, ..., 11→十, 12→十一, 13→十二
  /// 有闰月时 leap=L: L 位置是闰月，L 之后索引偏移 +1
  static int _monthToIndex(int month, int leap) {
    // 先算无闰时的索引
    int idx;
    if (month == 11) {
      idx = 0;
    } else if (month == 12) {
      idx = 1;
    } else {
      idx = month + 1; // 正=2, 二=3, ..., 十=11
    }

    // 如果闰月在此位置之前，索引要 +1（因为闰月占了一个位置）
    if (leap > 0 && idx >= leap) {
      idx++;
    }

    return idx;
  }

  /// ssq dx[] 索引 → 月号 (1-based, 无闰月假设)
  static int _indexToMonth(int index, int leap) {
    // 先还原无闰时的逻辑索引
    int logicIdx = index;
    if (leap > 0 && index > leap) {
      logicIdx = index - 1;
    }

    if (logicIdx == 0) return 11;
    if (logicIdx == 1) return 12;
    return logicIdx - 1; // 2→1(正), 3→2(二), ..., 11→10(十), 12→11(十一), 13→12(十二)
  }

  // ─────────────────────────────────────────────────────────────
  // 构建候选 & 正向验证
  // ─────────────────────────────────────────────────────────────

  static ZiweiReverseCandidate? _buildAndVerify({
    required int year,
    required int month,
    required int day,
    required int hour,
    required bool isLeap,
    required ZiweiTier1Query query,
  }) {
    // 农历时辰 → 公历整点小时 (子=0→0时, 丑=1→1时, ..., 亥=11→21时)
    final solarHour = hour * 2;

    try {
      final date = ZiweiDate.fromLunar(
        year,
        month,
        day,
        solarHour,
        0,
        0,
        isLeap,
        gender: query.gender,
        options: query.ruleset.calendarOptions,
        location: query.location,
        timeZone: query.timeZone,
        useTrueSolarTime: query.useTrueSolarTime,
      );

      final plate = ZiweiEngine.calculate(date, query.ruleset, tdrPan: query.tdrPan);

      // 过滤：公历日期必须在搜索范围内
      final solarJd = date.solar.toJ2000();
      final startJd = query.startDate.toJ2000();
      final endJd = query.endDate.toJ2000();
      if (solarJd < startJd || solarJd > endJd) return null;

      return ZiweiReverseCandidate(
        solarDate: date.solar,
        lunarYear: year,
        lunarMonth: month,
        lunarDay: day,
        hourIndex: hour,
        isLeapMonth: isLeap,
        plate: plate,
      );
    } catch (_) {
      return null;
    }
  }
}

class _MonthForm {
  final int index;      // 在 ssq.dx[] 中的索引
  final int lunarMonth; // 农历月号 (1-12)
  final bool isLeap;

  const _MonthForm({
    required this.index,
    required this.lunarMonth,
    required this.isLeap,
  });
}
