import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

extension PTYExt on Pty {
  void writeString(String data) {
    write(Uint8List.fromList(utf8.encode(data)));
  }
}
