import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:global_repository/global_repository.dart';
import 'package:path/path.dart' as p;

class DownloadBootPage extends StatefulWidget {
  @override
  _DownloadBootPageState createState() => _DownloadBootPageState();
}

class _DownloadBootPageState extends State<DownloadBootPage> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(child: _DownloadFile()),
    );
  }
}

class _DownloadFile extends StatefulWidget {
  const _DownloadFile({Key key, this.callback}) : super(key: key);
  final void Function() callback;
  @override
  _DownloadFileState createState() => _DownloadFileState();
}

class _DownloadFileState extends State<_DownloadFile> {
  final Dio dio = Dio();
  Response<String> response;
  final String filesPath = RuntimeEnvir.usrPath;
  List<String> androidAdbFiles = [
    'https://nightmare-my.oss-cn-beijing.aliyuncs.com/Termare/bootstrap-aarch64.zip',
  ];
  String cur;
  double fileDownratio = 0.0;
  String title = '';
  Future<void> downloadFile(String urlPath) async {
    print(urlPath);
    response = await dio.head<String>(urlPath);
    final int fullByte = int.tryParse(
      response.headers.value('content-length').toString(),
    ); //得到服务器文件返回的字节大小
    // final String _human = getFileSize(_fullByte); //拿到可读的文件大小返回给用户
    print('fullByte======$fullByte ${p.basename(urlPath)}');
    final String savePath = filesPath + '/' + p.basename(urlPath);
    // print(savePath);
    await dio.download(
      urlPath,
      savePath,
      onReceiveProgress: (count, total) {
        final double process = count / total;
        fileDownratio = process;
        setState(() {});
        // );
      },
    );
    final ProcessResult result = Process.runSync(
      'chmod',
      <String>[
        '0777',
        savePath,
      ],
      environment: RuntimeEnvir.envir(),
    );
    Log.e(result.stderr);
    Log.d(result.stdout);
    await installModule(savePath);
  }

  Future<void> installModule(String modulePath) async {
    title = '解压中...';
    setState(() {});
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
      cur = path;
      print(path);
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
      fileDownratio = count / total;
      print('total -> $total count -> $count');
      setState(() {});
    }
    File(modulePath).delete();
    title = '配置中...';
    fileDownratio = null;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    execDownload();
  }

  Future<void> execDownload() async {
    List<String> needDownloadFile;
    if (Platform.isAndroid) {
      needDownloadFile = androidAdbFiles;
    }
    for (final String urlPath in needDownloadFile) {
      title = '下载 ${p.basename(urlPath)} 中...';
      setState(() {});
      await downloadFile(urlPath);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '进度',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(25.0)),
              child: LinearProgressIndicator(
                value: fileDownratio,
              ),
            ),
            const SizedBox(height: 4),
            if (cur != null)
              SizedBox(
                child: Text(
                  '当前处理文件 $cur',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      onWillPop: () async {
        showToast('等待下载完成后');
        return false;
      },
    );
  }
}
