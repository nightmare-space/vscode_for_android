import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/xterm.dart';

Pty createPTY({
  String? shell,
}) {
  Map<String, String> envir = Map.from(Platform.environment);
  envir['HOME'] = RuntimeEnvir.homePath;
  // proot-distro install need
  envir['TERMUX_PREFIX'] = RuntimeEnvir.usrPath;
  envir['TERM'] = 'xterm-256color';
  envir['PATH'] = RuntimeEnvir.path;
  // proot deps
  envir['PROOT_LOADER'] = '${RuntimeEnvir.binPath}/loader';
  envir['LD_LIBRARY_PATH'] = RuntimeEnvir.binPath;

  return Pty.start(
    '/system/bin/sh',
    arguments: [],
    environment: envir,
    workingDirectory: RuntimeEnvir.homePath,
  );
}

extension TerminalExt on Terminal {
  void writeProgress(String data) {
    write('\x1b[31m- $data\x1b[0m\n\r');
  }
}

extension PTYExt on Pty {
  void writeString(String data) {
    write(Uint8List.fromList(utf8.encode(data)));
  }

  Future<void> defineFunction(String function) async {
    Log.i('define function start');
    Completer defineFunctionLock = Completer();
    Directory tmpDir = Directory(RuntimeEnvir.tmpPath);
    await tmpDir.create(recursive: true);
    String shortHash = hashCode.toRadixString(16).substring(0, 4);
    File shellFile = File('${tmpDir.path}/shell$shortHash');
    String patchFunction = '$function\n'
        r'''
    #printf "\033[A"
    #printf "\033[2K"
    #printf "\033[A"
    #printf "\033[2K"''';
    await shellFile.writeAsString(patchFunction);
    shellFile.watch(events: FileSystemEvent.delete).listen((event) {
      defineFunctionLock.complete();
    });
    File('${tmpDir.path}/shell${shortHash}backup').writeAsStringSync(function);
    // writeString('printf "\\033[?1049h"\n');
    writeString('source ${shellFile.path} &&');
    writeString('rm -rf ${shellFile.path} \n');
    //terminal?.buffer.eraseLine();
    // await Future.delayed(const Duration(milliseconds: 100));
    // writeString('printf "\\033[?1049l"\n');

    // bool fileExists = await shellFile.exists();
    // while (fileExists) {
    //   Log.v('File exists.');
    //   await Future.delayed(const Duration(milliseconds: 100)); // 每秒检查一次
    //   fileExists = await shellFile.exists();
    // }

    // 用 file watch 代替上面功能
    await defineFunctionLock.future;
    Log.i('define function -> done');
  }
}
