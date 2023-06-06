import 'package:flutter/services.dart';

class PluginUtil {
  static void openWebView() {
    MethodChannel channel = const MethodChannel('vscode_channel');
    channel.invokeMethod('');
  }
}
