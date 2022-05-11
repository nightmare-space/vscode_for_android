import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:global_repository/global_repository.dart';
import 'package:pty/pty.dart';
import 'package:xterm/next.dart';
import 'plugin_util.dart';
import 'script.dart';
import 'xterm_wrapper.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key key}) : super(key: key);

  @override
  _TerminalPageState createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  Map<String, String> envir;
  PseudoTerminal pseudoTerminal;
  bool vsCodeStaring = false;
  Terminal terminal = Terminal();
  bool hasBash() {
    final File bashFile = File(RuntimeEnvir.binPath + '/bash');
    final bool exist = bashFile.existsSync();
    return exist;
  }

  bool currentVSExist() {
    final File codeServer = File(
        '$prootDistroPath/installed-rootfs/ubuntu/home/code-server-$version-linux-arm64/code-server');
    final bool exist = codeServer.existsSync();
    return exist;
  }

  Future<void> createPtyTerm() async {
    if (Platform.isAndroid) {
      await PermissionUtil.requestStorage();
    }
    envir = Map.from(Platform.environment);
    envir['HOME'] = RuntimeEnvir.homePath;
    envir['TERMUX_PREFIX'] = RuntimeEnvir.usrPath;
    envir['TERM'] = 'xterm-256color';
    envir['PATH'] = RuntimeEnvir.path;
    if (File('${RuntimeEnvir.usrPath}/lib/libtermux-exec.so').existsSync()) {
      envir['LD_PRELOAD'] = '${RuntimeEnvir.usrPath}/lib/libtermux-exec.so';
    }
    if (Platform.isAndroid) {
      if (!hasBash()) {
        // 初始化后 bash 应该存在
        initTerminal();
        return;
      }
      // if (!currentVSExist()) {
      //   // 升级策略
      //   await copyVSCodeAsset();
      // }
    }
    pseudoTerminal = PseudoTerminal.start(
      RuntimeEnvir.binPath + '/bash',
      [],
      blocking: false,
      environment: envir,
      workingDirectory: RuntimeEnvir.homePath,
    )..init();
    Future.delayed(const Duration(milliseconds: 300), () {
      pseudoTerminal.write(startVsCodeScript);
      startVsCode(pseudoTerminal);
    });
    setState(() {});
    vsCodeStartWhenSuccessBind();
  }

  Future<void> startVsCode(PseudoTerminal pseudoTerminal) async {
    vsCodeStaring = true;
    setState(() {});
    pseudoTerminal.write('''start_vs_code\n''');
  }

  Future<void> vsCodeStartWhenSuccessBind() async {
    // WebView.platform = SurfaceAndroidWebView();
    final Completer completer = Completer();
    pseudoTerminal.out.asBroadcastStream().listen((event) {
      if (event.contains('http://0.0.0.0:10000')) {
        completer.complete();
      }
      if (event.contains('already')) {
        completer.complete();
      }
      event.split('').forEach((element) {
        terminal.write(element);
      });

      // Log.w('event -> $event');
    });
    await completer.future;
    PlauginUtil.openWebView();
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
    pseudoTerminal = PseudoTerminal.start(
      '/system/bin/sh',
      [],
      blocking: false,
      environment: envir,
    )..init();

    vsCodeStartWhenSuccessBind();
    await Future.delayed(Duration(milliseconds: 300));
    pseudoTerminal.write(
      initShell,
    );
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 100));
    terminal.write('${getRedLog('- 解压资源中...')}\r\n');
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory(RuntimeEnvir.homePath).createSync(recursive: true);
    await AssetsUtils.copyAssetToPath(
      'assets/bootstrap-aarch64.zip',
      RuntimeEnvir.tmpPath + '/bootstrap-aarch64.zip',
    );
    await AssetsUtils.copyAssetToPath(
      'assets/proot-distro.zip',
      RuntimeEnvir.homePath + '/proot-distro.zip',
    );
    Directory('$prootDistroPath/dlcache').createSync(
      recursive: true,
    );
    await AssetsUtils.copyAssetToPath(
      'assets/ubuntu-aarch64-pd-v2.3.1.tar.xz',
      '$prootDistroPath/dlcache/ubuntu-aarch64-pd-v2.3.1.tar.xz',
    );
    await unzipBootstrap(RuntimeEnvir.tmpPath + '/bootstrap-aarch64.zip');
    pseudoTerminal.write('initApp\n');
  }

  Future<void> unzipBootstrap(String modulePath) async {
    // Read the Zip file from disk.
    final bytes = File(modulePath).readAsBytesSync();
    // Decode the Zip file
    final archive = ZipDecoder().decodeBytes(bytes);
    // Extract the contents of the Zip archive to disk.
    final int total = archive.length;
    int count = 0;
    // print('total -> $total count -> $count');
    for (final file in archive) {
      final filename = file.name;
      final String path = '${RuntimeEnvir.usrPath}/$filename';
      Log.d(path);
      if (file.isFile) {
        final data = file.content as List<int>;
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(data);
      } else {
        Directory(path).create(
          recursive: true,
        );
      }
      count++;
      Log.d('total -> $total count -> $count');
      setState(() {});
    }
    File(modulePath).delete();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    createPtyTerm();
  }

  @override
  Widget build(BuildContext context) {
    if (pseudoTerminal == null) {
      return const SizedBox();
    }
    return WillPopScope(
      onWillPop: () async {
        pseudoTerminal.write('\x03');
        return true;
      },
      child: Stack(
        children: [
          if (pseudoTerminal != null)
            SafeArea(
              child: XTermWrapper(
                terminal: terminal,
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
                  PlauginUtil.openWebView();
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
    );
  }
}
