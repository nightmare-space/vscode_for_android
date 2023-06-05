import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
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
import 'utils/plugin_util.dart';
import 'script.dart';
import 'xterm_wrapper.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  // 环境变量
  late Map<String, String> envir;
  Pty? pseudoTerminal;
  bool vsCodeStaring = false;
  Terminal terminal = Terminal();

  // 是否存在bash文件
  bool hasBash() {
    final File bashFile = File('${RuntimeEnvir.binPath}/bash');
    final bool exist = bashFile.existsSync();
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
    Directory(RuntimeEnvir.binPath!).createSync(
      recursive: true,
    );
    String dioPath = '${RuntimeEnvir.binPath}/dart_dio';
    File(dioPath).writeAsStringSync(Config.dioScript);
    await exec('chmod +x $dioPath');
    if (Platform.isAndroid) {
      if (!hasBash()) {
        // 初始化后 bash 应该存在
        initTerminal();
        return;
      }
    }
    await AssetsUtils.copyAssetToPath(
      'assets/proot-distro.zip',
      '${RuntimeEnvir.homePath}/proot-distro.zip',
    );
    await AssetsUtils.copyAssetToPath(
      'assets/ubuntu-aarch64-pd-v3.0.1.tar.xz',
      '$prootDistroPath/dlcache/ubuntu-aarch64-pd-v3.0.1.tar.xz',
    );
    // try {
    //   String ubuntuVersion =
    //       File('$prootDistroPath/installed-rootfs/ubuntu/etc/issue')
    //           .readAsStringSync();
    //   if(ubuntuVersion.contains('21.04')){
    //     await Ub
    //   }
    // } catch (e) {}
    pseudoTerminal = Pty.start(
      '${RuntimeEnvir.binPath}/bash',
      arguments: [],
      environment: envir,
      workingDirectory: RuntimeEnvir.homePath,
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      pseudoTerminal!.writeString(startVsCodeScript);
      startVsCode(pseudoTerminal!);
    });
    setState(() {});
    vsCodeStartWhenSuccessBind();
  }

  Future<void> startVsCode(Pty pseudoTerminal) async {
    vsCodeStaring = true;
    setState(() {});
    pseudoTerminal.writeString('''start_vs_code\n''');
    // pseudoTerminal
    //     .writeString('''cd $prootDistroPath/installed-rootfs/ubuntu\n''');
  }

  Future<void> vsCodeStartWhenSuccessBind() async {
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
      if (event.contains('http://0.0.0.0:10000')) {
        Log.e(event);
        if (!completer.isCompleted) {
          completer.complete();
          await AssetsUtils.copyAssetToPath(
            'assets/Alipay.png',
            '$ubuntuPath/root/捐赠二维码-支付宝.png',
          );
          await AssetsUtils.copyAssetToPath(
            'assets/Alipay.png',
            '$ubuntuPath/root/捐赠二维码-微信.png',
          );
          File('$ubuntuPath/root/捐赠说明.md').writeAsStringSync(
            'Code FA 是免费并且开源的项目，花费了我不少的业余时间，如果你觉得这个软件有帮到你，可以为作者打钱充电，我会有更多开发时的动力~',
          );
          await AssetsUtils.copyAssetToPath(
            'assets/Alipay.png',
            '$ubuntuPath/home/捐赠二维码-支付宝.png',
          );
          await AssetsUtils.copyAssetToPath(
            'assets/Alipay.png',
            '$ubuntuPath/home/捐赠二维码-微信.png',
          );
          File('$ubuntuPath/home/捐赠说明.md').writeAsStringSync(
            'Code FA 是免费并且开源的项目，花费了我不少的业余时间，如果你觉得这个软件有帮到你，可以为作者打钱充电，我会有更多开发时的动力~',
          );
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
    pseudoTerminal = Pty.start(
      '/system/bin/sh',
      arguments: [],
      environment: envir,
      workingDirectory: RuntimeEnvir.homePath,
    );

    vsCodeStartWhenSuccessBind();
    await Future.delayed(const Duration(milliseconds: 300));
    pseudoTerminal!.defineFunction(initShell);
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 100));
    terminal.write(getRedLog('- 解压资源中...\r\n'));
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
    await unzipBootstrap('${RuntimeEnvir.tmpPath}/bootstrap-aarch64.zip');
    await extractTarGz(
      readBinaryFileAsStream('/sdcard/code-server-$version-linux-arm64.tar.gz'),
      RuntimeEnvir.homePath,
      (data) {
        terminal.write('$data\r\n');
      },
    );
    pseudoTerminal!.writeString('initApp\n');
  }

  Stream<List<int>> readBinaryFileAsStream(String file) {
    print('Reading binary file $file.');
    var contents = File(file).openRead();
    return contents;
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
      final String filePath = '${RuntimeEnvir.usrPath}/$filename';
      // Log.d(path);
      terminal.write('\x1b[2K\r - ${path.basename(filePath)}');
      // terminal.write('\x1b[2K\r');

      if (file.isFile) {
        final data = file.content as List<int>;
        await File(filePath).create(recursive: true);
        await File(filePath).writeAsBytes(data);
      } else {
        Directory(filePath).create(recursive: true);
      }
      count++;
      // Log.d('total -> $total count -> $count');
      setState(() {});
    }
    terminal.write('\r\n');
    File(modulePath).delete();
    setState(() {});
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
    return WillPopScope(
      onWillPop: () async {
        pseudoTerminal!.writeString('\x03');
        return true;
      },
      child: Stack(
        children: [
          if (pseudoTerminal != null)
            SafeArea(
              child: XTermWrapper(
                terminal: terminal,
                pseudoTerminal: pseudoTerminal!,
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

extension PTYExt on Pty {
  Future<void> defineFunction(String function) async {
    print('define func');
    Directory(RuntimeEnvir.tmpPath).createSync(recursive: true);
    Directory dir = Directory(RuntimeEnvir.tmpPath).createTempSync();
    File('${dir.path}/shell').writeAsStringSync(function);
    // 删除这个文件夹
    // pty.write(Uint8List.fromList(Utf8Encoder().convert('chmod +x ${dir.path}/shell\n')));
    write(Uint8List.fromList(Utf8Encoder().convert('source ${dir.path}/shell\n')));
    Future.delayed(Duration(seconds: 1), () {
      dir.delete(recursive: true);
    });
    // 等待1s
    await Future.delayed(Duration(seconds: 1));
    // source完成后删除源文件
  }
}
