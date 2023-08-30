import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:global_repository/global_repository.dart';

extension PTYExt on Pty {
  void writeString(String data) {
    write(Uint8List.fromList(utf8.encode(data)));
  }

  Future<void> defineFunction(String function) async {
    print('define func');
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory dir = Directory(RuntimeEnvir.tmpPath).createTempSync();
    File('${dir.path}/shell').writeAsStringSync(function);
    write(Uint8List.fromList(const Utf8Encoder().convert('source ${dir.path}/shell\n')));
    // 等待1s,source完成后删除源文件
    Future.delayed(const Duration(seconds: 1), () {
      dir.delete(recursive: true);
    });
  }
}
