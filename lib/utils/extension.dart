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
    Log.i('define function start');
    Directory tmpDir = Directory(RuntimeEnvir.tmpPath);
    await tmpDir.create(recursive: true);
    String shortHash = hashCode.toRadixString(16).substring(0, 4);
    File shellPath = File('${tmpDir.path}/shell$shortHash');
    String patchFunction = '$function\n'
        r'''
    printf "\033[A"
    printf "\033[2K"
    printf "\033[A"
    printf "\033[2K"''';
    shellPath.writeAsStringSync(patchFunction);
    File('${tmpDir.path}/shell${shortHash}backup').writeAsStringSync(function);
    // writeString('printf "\\033[?1049h"\n');
    writeString('source ${shellPath.path} &&');
    writeString('rm -rf ${shellPath.path} \n');
    //terminal?.buffer.eraseLine();
    await Future.delayed(const Duration(milliseconds: 100));
    // writeString('printf "\\033[?1049l"\n');
    bool fileExists = await shellPath.exists();
    while (fileExists) {
      Log.v('File exists.');
      await Future.delayed(const Duration(milliseconds: 100)); // 每秒检查一次
      fileExists = await shellPath.exists();
    }
    Log.i('define function -> done');
    // await defineFunctionLock.future;
  }
}
