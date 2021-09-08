import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class AssetsUtils {
  AssetsUtils._();
  static Future<void> copyAssetToPath(String key, String path) async {
    final ByteData byteData = await rootBundle.load(key);
    final Uint8List picBytes = byteData.buffer.asUint8List();
    final File file = File(path);
    if (!await file.exists()) {
      await file.writeAsBytes(picBytes);
    }
  }
}
