import 'dart:convert';

import 'package:flutter_pty/flutter_pty.dart';

extension PTYExt on Pty {
  void writeString(String data) {
    write(utf8.encode(data));
  }
}
