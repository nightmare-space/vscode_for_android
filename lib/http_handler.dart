import 'dart:io';
import 'package:dio/dio.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/next.dart';

import 'config.dart';

const String dioLockFile = '/data/data/${Config.packageName}/files/dio_lock';
class HttpHandler {
  static Future<void> handDownload({
    String cmdLine,
    Terminal controller,
  }) async {
    Log.d('handDownload');
    final RegExp regExp = RegExp('dart_dio');
    // Log.d('argsStr ->$cmdLine');
    final String argsStr = cmdLine.replaceAll(regExp, '');
    if (argsStr.isEmpty) {
      print('参数为空');
      controller.write('使用方法：\n');
      controller.write('dio 下载的url 保存路径\n');
      await Process.run('rm', ['-rf', dioLockFile]);
      return;
    }
    // Log.d('argsStr ->$argsStr');
    // Log.d('argsStr ->${argsStr.isEmpty}');
    final List<String> args = argsStr.trim().split(' ');
    // Log.d('->$args .$argsStr.');
    // Log.d('->${args.isEmpty}');
    // Log.d('->${args.length}');
    // Log.d('codeUnits ->${args.first.codeUnits}');

    final String fileName = args.first.replaceAll(RegExp('.*/'), '');
    // return;
    // File file = File(dioLockFile);
    // file.writeAsStringSync('contents');

    // await NiProcess.exec(
    //   'echo >$dioLockFile\necho 下载 $fileName 中 >$dioLockFile',
    //   getStderr: true,
    // );
    Log.d('fileName->$fileName');
    await Dio().download(
      args.first,
      args.last,
      onReceiveProgress: (count, total) {
        final double process = count / total;
        final int processRadio = (process * 100).toInt();

        // radio 即 '#'的个数
        int column = controller.viewWidth - 8;
        final int radio = (process * column).toInt();
        controller.write(
          '\r\x1b[32m[${'#' * radio}${'.' * (column - radio)}] $processRadio%\x1b[0m',
        );
        if (processRadio == 100) {
          controller.write(
            '\r\n',
          );
        }
        controller.notifyListeners();
        Log.d('process->$processRadio');
      },
    );
    Log.d('下载 $fileName 结束');
    await Process.run('rm', ['-rf', dioLockFile]);
    Log.d('删除 $dioLockFile 结束');
  }
}
