/// 实朔实气计算器 (SSQ)。
///
/// 移植自寿星万年历 (sxwnl) lunar.js 的 SSQ 对象。
/// 负责计算节气时刻、合朔时刻、农历月序、闰月判断。
///
/// 包含：
/// - 历史历法拟合参数 (suoKB, qiKB)
/// - 修正表解压 (jieya)
/// - 节气/合朔计算 (calc)
/// - 农历排谱 (calcY)
library;

import 'dart:math' as math;

import 'delta_t.dart';
import 'math_utils.dart';
import 'solar_lunar_pos.dart';

/// 朔直线拟合参数表。
///
/// 结构：[起始儒略日, 朔望月周期]
/// 用于历史时期的平朔计算。
const List<double> _suoKB = [
  1457698.231017, 29.53067166, // -721-12-17 h=0.00032 古历·春秋
  1546082.512234, 29.53085106, // -479-12-11 h=0.00053 古历·战国
  1640640.735300, 29.53060000, // -221-10-31 h=0.01010 古历·秦汉
  1642472.151543, 29.53085439, // -216-11-04 h=0.00040 古历·秦汉

  1683430.509300, 29.53086148, // -104-12-25 h=0.00313 汉书·律历志(太初历)平气平朔
  1752148.041079, 29.53085097, //   85-02-13 h=0.00049 后汉书·律历志(四分历)
  // 1807665.420323, 29.53059851, //  237-02-12 h=0.00033 晋书·律历志(景初历)
  1807724.481520, 29.53059851, //  237-04-12 h=0.00033 晋书·律历志(景初历)
  1883618.114100, 29.53060000, //  445-01-24 h=0.00030 宋书·律历志(何承天元嘉历)
  1907360.704700, 29.53060000, //  510-01-26 h=0.00030 宋书·律历志(祖冲之大明历)
  1936596.224900, 29.53060000, //  590-02-10 h=0.01010 随书·律历志(开皇历)
  1939135.675300, 29.53060000, //  597-01-24 h=0.00890 随书·律历志(大业历)
  1947168.00, //  619-01-21
];

/// 气直线拟合参数表。
///
/// 结构：[起始儒略日, 回归年周期/24]
/// 用于历史时期的平气计算。
const List<double> _qiKB = [
  1640650.479938, 15.21842500, // -221-11-09 h=0.01709 古历·秦汉
  1642476.703182, 15.21874996, // -216-11-09 h=0.01557 古历·秦汉

  1683430.515601, 15.218750011, // -104-12-25 h=0.01560 汉书·律历志(太初历)平气平朔
  1752157.640664, 15.218749978, //   85-02-23 h=0.01559 后汉书·律历志(四分历)
  1807675.003759, 15.218620279, //  237-02-22 h=0.00010 晋书·律历志(景初历)
  1883627.765182, 15.218612292, //  445-02-03 h=0.00026 宋书·律历志(何承天元嘉历)
  1907369.128100, 15.218449176, //  510-02-03 h=0.00027 宋书·律历志(祖冲之大明历)
  1936603.140413, 15.218425000, //  590-02-17 h=0.00149 随书·律历志(开皇历)
  1939145.524180, 15.218466998, //  597-02-03 h=0.00121 随书·律历志(大业历)
  1947180.798300, 15.218524844, //  619-02-03 h=0.00052 新唐书·历志(戊寅元历)平气定朔
  1964362.041824, 15.218533526, //  666-02-17 h=0.00059 新唐书·历志(麟德历)
  1987372.340971, 15.218513908, //  729-02-16 h=0.00096 新唐书·历志(大衍历,至德历)
  1999653.819126, 15.218530782, //  762-10-03 h=0.00093 新唐书·历志(五纪历)
  2007445.469786, 15.218535181, //  784-02-01 h=0.00059 新唐书·历志(正元历,观象历)
  2021324.917146, 15.218526248, //  822-02-01 h=0.00022 新唐书·历志(宣明历)
  2047257.232342, 15.218519654, //  893-01-31 h=0.00015 新唐书·历志(崇玄历)
  2070282.898213, 15.218425000, //  956-02-16 h=0.00149 旧五代·历志(钦天历)
  2073204.872850, 15.218515221, //  964-02-16 h=0.00166 宋史·律历志(应天历)
  2080144.500926, 15.218530782, //  983-02-16 h=0.00093 宋史·律历志(乾元历)
  2086703.688963, 15.218523776, // 1001-01-31 h=0.00067 宋史·律历志(仪天历,崇天历)
  2110033.182763, 15.218425000, // 1064-12-15 h=0.00669 宋史·律历志(明天历)
  2111190.300888, 15.218425000, // 1068-02-15 h=0.00149 宋史·律历志(崇天历)
  2113731.271005, 15.218515671, // 1075-01-30 h=0.00038 李锐补修(奉元历)
  2120670.840263, 15.218425000, // 1094-01-30 h=0.00149 宋史·律历志
  2123973.309063, 15.218425000, // 1103-02-14 h=0.00669 李锐补修(占天历)
  2125068.997336, 15.218477932, // 1106-02-14 h=0.00056 宋史·律历志(纪元历)
  2136026.312633, 15.218472436, // 1136-02-14 h=0.00088 宋史·律历志(统元历,乾道历,淳熙历)
  2156099.495538, 15.218425000, // 1191-01-29 h=0.00149 宋史·律历志(会元历)
  2159021.324663, 15.218425000, // 1199-01-29 h=0.00149 宋史·律历志(统天历)
  2162308.575254, 15.218461742, // 1208-01-30 h=0.00146 宋史·律历志(开禧历)
  2178485.706538, 15.218425000, // 1252-05-15 h=0.04606 淳祐历
  2178759.662849, 15.218445786, // 1253-02-13 h=0.00231 会天历
  2185334.020800, 15.218425000, // 1271-02-13 h=0.00520 宋史·律历志(成天历)
  2187525.481425, 15.218425000, // 1277-02-12 h=0.00520 本天历
  2188621.191481, 15.218437494, // 1280-02-13 h=0.00015 元史·历志(郭守敬授时历)
  2322147.76, // 1645-09-21
];

// 619-01-21开始16598个朔日修正表 d0=1947168
const String _suoS =
    "EqoFscDcrFpmEsF2DfFideFelFpFfFfFiaipqti1ksttikptikqckstekqttgkqttgkqteksttikptikq2fjstgjqttjkqttgkqt"
    "ekstfkptikq2tijstgjiFkirFsAeACoFsiDaDiADc1AFbBfgdfikijFifegF1FhaikgFag1E2btaieeibggiffdeigFfqDfaiBkF"
    "1kEaikhkigeidhhdiegcFfakF1ggkidbiaedksaFffckekidhhdhdikcikiakicjF1deedFhFccgicdekgiFbiaikcfi1kbFibef"
    "gEgFdcFkFeFkdcfkF1kfkcickEiFkDacFiEfbiaejcFfffkhkdgkaiei1ehigikhdFikfckF1dhhdikcfgjikhfjicjicgiehdik"
    "cikggcifgiejF1jkieFhegikggcikFegiegkfjebhigikggcikdgkaFkijcfkcikfkcifikiggkaeeigefkcdfcfkhkdgkegieid"
    "hijcFfakhfgeidieidiegikhfkfckfcjbdehdikggikgkfkicjicjF1dbidikFiggcifgiejkiegkigcdiegfggcikdbgfgefjF1"
    "kfegikggcikdgFkeeijcfkcikfkekcikdgkabhkFikaffcfkhkdgkegbiaekfkiakicjhfgqdq2fkiakgkfkhfkfcjiekgFebicg"
    "gbedF1jikejbbbiakgbgkacgiejkijjgigfiakggfggcibFifjefjF1kfekdgjcibFeFkijcfkfhkfkeaieigekgbhkfikidfcje"
    "aibgekgdkiffiffkiakF1jhbakgdki1dj1ikfkicjicjieeFkgdkicggkighdF1jfgkgfgbdkicggfggkidFkiekgijkeigfiski"
    "ggfaidheigF1jekijcikickiggkidhhdbgcfkFikikhkigeidieFikggikhkffaffijhidhhakgdkhkijF1kiakF1kfheakgdkif"
    "iggkigicjiejkieedikgdfcggkigieeiejfgkgkigbgikicggkiaideeijkefjeijikhkiggkiaidheigcikaikffikijgkiahi1"
    "hhdikgjfifaakekighie1hiaikggikhkffakicjhiahaikggikhkijF1kfejfeFhidikggiffiggkigicjiekgieeigikggiffig"
    "gkidheigkgfjkeigiegikifiggkidhedeijcfkFikikhkiggkidhh1ehigcikaffkhkiggkidhh1hhigikekfiFkFikcidhh1hit"
    "cikggikhkfkicjicghiediaikggikhkijbjfejfeFhaikggifikiggkigiejkikgkgieeigikggiffiggkigieeigekijcijikgg"
    "ifikiggkideedeijkefkfckikhkiggkidhh1ehijcikaffkhkiggkidhh1hhigikhkikFikfckcidhh1hiaikgjikhfjicjicgie"
    "hdikcikggifikigiejfejkieFhegikggifikiggfghigkfjeijkhigikggifikiggkigieeijcijcikfksikifikiggkidehdeij"
    "cfdckikhkiggkhghh1ehijikifffffkhsFngErD1pAfBoDd1BlEtFqA2AqoEpDqElAEsEeB2BmADlDkqBtC1FnEpDqnEmFsFsAFn"
    "llBbFmDsDiCtDmAB2BmtCgpEplCpAEiBiEoFqFtEqsDcCnFtADnFlEgdkEgmEtEsCtDmADqFtAFrAtEcCqAE1BoFqC1F1DrFtBmF"
    "tAC2ACnFaoCgADcADcCcFfoFtDlAFgmFqBq2bpEoAEmkqnEeCtAE1bAEqgDfFfCrgEcBrACfAAABqAAB1AAClEnFeCtCgAADqDoB"
    "mtAAACbFiAAADsEtBqAB2FsDqpFqEmFsCeDtFlCeDtoEpClEqAAFrAFoCgFmFsFqEnAEcCqFeCtFtEnAEeFtAAEkFnErAABbFkAD"
    "nAAeCtFeAfBoAEpFtAABtFqAApDcCGJ";

// 1645-09-23开始7567个节气修正表
const String _qiS =
    "FrcFs22AFsckF2tsDtFqEtF1posFdFgiFseFtmelpsEfhkF2anmelpFlF1ikrotcnEqEq2FfqmcDsrFor22FgFrcgDscFs22FgEe"
    "FtE2sfFs22sCoEsaF2tsD1FpeE2eFsssEciFsFnmelpFcFhkF2tcnEqEpFgkrotcnEqrEtFermcDsrE222FgBmcmr22DaEfnaF22"
    "2sD1FpeForeF2tssEfiFpEoeFssD1iFstEqFppDgFstcnEqEpFg11FscnEqrAoAF2ClAEsDmDtCtBaDlAFbAEpAAAAAD2FgBiBqo"
    "BbnBaBoAAAAAAAEgDqAdBqAFrBaBoACdAAf1AACgAAAeBbCamDgEifAE2AABa1C1BgFdiAAACoCeE1ADiEifDaAEqAAFe1AcFbcA"
    "AAAAF1iFaAAACpACmFmAAAAAAAACrDaAAADG0";

/// 农历月份名称（0=十一月, 1=十二月, 2=正月...）
///
/// 对应关系：
/// index: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
/// name: 十一, 十二, 正, 二, 三, 四, 五, 六, 七, 八, 九, 十
const List<String> monthNames = [
  "十一",
  "十二",
  "正",
  "二",
  "三",
  "四",
  "五",
  "六",
  "七",
  "八",
  "九",
  "十",
];

/// 朔气引擎结果。
///
/// 包含一年（冬至到冬至）内的所有中气、合朔、月名、闰月信息。
class SSQResult {
  /// 中气表 (儒略日 J2000 相对值, 北京时间)。
  /// 包含 25 个中气，从冬至开始。
  final List<double> zq;

  /// 合朔表 (儒略日 J2000 相对值, 北京时间)。
  /// 包含 15 个合朔时刻（已取整）。
  final List<double> hs;

  /// 各月天数 (29 或 30)。
  final List<int> dx;

  /// 各月名称 (如 "正", "二", "闰四")。
  final List<String> ym;

  /// 闰月位置 (0 = 无闰月)。
  /// 如果 leap = i，表示第 i 个月（0-based）是闰月。
  final int leap;

  SSQResult({
    required this.zq,
    required this.hs,
    required this.dx,
    required this.ym,
    required this.leap,
  });
}

/// 实朔实气计算器。
class SSQ {
  late final String _sb; // 解压后的朔修正表
  late final String _qb; // 解压后的气修正表

  static final SSQ _instance = SSQ._internal();

  factory SSQ() => _instance;

  SSQ._internal() {
    _sb = _jieya(_suoS);
    _qb = _jieya(_qiS);
  }

  /// 解压修正表字符串。
  String _jieya(String s) {
    const o = "0000000000";
    const o2 = o + o;
    s = s.replaceAll('J', '00');
    s = s.replaceAll('I', '000');
    s = s.replaceAll('H', '0000');
    s = s.replaceAll('G', '00000');
    s = s.replaceAll('t', '02');
    s = s.replaceAll('s', '002');
    s = s.replaceAll('r', '0002');
    s = s.replaceAll('q', '00002');
    s = s.replaceAll('p', '000002');
    s = s.replaceAll('o', '0000002');
    s = s.replaceAll('n', '00000002');
    s = s.replaceAll('m', '000000002');
    s = s.replaceAll('l', '0000000002');
    s = s.replaceAll('k', '01');
    s = s.replaceAll('j', '0101');
    s = s.replaceAll('i', '001');
    s = s.replaceAll('h', '001001');
    s = s.replaceAll('g', '0001');
    s = s.replaceAll('f', '00001');
    s = s.replaceAll('e', '000001');
    s = s.replaceAll('d', '0000001');
    s = s.replaceAll('c', '00000001');
    s = s.replaceAll('b', '000000001');
    s = s.replaceAll('a', '0000000001');
    s = s.replaceAll('A', o2 + o2 + o2);
    s = s.replaceAll('B', o2 + o2 + o);
    s = s.replaceAll('C', o2 + o2);
    s = s.replaceAll('D', o2 + o);
    s = s.replaceAll('E', o2);
    s = s.replaceAll('F', o);
    return s;
  }

  // ==================== 高/低精度计算 ====================

  /// 较高精度气 (北京时间)。
  double _qiHigh(double w) {
    var t = sALonT2(w) * 36525;
    t = t - dtT(t) + 8 / 24;
    var v = ((t + 0.5) % 1) * 86400;
    if (v < 1200 || v > 86400 - 1200) {
      t = sALonT(w) * 36525 - dtT(t) + 8 / 24;
    }
    return t;
  }

  /// 较高精度朔 (北京时间)。
  double _soHigh(double w) {
    var t = msALonT2(w) * 36525;
    t = t - dtT(t) + 8 / 24;
    var v = ((t + 0.5) % 1) * 86400;
    if (v < 1800 || v > 86400 - 1800) {
      t = msALonT(w) * 36525 - dtT(t) + 8 / 24;
    }
    return t;
  }

  /// 低精度定朔计算 (2000-600年误差<2小时)。
  double _soLow(double w) {
    const v = 7771.37714500204;
    var t = (w + 1.08472) / v;
    t -=
        (-0.0000331 * t * t +
                0.10976 * math.cos(0.785 + 8328.6914 * t) +
                0.02224 * math.cos(0.187 + 7214.0629 * t) -
                0.03342 * math.cos(4.669 + 628.3076 * t)) /
            v +
        (32 * (t + 1.8) * (t + 1.8) - 20) / 86400 / 36525;
    return t * 36525 + 8 / 24;
  }

  /// 低精度定气计算 (误差<30分)。
  double _qiLow(double w) {
    const v = 628.3319653318;
    var t = (w - 4.895062166) / v;
    t -=
        (53 * t * t +
            334116 * math.cos(4.67 + 628.307585 * t) +
            2061 * math.cos(2.678 + 628.3076 * t) * t) /
        v /
        10000000;

    final l =
        48950621.66 +
        6283319653.318 * t +
        53 * t * t +
        334166 * math.cos(4.669257 + 628.307585 * t) +
        3489 * math.cos(4.6261 + 1256.61517 * t) +
        2060.6 * math.cos(2.67823 + 628.307585 * t) * t -
        994 -
        834 * math.sin(2.1824 - 33.75705 * t);

    t -=
        (l / 10000000 - w) / 628.332 +
        (32 * (t + 1.8) * (t + 1.8) - 20) / 86400 / 36525;
    return t * 36525 + 8 / 24;
  }

  // ==================== 核心计算调度 ====================

  /// 计算节气或合朔的儒略日（J2000相对值，北京时间）。
  ///
  /// [jd] 应靠近所要取得的气朔日。
  /// [type] 0=朔, 1=气。
  double calc(double jd, int type) {
    jd += 2451545; // 转为绝对儒略日
    double dRes;
    String n = "";

    var b = _suoKB;
    var pc = 14.0;
    if (type == 1) {
      b = _qiKB;
      pc = 7.0;
    }

    final f1 = b[0] - pc;
    final f2 = b[b.length - 1] - pc;
    final f3 = 2436935.0; // 1960.1.1

    // 1. 现代/远古天文算法 (表外数据)
    if (jd < f1 || jd >= f3) {
      if (type == 1) {
        // 定气
        // 2451259 = 1999.3.21 春分
        dRes = int2(
          _qiHigh(int2((jd + pc - 2451259) / 365.2422 * 24) * math.pi / 12) +
              0.5,
        ).toDouble();
      } else {
        // 定朔
        // 2451551 = 2000.1.7 朔日
        dRes = int2(
          _soHigh(int2((jd + pc - 2451551) / 29.5306) * math.pi * 2) + 0.5,
        ).toDouble();
      }
      return dRes; // 已经是 J2000 相对值
    }

    // 2. 平气/平朔 (历史表内，早期)
    if (jd >= f1 && jd < f2) {
      int i;
      for (i = 0; i < b.length; i += 2) {
        if (jd + pc < b[i + 2]) break;
      }
      dRes = b[i] + b[i + 1] * int2((jd + pc - b[i]) / b[i + 1]);
      dRes = int2(dRes + 0.5).toDouble();

      // 太初历特殊修正
      if (dRes == 1683460) dRes++;

      return dRes - 2451545; // 转回 J2000 相对值
    }

    // 3. 定气/定朔 (历史表内，晚期) - 使用低精度算法 + 修正表
    if (jd >= f2 && jd < f3) {
      if (type == 1) {
        // 定气
        dRes = int2(
          _qiLow(int2((jd + pc - 2451259) / 365.2422 * 24) * math.pi / 12) +
              0.5,
        ).toDouble();
        // 查修正表
        // f2 = 修正表起点
        final idx = int2((jd - f2) / 365.2422 * 24);
        if (idx >= 0 && idx < _qb.length) n = _qb[idx];
      } else {
        // 定朔
        dRes = int2(
          _soLow(int2((jd + pc - 2451551) / 29.5306) * math.pi * 2) + 0.5,
        ).toDouble();
        final idx = int2((jd - f2) / 29.5306);
        if (idx >= 0 && idx < _sb.length) n = _sb[idx];
      }

      if (n == "1") dRes += 1;
      if (n == "2") dRes -= 1;
      // 注意：这里 _qiLow / _soLow 返回的已经是 J2000 相对值
      // 修正表也是基于 J2000 相对值调整
      return dRes;
    }

    return 0; // Should not reach here
  }

  // ==================== 农历排谱 ====================

  /// 农历排月序计算。
  ///
  /// 有效范围：两个冬至之间 (冬至一 <= d < 冬至二)。
  /// [jd] 为目标日期附近的 J2000 相对儒略日。
  ///
  /// 返回该年的 SSQResult。
  SSQResult calcY(double jd) {
    final zq = List<double>.filled(25, 0);
    final hs = List<double>.filled(15, 0);
    final dx = List<int>.filled(14, 0);
    final ym = List<String>.filled(14, "");
    int leap = 0;

    // 1. 确定年份和冬至
    // 355 = 2000.12 冬至 (J2000相对值)
    // 估算最近的冬至
    var w = int2((jd - 355 + 183) / 365.2422) * 365.2422 + 355;
    if (calc(w, 1) > jd) w -= 365.2422;

    // 2. 计算 25 个节气 (从冬至开始)
    for (var i = 0; i < 25; i++) {
      zq[i] = calc(w + 15.2184 * i, 1);
    }

    // 3. 计算“首朔”
    // 求较靠近冬至的朔日
    var wSho = calc(zq[0], 0);
    if (wSho > zq[0]) wSho -= 29.53;

    // 4. 计算该年所有朔 (15个)
    for (var i = 0; i < 15; i++) {
      hs[i] = calc(wSho + 29.5306 * i, 0);
    }

    // 5. 计算月大小
    for (var i = 0; i < 14; i++) {
      dx[i] = (hs[i + 1] - hs[i]).toInt();
    }

    // 6. 处理特殊历史历法 (春秋/战国/秦汉 -721 ~ -104)
    // 这部分逻辑比较复杂，先简化处理或完整移植
    final yy = int2((zq[0] + 10 + 180) / 365.2422) + 2000;
    if (yy >= -721 && yy <= -104) {
      // 历史特殊规则移植
      final ns = List<double>.filled(3, 0);
      final nsName = List<String>.filled(3, "");
      final nsMonth = List<int>.filled(3, 0);

      for (var i = 0; i < 3; i++) {
        final y = yy + i - 1;
        if (y >= -721) {
          ns[i] = calc(
            1457698 - j2000 + int2(0.342 + (y + 721) * 12.368422) * 29.5306,
            0,
          );
          nsName[i] = '十三';
          nsMonth[i] = 2; // 建丑
        }
        if (y >= -479) {
          ns[i] = calc(
            1546083 - j2000 + int2(0.500 + (y + 479) * 12.368422) * 29.5306,
            0,
          );
          nsName[i] = '十三';
          nsMonth[i] = 2; // 建丑
        }
        if (y >= -220) {
          ns[i] = calc(
            1640641 - j2000 + int2(0.866 + (y + 220) * 12.369000) * 29.5306,
            0,
          );
          nsName[i] = '后九';
          nsMonth[i] = 11; // 建亥
        }
      }

      for (var i = 0; i < 14; i++) {
        int nn;
        for (nn = 2; nn >= 0; nn--) {
          if (hs[i] >= ns[nn]) break;
        }
        if (nn < 0) nn = 0; // Fallback

        final f1 = int2((hs[i] - ns[nn] + 15) / 29.5306); // 该月积数
        if (f1 < 12) {
          ym[i] = monthNames[(f1 + nsMonth[nn]) % 12];
        } else {
          ym[i] = nsName[nn];
        }
      }
      // 历史历法不计算 leap，直接返回
      return SSQResult(zq: zq, hs: hs, dx: dx, ym: ym, leap: 0);
    }

    // 7. 无中气置闰法
    // 临时月序初始化
    final ymInt = List<int>.filled(14, 0);
    for (var i = 0; i < 14; i++) {
      ymInt[i] = i;
    }

    if (hs[13] <= zq[24]) {
      // 第13月的月末没有超过下一个冬至，说明今年有13个月
      int i;
      for (i = 1; i < 13; i++) {
        // 找第一个没有中气的月份
        // B[i] 是月初，B[i+1] 是下月初
        // A[2*i] 是该月对应的中气 (冬至是 A[0], 小寒 A[1], 大寒 A[2]...)
        // 这里的对应关系：
        // 月序 i=0 (包含冬至 A[0])
        // 月序 i=1 (应包含大寒 A[2])
        // 所以检查第 i 个月是否有中气，就是看 B[i+1] > A[2*i]
        // 如果 B[i+1] <= A[2*i]，说明中气落到了下个月，本月无中气
        if (hs[i + 1] <= zq[2 * i]) {
          break;
        }
      }
      leap = i;
      // 闰月之后的月序减一
      for (; i < 14; i++) {
        ymInt[i]--;
      }
    }

    // 8. 月名转换与月建处理
    for (var i = 0; i < 14; i++) {
      final dm = hs[i] + j2000;
      final v2 = ymInt[i];
      var mc = monthNames[v2 % 12]; // 默认月建

      // 特殊时期的月建调整
      if (dm >= 1724360 && dm <= 1729794) {
        mc = monthNames[(v2 + 1) % 12]; // 新莽
      } else if (dm >= 1807724 && dm <= 1808699) {
        mc = monthNames[(v2 + 1) % 12]; // 魏明帝
      } else if (dm >= 1999349 && dm <= 1999467) {
        mc = monthNames[(v2 + 2) % 12]; // 武则天
      } else if (dm >= 1973067 && dm <= 1977052) {
        // 武则天周历
        if (v2 % 12 == 0) mc = "正";
        if (v2 == 2) mc = '一';
      }

      // 改名避免重复
      if (dm == 1729794 || dm == 1808699) mc = '拾贰';

      ym[i] = mc;
    }

    return SSQResult(zq: zq, hs: hs, dx: dx, ym: ym, leap: leap);
  }
}
