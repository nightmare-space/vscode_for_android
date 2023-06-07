import 'dart:io';

import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/xterm.dart';

import 'io.dart';
import 'script.dart';

class HomeController extends GetxController {
  Terminal terminal = Terminal();
  Future<void> unzipVSCodeIfNotExist() async {
    if (File('$ubuntuPath/home/code-server-$version-linux-arm64/bin/code-server').existsSync()) {
      return;
    }
    Log.i('未发现这个版本的VS Code，解压中...');
    await extractTarGz(
      readBinaryFileAsStream('/sdcard/code-server-$version-linux-arm64.tar.gz'),
      RuntimeEnvir.homePath,
      (data) {
        print(data);
        terminal.write(data);
      },
    );
  }
}
