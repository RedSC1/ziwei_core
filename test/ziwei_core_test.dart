import 'dart:io'; // 用来读硬盘文件的
import 'package:test/test.dart'; // 测试框架
// 下面这两个 import 要根据你的实际路径改一下
import 'package:ziwei_core/src/config/loader.dart'; 
import 'package:ziwei_core/src/enums/config_enums.dart';
import 'package:ziwei_core/src/time/ziwei_date.dart';

void main() {
  // 定义一个组
  group('ConfigLoader 测试', () {
    
    test('能够读取并解析 main_rules.json', () {
      // 1. 找到你的 JSON 文件 (路径是以项目根目录为起点的)
      final file = File('assets/config/default/main_rules.json');
      
      // 检查一下文件在不在，不在的话打印路径方便排查
      if (!file.existsSync()) {
        fail('找不到文件: ${file.absolute.path}');
      }
      
      // 2. 读取内容
      final jsonStr = file.readAsStringSync();

      // 3. 喂给你的 ConfigLoader
      // 因为是 Strict 模式，如果解析出错这里会直接抛异常报错 (Test Failed)
      final options = ConfigLoader.parse(jsonStr);
      
      var dt = DateTime(2002,1,1,23,00);

      var d = ZiweiDate.fromSolar(dt, options: options);
      print(d.toString());
     
    });
  });
}