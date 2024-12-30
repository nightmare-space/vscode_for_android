import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';
import 'package:xterm/xterm.dart';
import 'config.dart';
import 'script.dart';
import 'utils/plugin_util.dart';
import 'utils/pty_util.dart';

// TODO: 点击背景即可展示终端内容
// 默认只加载进度条
class HomeController extends GetxController {
  Pty? pseudoTerminal;
  bool vsCodeStaring = false;
  late Terminal terminal = Terminal(
    maxLines: 10000,
    onResize: (width, height, pixelWidth, pixelHeight) {
      pseudoTerminal!.resize(height, width);
    },
    onOutput: (data) {
      pseudoTerminal!.writeString(data);
    },
  );
  bool webviewHasOpen = false;

  double progress = 0.0;
  double step = 11;
  String lastLine = '';
  File file = File('${RuntimeEnvir.tmpPath}/progress');

  void updateProgress(int value) {
    file.writeAsString('$value');
    update();
  }

  /// 监听输出，当输出中包含vscode启动成功的标志时，启动vscode
  Future<void> vsCodeStartWhenSuccessBind() async {
    terminal.writeProgress('监听VS Code启动状态以跳转Web View...');
    // WebView.platform = SurfaceAndroidWebView();
    final Completer completer = Completer();
    pseudoTerminal!.output.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen((event) async {
      // final List<String> list = event.split(RegExp('\x0d|\x0a'));
      // final String lastLine = list.last.trim();
      // if (lastLine.startsWith(RegExp('dart_dio'))) {
      //   String data = event.replaceAll(RegExp('dart_dio.*'), '');
      //   terminal.write(data);
      //   HttpHandler.handDownload(
      //     controller: terminal,
      //     cmdLine: list.last,
      //   );
      //   return;
      // }
      lastLine = event.trim().split(RegExp('\x0d|\x0a')).last;
      update();
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
    updateProgress(11);
    update();
    PluginUtil.openWebView();
    Future.delayed(const Duration(milliseconds: 2000), () {
      vsCodeStaring = false;
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      update();
    });
  }

  Future<void> initEnvir() async {
    List<String> androidFiles = [
      'libbash.so',
      'libbusybox.so',
      'liblibtalloc.so.2.so',
      'libloader.so',
      'libproot.so',
      'libsudo.so',
    ];
    String libPath = await PluginUtil.getLibPath();
    Log.i('libPath -> $libPath');

    for (int i = 0; i < androidFiles.length; i++) {
      // when android target sdk > 28
      // cannot execute file in /data/data/com.xxx/files/usr/bin
      // so we need create a link to /data/data/com.xxx/files/usr/bin
      final sourcePath = '$libPath/${androidFiles[i]}';
      String fileName = androidFiles[i].replaceAll(RegExp('^lib|\\.so\$'), '');
      String filePath = '${RuntimeEnvir.binPath}/$fileName';
      // custom path, termux-api will invoke
      File file = File(filePath);
      FileSystemEntityType type = await FileSystemEntity.type(filePath);
      Log.i('$fileName type -> $type');
      if (type != FileSystemEntityType.notFound && type != FileSystemEntityType.link) {
        // old version adb is plain file
        Log.i('find plain file -> $fileName, delete it');
        await file.delete();
      }
      Link link = Link(filePath);
      if (link.existsSync()) {
        link.deleteSync();
      }
      try {
        Log.i('create link -> $fileName ${link.path}');
        link.createSync(sourcePath);
      } catch (e) {
        Log.e('installAdbToEnvir error -> $e');
      }
    }
  }

  void syncProgress() {
    file.createSync(recursive: true);
    file.watch(events: FileSystemEvent.all).listen((event) async {
      if (event.type == FileSystemEvent.modify) {
        String content = await file.readAsString();
        Log.e('content -> $content');
        if (content.isEmpty) {
          return;
        }
        progress = int.parse(content) / step;
        Log.e('progress -> $progress');
        update();
        // terminal.writeProgress(content);
      }
    });
    updateProgress(0);
  }

  void createBusyboxLink() {
    try {
      // 创建 ${RuntimeEnvir.binPath}/busybox 到 ${RuntimeEnvir.binPath}/xz 的软连接
      List<String> links = [
        'xz',
        'realpath',
        'basename',
        'awk',
        'bzip2',
        'cat',
        'chmod',
        'cp',
        'curl',
        'cut',
        'du',
        'file',
        'find',
        'grep',
        'gzip',
        // head id lscpu mkdir proot rm sed tar xargs xz
        'head',
        'id',
        'lscpu',
        'mkdir',
        'rm',
        'sed',
        'tar',
        'xargs',
        'xz',
        'uname',
        'stat',
      ];

      for (String linkName in links) {
        Link link = Link('${RuntimeEnvir.binPath}/$linkName');
        if (!link.existsSync()) {
          link.createSync('${RuntimeEnvir.binPath}/busybox');
        }
      }
    } catch (e) {
      Log.e('创建软连接失败 -> $e');
    }
  }

  Future<void> createPtyTerm() async {
    if (GetPlatform.isAndroid) {
      PermissionStatus status = await Permission.manageExternalStorage.request();
      Log.i('status -> $status');
      if (!status.isGranted) {
        return;
      }
    }
    // 创建相关文件夹
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory(RuntimeEnvir.homePath).createSync(recursive: true);
    Directory(RuntimeEnvir.binPath).createSync(recursive: true);
    await initEnvir();
    File file = File('/sdcard/code_version');
    try {
      if (!file.existsSync()) {
        file.createSync();
        file.writeAsStringSync(Config.defaultCodeServerVersion);
      }
    } catch (e) {
      Log.e('创建文件失败 -> $e');
    }
    if (file.existsSync()) version = file.readAsStringSync();
    if (version.isEmpty) {
      version = Config.defaultCodeServerVersion;
    }
    terminal.writeProgress('创建PTY终端实例...');
    pseudoTerminal = createPTY();
    updateProgress(1);
    terminal.writeProgress('定义需要使用的函数...');
    // Uint8List bytesFunctions = utf8.encode(startVsCodeScript);
    // pseudoTerminal!.write(bytesFunctions);
    await pseudoTerminal!.defineFunction(startVsCodeScript);
    updateProgress(2);
    terminal.writeProgress('当前VS Code Server版本:$version...');
    // Directory('$prootDistroPath/dlcache').createSync(recursive: true);

    terminal.writeProgress('拷贝 proot-distro 到数据目录...');
    // proot-distro to launch ubuntu
    await AssetsUtils.copyAssetToPath(
      'assets/proot-distro.zip',
      '${RuntimeEnvir.homePath}/proot-distro.zip',
    );
    updateProgress(3);
    terminal.writeProgress('拷贝 ubuntu 到数据目录...');
    await AssetsUtils.copyAssetToPath(
      'assets/${Config.ubuntu}',
      '${RuntimeEnvir.homePath}/${Config.ubuntu}',
    );
    updateProgress(4);
    terminal.writeProgress('创建 Busybox 符号链接...');
    createBusyboxLink();
    updateProgress(5);
    vsCodeStartWhenSuccessBind();
    terminal.writeProgress('拷贝 code-server 到数据目录...');
    await AssetsUtils.copyAssetToPath(
      'assets/code-server-${Config.defaultCodeServerVersion}-linux-arm64.tar.gz',
      '${RuntimeEnvir.tmpPath}/code-server-${Config.defaultCodeServerVersion}-linux-arm64.tar.gz',
    );
    updateProgress(6);
    startVsCode(pseudoTerminal!);
  }

  Future<void> startVsCode(Pty pseudoTerminal) async {
    vsCodeStaring = true;
    update();
    pseudoTerminal.writeString('start_vs_code\n');
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
      syncProgress();
      createPtyTerm();
    });
  }
}
