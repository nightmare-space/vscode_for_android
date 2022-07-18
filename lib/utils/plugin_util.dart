import 'package:flutter/services.dart';

class PlauginUtil {
  static void openWebView() {
    MethodChannel channel = const MethodChannel('vscode_channel');
    channel.invokeMethod('');
  }
}
