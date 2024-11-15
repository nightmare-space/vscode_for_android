import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';
import 'package:xterm/xterm.dart';
import 'config.dart';
import 'utils/http_handler.dart';
import 'io.dart';
import 'script.dart';
import 'utils/plugin_util.dart';
import 'utils/pty_util.dart';
import 'utils/zip_util.dart';
import 'package:path/path.dart' as path;

class HomeController extends GetxController {
  Pty? pseudoTerminal;
  bool vsCodeStaring = false;
  Terminal terminal = Terminal(
    maxLines: 10000,
  );
  bool webviewHasOpen = false;
  Future<void> unzipVSCodeIfNotExist() async {
    // TODO 安卓13无法写入到外部储存
    String appCodePath = '${RuntimeEnvir.homePath}/code-server-${Config.defaultCodeServerVersion}-linux-arm64.tar.gz';
    if (!File(appCodePath).existsSync()) {
      terminal.write('拷贝App内${Config.defaultCodeServerVersion}版本Code Server到数据目录...\n\r');
      try {
        await AssetsUtils.copyAssetToPath('assets/code-server-${Config.defaultCodeServerVersion}-linux-arm64.tar.gz', appCodePath);
      } catch (e) {
        terminal.write(e.toString());
        Log.e(e);
      }
    }
    if (!File('$ubuntuPath/opt/code-server-$version-linux-arm64/bin/code-server').existsSync()) {
      terminal.write('解压中$version到${RuntimeEnvir.homePath}\n\r');
      try {
        await extractTarGz(
          readBinaryFileAsStream(appCodePath),
          RuntimeEnvir.homePath,
          (data) {
            // print(data);
            terminal.write('\x1b[J\x1b7$data\x1b8');
          },
        );
        return;
      } catch (e) {
        terminal.write(e.toString());
      }
    }
    if (File('$ubuntuPath/opt/code-server-$version-linux-arm64/bin/code-server').existsSync()) {
      terminal.write('Ubuntu数据目录已存在$version的Code Server\n\r');
      return;
    }
    terminal.write('未发现这个版本的VS Code，解压中...\n\r');
    Log.i('未发现这个版本的VS Code，解压中...');
    try {
      await extractTarGz(
        readBinaryFileAsStream('/storage/emulated/0/code-server-$version-linux-arm64.tar.gz'),
        RuntimeEnvir.homePath,
        (data) {
          // print(data);
          terminal.write('\x1b[2K\x1b7$data\x1b8');
        },
      );
    } catch (e) {
      terminal.write(e.toString());
    }

    terminal.write('\n\r');
  }

  /// 监听输出，当输出中包含vscode启动成功的标志时，启动vscode
  Future<void> vsCodeStartWhenSuccessBind() async {
    terminal.write('监听VS Code启动状态以跳转Web View...\n\r');
    // WebView.platform = SurfaceAndroidWebView();
    final Completer completer = Completer();
    pseudoTerminal!.output.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen((event) async {
      final List<String> list = event.split(RegExp('\x0d|\x0a'));
      final String lastLine = list.last.trim();
      if (lastLine.startsWith(RegExp('dart_dio'))) {
        String data = event.replaceAll(RegExp('dart_dio.*'), '');
        terminal.write(data);
        HttpHandler.handDownload(
          controller: terminal,
          cmdLine: list.last,
        );
        return;
      }
      if (event.contains('http://0.0.0.0:${Config.port}')) {
        Log.e(event);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      if (event.contains('already')) {
        Log.e(event);
        // if (!completer.isCompleted) {
        //   completer.complete();
        // }
      }

      terminal.write(event);
      // event.split('').forEach((element) {
      //   terminal.write(event);
      // });
    });
    await completer.future;
    await Future.delayed(const Duration(milliseconds: 100));
    webviewHasOpen = true;
    // 用url_launcher打开浏览器
    PluginUtil.openWebView();
    update();
    Future.delayed(const Duration(milliseconds: 2000), () {
      vsCodeStaring = false;
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      update();
    });
  }

  // 是否存在bash文件，初始化后 bash 应该存在
  bool hasBash() {
    final File bashFile = File('${RuntimeEnvir.binPath}/bash');
    final bool exist = bashFile.existsSync();
    return exist;
  }

  Future<void> createPtyTerm() async {
    if (Platform.isAndroid) {
      await PermissionUtil.requestStorage();
    }
    File file = File('/sdcard/code_version');
    try {
      if (!file.existsSync()) {
        file.createSync();
        file.writeAsStringSync(Config.defaultCodeServerVersion);
      }
    } catch (e) {
      // 在小米平板6上会有异常，无法创建文件，怀疑是和Android系统有关
    }
    if (file.existsSync()) version = file.readAsStringSync();
    if (version.isEmpty) {
      version = Config.defaultCodeServerVersion;
    }
    terminal.write('当前VS Code Server版本:$version...\n\r');
    // 创建相关文件夹
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory(RuntimeEnvir.homePath).createSync(recursive: true);
    Directory('$prootDistroPath/dlcache').createSync(recursive: true);
    Directory(RuntimeEnvir.binPath).createSync(recursive: true);

    // proot-distro 用来安装ubuntu
    await AssetsUtils.copyAssetToPath(
      'assets/proot-distro.zip',
      '${RuntimeEnvir.homePath}/proot-distro.zip',
    );

    final inputStream = InputFileStream('${RuntimeEnvir.homePath}/proot-distro.zip');
    // Decode the zip from the InputFileStream. The archive will have the contents of the
    // zip, without having stored the data in memory.
    final archive = ZipDecoder().decodeBuffer(inputStream);
    // For all of the entries in the archive
    for (var file in archive.files) {
      // If it's a file and not a directory
      if (file.isFile) {
        // Write the file content to a directory called 'out'.
        // In practice, you should make sure file.name doesn't include '..' paths
        // that would put it outside of the extraction directory.
        // An OutputFileStream will write the data to disk.
        final outputStream = OutputFileStream('${RuntimeEnvir.homePath}/${file.name}');
        // The writeContent method will decompress the file content directly to disk without
        // storing the decompressed data in memory.
        file.writeContent(outputStream);
        // Make sure to close the output stream so the File is closed.
        outputStream.close();
      }
    }
    // ubuntu资源包
    await AssetsUtils.copyAssetToPath(
      'assets/ubuntu-aarch64-pd-v3.0.1.tar.xz',
      '$prootDistroPath/dlcache/ubuntu-aarch64-pd-v3.0.1.tar.xz',
    );
    if (!hasBash()) {
      initTerminal();
      return;
    }

    terminal.write('创建PTY终端实例...\n\r');
    pseudoTerminal = createPTY();
    terminal.write('定义需要使用的函数...\n\r');

    /// 定义需要使用的函数
    Uint8List bytesStartVsCodeScript = utf8.encode(startVsCodeScript);
    pseudoTerminal!.write(bytesStartVsCodeScript);
    update();
    vsCodeStartWhenSuccessBind();
    await unzipVSCodeIfNotExist();
    startVsCode(pseudoTerminal!);
  }

  Future<void> startVsCode(Pty pseudoTerminal) async {
    vsCodeStaring = true;
    update();
    terminal.write('开始启动VS Code...\n\r');
    Uint8List bytesStartVSCode = utf8.encode('''start_vs_code\n''');
    pseudoTerminal.write(bytesStartVSCode);
  }

  Future<void> initTerminal() async {
    pseudoTerminal = createPTY(shell: '/system/bin/sh');
    vsCodeStartWhenSuccessBind();
    Uint8List bytesInitShell = utf8.encode(initShell);
    pseudoTerminal!.write(bytesInitShell);
    update();
    terminal.write(getRedLog('- 解压资源中...\r\n'));

    await AssetsUtils.copyAssetToPath(
      'assets/bootstrap-aarch64.zip',
      '${RuntimeEnvir.tmpPath}/bootstrap-aarch64.zip',
    );
    await ZipUtil.unzipBootstrap('${RuntimeEnvir.tmpPath}/bootstrap-aarch64.zip', onFile: (String name) {
      terminal.write('\x1b[2K\x1b7- ${path.basename(name)}.\x1b8');
    });
    terminal.write('\r\n');
    await unzipVSCodeIfNotExist();
    Uint8List bytesInitApp = utf8.encode('initApp\n');
    pseudoTerminal!.write(bytesInitApp);
  }

  @override
  void onInit() {
    super.onInit();
    Future.delayed(Duration.zero, () async {
      SettingNode settingNode = 'privacy'.setting;
      if (settingNode.get() == null) {
        await Get.to(PrivacyAgreePage(
          onAgreeTap: () {
            settingNode.set(true);
            Get.back();
          },
        ));
      }
      createPtyTerm();
    });
  }

  Future<bool> isLocalAsset(final String assetPath) async {
    final encoded = utf8.encoder.convert(Uri(path: Uri.encodeFull(assetPath)).path);
    final asset = await ServicesBinding.instance.defaultBinaryMessenger.send('flutter/assets', encoded.buffer.asByteData());
    return asset != null;
  }
}
