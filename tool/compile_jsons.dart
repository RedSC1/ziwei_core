import 'dart:io';

void main(List<String> args) async {
  // 默认值
  String inputDir = 'assets/config/default';
  String outputFileUrl = 'lib/src/config/default_jsons.dart';
  String className = 'DefaultJsons';

  // 解析命令行参数（非常基础的可选参数支持）
  // 用法: dart run tool/compile_jsons.dart [input_dir] [output_file] [class_name]
  if (args.isNotEmpty) inputDir = args[0];
  if (args.length > 1) outputFileUrl = args[1];
  if (args.length > 2) className = args[2];

  final assetsDir = Directory(inputDir);
  if (!assetsDir.existsSync()) {
    print("❌ 找不到输入目录: \$inputDir");
    exit(1);
  }

  final outputFile = File(outputFileUrl);
  // 确保输出文件的目录存在
  if (!outputFile.parent.existsSync()) {
    outputFile.parent.createSync(recursive: true);
  }

  final sb = StringBuffer();

  sb.writeln('// 自动生成的文件，请勿手动修改 (Generated File)');
  sb.writeln('//');
  sb.writeln(
    '// 运行 `dart run tool/compile_jsons.dart \$inputDir \$outputFileUrl \$className` 更新此文件',
  );
  sb.writeln('class \$className {');

  final files = assetsDir.listSync().whereType<File>().toList();
  for (var file in files) {
    if (file.path.endsWith('.json')) {
      final name = file.uri.pathSegments.last.replaceAll('.json', '');
      final content = await file.readAsString();

      // 处理转义字符，特别是 $ 符号在 dart 字符串模板里的转义
      final escapedContent = content
          .replaceAll('\$', '\\\$')
          .replaceAll('\\', '\\\\');

      // 驼峰命名
      final camelName = _toCamelCase(name);

      sb.writeln('  static const String $camelName = r"""');
      sb.writeln(escapedContent);
      sb.writeln('""";');
      sb.writeln();
      print('✅ 编译了 $name.json -> $className.$camelName');
    }
  }

  sb.writeln('}');

  await outputFile.writeAsString(sb.toString());
  print('🎉 所有 JSON 编译完成！已输出至: ${outputFile.path}');

  // 格式化输出的 dart 文件
  await Process.run('dart', ['format', outputFile.path]);
}

String _toCamelCase(String text) {
  final parts = text.split('_');
  final sb = StringBuffer(parts.first.toLowerCase());
  for (int i = 1; i < parts.length; i++) {
    final part = parts[i];
    sb.write(part[0].toUpperCase());
    sb.write(part.substring(1).toLowerCase());
  }
  return sb.toString();
}
