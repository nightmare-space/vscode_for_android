import 'dart:io';

import 'package:archive/archive.dart';
import 'package:global_repository/global_repository.dart';

class ZipUtil {
  static Future<void> unzipBootstrap(
    String modulePath, {
    void Function(String name)? onFile,
  }) async {
    // Read the Zip file from disk.
    final bytes = File(modulePath).readAsBytesSync();
    // Decode the Zip file
    final archive = ZipDecoder().decodeBytes(bytes);
    // Extract the contents of the Zip archive to disk.
    // final int total = archive.length;
    // int count = 0;
    // print('total -> $total count -> $count');
    for (final file in archive) {
      final filename = file.name;
      final String path = '${RuntimeEnvir.usrPath}/$filename';
      onFile?.call(filename);
      // Log.d(path);
      if (file.isFile) {
        final data = file.content as List<int>;
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(data);
      } else {
        Directory(path).create(
          recursive: true,
        );
      }
      // count++;
      // Log.d('total -> $total count -> $count');
    }
    File(modulePath).delete();
  }
}
