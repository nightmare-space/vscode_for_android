import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';
import 'package:vscode_for_android/terminal_page.dart';
//FIXME: import 'behavior.dart';


Future<void> main() async {
  RuntimeEnvir.initEnvirWithPackageName('com.nightmare.code');
  await initSettingStore(RuntimeEnvir.configPath);

  runApp(const MyApp());
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  //FIXME: initApi('Code FA', Config.versionName);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Code FA',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: TerminalPage(),
      ),
    );
  }
}
