import 'package:flutter/services.dart';

class PluginUtil {
  static void openWebView() {
    MethodChannel channel = const MethodChannel('vscode_channel');
    channel.invokeMethod('open_webview');
  }

  static Future<String> getLibPath() async {
    MethodChannel channel = const MethodChannel('vscode_channel');
    return await channel.invokeMethod('lib_path');
  }
}
