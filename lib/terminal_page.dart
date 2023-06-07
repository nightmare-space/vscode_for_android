import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:path/path.dart' as path;
import 'package:settings/settings.dart';
import 'package:vscode_for_android/utils/extension.dart';
import 'package:xterm/xterm.dart';
import 'config.dart';
import 'http_handler.dart';
import 'io.dart';
import 'terminal_controller.dart';
import 'utils/plugin_util.dart';
import 'script.dart';
import 'utils/pty_util.dart';
import 'utils/zip_util.dart';
import 'xterm_wrapper.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  HomeController controller = Get.put(HomeController());
  Pty? pseudoTerminal;
  bool vsCodeStaring = false;

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
        file.writeAsStringSync('4.13.0');
      }
    } catch (e) {
      // 在小米平板6上会有异常，无法创建文件，怀疑是和Android系统有关
    }
    if (file.existsSync()) version = file.readAsStringSync();
    if (version.isEmpty) {
      version = '4.13.0';
    }
    Directory(RuntimeEnvir.binPath!).createSync(recursive: true);
    String dioPath = '${RuntimeEnvir.binPath}/dart_dio';
    File(dioPath).writeAsStringSync(Config.dioScript);
    await exec('chmod +x $dioPath');
    if (Platform.isAndroid) {
      if (!hasBash()) {
        initTerminal();
        return;
      }
    }
    // proot-distro 用来安装ubuntu
    await AssetsUtils.copyAssetToPath(
      'assets/proot-distro.zip',
      '${RuntimeEnvir.homePath}/proot-distro.zip',
    );
    // ubuntu资源包
    await AssetsUtils.copyAssetToPath(
      'assets/ubuntu-aarch64-pd-v3.0.1.tar.xz',
      '$prootDistroPath/dlcache/ubuntu-aarch64-pd-v3.0.1.tar.xz',
    );
    pseudoTerminal = createPTY();
    await pseudoTerminal?.defineFunction(startVsCodeScript);
    setState(() {});
    vsCodeStartWhenSuccessBind();
    await controller.unzipVSCodeIfNotExist();
    startVsCode(pseudoTerminal!);
  }

  Future<void> startVsCode(Pty pseudoTerminal) async {
    vsCodeStaring = true;
    setState(() {});
    pseudoTerminal.writeString('''start_vs_code\n''');
  }

  /// 监听输出，当输出中包含vscode启动成功的标志时，启动vscode
  Future<void> vsCodeStartWhenSuccessBind() async {
    // WebView.platform = SurfaceAndroidWebView();
    final Completer completer = Completer();
    pseudoTerminal!.output.cast<List<int>>().transform(const Utf8Decoder(allowMalformed: true)).listen((event) async {
      final List<String> list = event.split(RegExp('\x0d|\x0a'));
      final String lastLine = list.last.trim();
      if (lastLine.startsWith(RegExp('dart_dio'))) {
        String data = event.replaceAll(RegExp('dart_dio.*'), '');
        controller.terminal.write(data);
        HttpHandler.handDownload(
          controller: controller.terminal,
          cmdLine: list.last,
        );
        return;
      }
      if (event.contains('http://0.0.0.0:10000')) {
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

      controller.terminal.write(event);
      // event.split('').forEach((element) {
      //   terminal.write(event);
      // });
    });
    await completer.future;
    await Future.delayed(const Duration(milliseconds: 100));
    // 用url_launcher打开浏览器
    PluginUtil.openWebView();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 2000), () {
      vsCodeStaring = false;
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [],
      );
      setState(() {});
    });
  }

  Future<void> initTerminal() async {
    pseudoTerminal = createPTY(shell: '/system/bin/sh');
    vsCodeStartWhenSuccessBind();
    await pseudoTerminal!.defineFunction(initShell);
    setState(() {});
    controller.terminal.write(getRedLog('\r\n- 解压资源中...\r\n'));
    // 创建相关文件夹
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory(RuntimeEnvir.homePath).createSync(recursive: true);
    Directory('$prootDistroPath/dlcache').createSync(recursive: true);

    await AssetsUtils.copyAssetToPath(
      'assets/bootstrap-aarch64.zip',
      '${RuntimeEnvir.tmpPath}/bootstrap-aarch64.zip',
    );
    await AssetsUtils.copyAssetToPath(
      'assets/proot-distro.zip',
      '${RuntimeEnvir.homePath}/proot-distro.zip',
    );
    await AssetsUtils.copyAssetToPath(
      'assets/ubuntu-aarch64-pd-v3.0.1.tar.xz',
      '$prootDistroPath/dlcache/ubuntu-aarch64-pd-v3.0.1.tar.xz',
    );
    await ZipUtil.unzipBootstrap('${RuntimeEnvir.tmpPath}/bootstrap-aarch64.zip', onFile: (String name) {
      controller.terminal.write('\x1b[2K\r- ${path.basename(name)}.');
      // terminal.write('\x1b7\x1b[2K\x1b[B\x1b[2Kx1b[B\x1b[2K\r- $name.\x1b8');
    });
    controller.terminal.write('\r\n');
    await controller.unzipVSCodeIfNotExist();
    pseudoTerminal!.writeString('initApp\n');
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      SettingNode settingNode = 'privacy'.setting;
      if (settingNode.get() == null) {
        await Get.to(PrivacyAgreePage(
          onAgreeTap: () {
            settingNode.set(true);
            Navigator.of(context).pop();
          },
        ));
      }
      createPtyTerm();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (pseudoTerminal == null) {
      return const SizedBox();
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          pseudoTerminal!.writeString('\x03');
          return true;
        },
        child: Stack(
          children: [
            if (pseudoTerminal != null)
              SafeArea(
                child: XTermWrapper(
                  terminal: controller.terminal,
                  pseudoTerminal: pseudoTerminal,
                ),
              ),
            Center(
              child: Material(
                color: const Color(0xfff3f4f9),
                borderRadius: BorderRadius.circular(12.w),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    PluginUtil.openWebView();
                  },
                  child: SizedBox(
                    height: 48.w,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (vsCodeStaring)
                            SpinKitDualRing(
                              color: Theme.of(context).primaryColor,
                              size: 18.w,
                              lineWidth: 2.w,
                            ),
                          if (vsCodeStaring)
                            const SizedBox(
                              width: 8,
                            ),
                          Text(
                            vsCodeStaring ? 'VS Code 启动中...' : '打开VS Code窗口',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontSize: 16.w,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
