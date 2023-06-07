import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:global_repository/global_repository.dart';

Pty createPTY({
  String? shell,
}) {
  shell ??= '${RuntimeEnvir.binPath}/bash';
  late Map<String, String> envir;
  envir = Map.from(Platform.environment);
  envir['HOME'] = RuntimeEnvir.homePath;
  envir['TERMUX_PREFIX'] = RuntimeEnvir.usrPath;
  envir['TERM'] = 'xterm-256color';
  envir['PATH'] = RuntimeEnvir.path;
  if (File('${RuntimeEnvir.usrPath}/lib/libtermux-exec.so').existsSync()) {
    envir['LD_PRELOAD'] = '${RuntimeEnvir.usrPath}/lib/libtermux-exec.so';
  }
  return Pty.start(
    '/system/bin/sh',
    arguments: [],
    environment: envir,
    workingDirectory: RuntimeEnvir.homePath,
  );
}
