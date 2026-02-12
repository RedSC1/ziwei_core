import 'dart:convert';
import 'dart:io';
import 'package:ziwei_core/src/config/schemas/flow_definition.dart';

void main() async {
  try {
    final file = File('assets/config/default/flow_stars.json');
    if (!await file.exists()) {
      print('❌ File not found: ${file.path}');
      return;
    }
    final jsonStr = await file.readAsString();
    print('📂 JSON content length: ${jsonStr.length}');

    final List<dynamic> list = jsonDecode(jsonStr);
    print('🔢 Found ${list.length} entries in JSON list');

    int successCount = 0;
    for (var i = 0; i < list.length; i++) {
      try {
        FlowDefinition.fromJson(list[i]);
        successCount++;
      } catch (e) {
        print('❌ Failed to parse item $i: $e');
        print('   Item content: ${list[i]}');
      }
    }
    print('✅ Successfully parsed $successCount items');

  } catch (e, s) {
    print('❌ Fatal error: $e');
    print(s);
  }
}
