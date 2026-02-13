import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:sxwnl_dart/src/sxwnl/ssq.dart';
import 'package:sxwnl_dart/src/astro_date_time.dart';

void main() {
  final ssq = SSQ();

  // 辅助：JD 转可读字符串
  String jdStr(double jd) {
    // 加上 J2000 偏移
    final dt = AstroDateTime.fromJ2000(jd);
    return dt.toString();
  }

  group('SSQ.calc (节气/合朔)', () {
    test('2000年冬至 (J2000前)', () {
      // 2000年冬至约在 2000-12-21
      // J2000 = 2000-01-01 12:00
      // 2000-12-21 距 J2000 约 355 天
      // 估算 JD ≈ 355
      final jd = ssq.calc(355, 1); // 1=气
      final dt = AstroDateTime.fromJ2000(jd);
      // 预期：2000-12-21 左右
      expect(dt.year, 2000);
      expect(dt.month, 12);
      expect(dt.day, 21);
    });

    test('2000年首朔', () {
      // 2000年1月6日 18:14 UTC 是朔日
      // 北京时间是 1月7日 02:14
      // sxwnl 返回的是北京时间的整数日
      final jd = ssq.calc(5, 0); // 0=朔
      final dt = AstroDateTime.fromJ2000(jd);
      expect(dt.year, 2000);
      expect(dt.month, 1);
      expect(dt.day, 7);
    });
  });

  group('SSQ.calcY (农历排谱)', () {
    test('2023年 (闰二月)', () {
      // 2023年春节是 1月22日
      // 2023年中大概是 JD = (2023-2000)*365.25 ≈ 8400
      final result = ssq.calcY(8400);

      // 验证闰月: 2023年闰二月 (第3个月是闰月，index=2)
      // 注意：sxwnl 的 result.leap 返回的是“闰月及其之后月份的索引修正前的位置”
      // 或者直接看 monthNames
      // result.ym 应该是 ["正", "二", "二", "三"...] ?
      // 不，sxwnl 的 ym 存储的是月名字符串。
      // 2023年农历序列：正、二、闰二、三、四...
      // 对应的 ym 数组：["正", "二", "二", "三", ...]
      // leap 字段：如果 leap=i，表示第 i 个月是闰月（1-based? 还是 0-based?）
      // 看 ssq.dart 源码：
      // if (B[13] <= A[24]) ... this.leap = i;
      // i 从 1 开始找。
      // 如果 leap > 0，则第 leap 个月（从0开始数）是闰月？
      // 让我们直接打印来看看。

      // 验证月份数量
      // 闰年有 13 个月，但 hs 数组固定 15 个（首尾多算），ym 和 dx 固定 14 个。
      // 实际上我们要看的是有效月份。
      // 2023年确实有闰月，leap 应该 > 0。
      expect(result.leap, greaterThan(0));

      // 验证闰二月
      // 正常年份 result.leap = 0
      // 2023年 result.leap 应该是 2 (因为第0个是正月，第1个是二月，第2个是闰二月)
      // 让我们检查 ym[2]
      // 如果是闰二月，ym[1]="二", ym[2]="二" (名称相同，或者有特殊标记?)
      // ssq.dart 源码里没有给闰月加 "闰" 字前缀，只是调整了月序。
      // 需要在上层逻辑加 "闰" 字。
      // 这里只需要确认有两个 "二" 月。
      int twoCount = result.ym.where((n) => n == '二').length;
      expect(twoCount, 2);
    });

    test('2020年 (闰四月)', () {
      // JD ≈ 7300
      final result = ssq.calcY(7300);
      expect(result.leap, greaterThan(0));
      // 应该有两个 "四" 月
      int fourCount = result.ym.where((n) => n == '四').length;
      expect(fourCount, 2);
    });

    test('2021年 (无闰月)', () {
      // JD ≈ 7665
      final result = ssq.calcY(7665);
      expect(result.leap, 0);
      // 每个月名只出现一次
      int twoCount = result.ym.where((n) => n == '二').length;
      expect(twoCount, 1);
    });
  });

  group('历史农历验证', () {
    test('公元前221年 (秦汉历)', () {
      // 随便选一个历史日期验证算法不崩溃
      // BC 221 ≈ -2220 年
      // JD ≈ (-2220 - 2000) * 365.25 ≈ -1540000
      // AstroDateTime(-220, 1, 1).toJ2000()
      final jd = AstroDateTime(-220, 1, 1).toJ2000();
      final result = ssq.calcY(jd);
      // 只要能算出来就行
      expect(result.ym.length, 14);
    });
  });
}
