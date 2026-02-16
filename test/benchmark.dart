import 'dart:io';
import 'dart:math';
import 'package:test/test.dart';
import 'package:sxwnl_spa_dart/sxwnl_spa_dart.dart';

void main() {
  test('Benchmark 7000 years', () async {
    final file = File('../benchmark_test/solar_terms_7000y.csv');
    if (!await file.exists()) {
      print("CSV file not found at ${file.absolute.path}");
      return;
    }
    final lines = await file.readAsLines();

    final ssq = SSQ();

    // 统计变量
    double maxError = 0;
    double totalError = 0;
    int countExact = 0; // < 0.01s
    int countLess1s = 0;
    int countLess4s = 0;
    int countLarge = 0;
    int total = 0;

    // 跳过表头
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 3) continue;

      final year = int.parse(parts[0]);
      if (year != 2000) continue; // 只跑 2000 年
      final idx = int.parse(parts[1]);
      final expectedJD = double.parse(parts[2]);

      // 复刻生成逻辑
      final estJD = (year - 2000) * 365.2422 + 355;
      final w = ((estJD - 355 + 183) / 365.2422).floor() * 365.2422 + 355;

      // Dart 计算
      final actualJD = ssq.calc(w + 15.2184 * idx, 1);

      // 误差 (秒)
      // 1 JD = 86400 秒
      final diffDays = (actualJD - expectedJD).abs();
      final diffSeconds = diffDays * 86400;

      totalError += diffSeconds;
      maxError = max(maxError, diffSeconds);

      if (diffSeconds < 0.01) {
        countExact++;
      } else if (diffSeconds < 1.0) {
        countLess1s++;
      } else if (diffSeconds < 4.0) {
        countLess4s++;
      } else {
        countLarge++;
        if (countLarge <= 5) {
          print(
            'Large Error at Year $year Term $idx: Exp=$expectedJD Act=$actualJD Diff=${diffSeconds.toStringAsFixed(4)}s',
          );
        }
      }
      total++;

      if (i % 50000 == 0) {
        print('Processed $i records...');
      }
    }

    print('\n=== Benchmark Results ===');
    print('Total Records: $total');
    print('Max Error: ${maxError.toStringAsFixed(6)} seconds');
    print('Avg Error: ${(totalError / total).toStringAsFixed(6)} seconds');
    print('');
    print('Distribution:');
    print(
      '  Exact (<0.01s): $countExact (${(countExact / total * 100).toStringAsFixed(2)}%)',
    );
    print(
      '  < 1 second    : $countLess1s (${(countLess1s / total * 100).toStringAsFixed(2)}%)',
    );
    print(
      '  < 4 seconds   : $countLess4s (${(countLess4s / total * 100).toStringAsFixed(2)}%)',
    );
    print(
      '  > 4 seconds   : $countLarge (${(countLarge / total * 100).toStringAsFixed(2)}%)',
    );

    // 断言：不允许有超过 4 秒的误差
    expect(countLarge, 0);
    // 断言：99.9% 的误差小于 1 秒
    expect((countExact + countLess1s) / total, greaterThan(0.999));
  }, timeout: Timeout(Duration(minutes: 5)));
}
