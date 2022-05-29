import 'package:flutter/services.dart';

class PlauginUtil {
  static void openWebView() {
    MethodChannel channel = MethodChannel('vscode_channel');
    channel.invokeMethod('');
  }
}
