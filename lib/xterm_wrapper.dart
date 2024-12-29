import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:get/utils.dart';
import 'package:vscode_for_android/utils/extension.dart';
import 'package:xterm/xterm.dart';

class XTermWrapper extends StatefulWidget {
  const XTermWrapper({
    super.key,
    required this.terminal,
    required this.pseudoTerminal,
  });
  final Terminal? terminal;
  final Pty? pseudoTerminal;

  @override
  State<XTermWrapper> createState() => _XTermWrapperState();
}

class _XTermWrapperState extends State<XTermWrapper> {
  StreamSubscription? streamSubscription;

  @override
  void initState() {
    super.initState();
    widget.terminal!.onOutput = (data) {
      widget.pseudoTerminal!.writeString(data);
    };

    widget.terminal!.onResize = (width, height, pixelWidth, pixelHeight) {
      widget.pseudoTerminal!.resize(height, width);
    };
  }

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      widget.terminal!,
      readOnly: false,
      backgroundOpacity: 0,
      theme: macTheme,
    );
  }
}

TerminalTheme android = TerminalTheme(
  cursor: Color(0XAAAEAFAD),
  selection: Colors.primaries[3].withOpacity(0.5),
  foreground: Colors.white,
  background: Color(0XFF000000),
  black: Color(0XFF000000),
  red: Color(0XFFCD3131),
  green: Color(0XFF0DBC79),
  yellow: Color(0XFFE5E510),
  blue: Color(0XFF2472C8),
  magenta: Color(0XFFBC3FBC),
  cyan: Color(0XFF11A8CD),
  white: Color(0XFFE5E5E5),
  brightBlack: Color(0XFF666666),
  brightRed: Color(0XFFF14C4C),
  brightGreen: Color(0XFF23D18B),
  brightYellow: Color(0XFFF5F543),
  brightBlue: Color(0XFF3B8EEA),
  brightMagenta: Color(0XFFD670D6),
  brightCyan: Color(0XFF29B8DB),
  brightWhite: Color(0XFFFFFFFF),
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);
const TerminalTheme macTheme = TerminalTheme(
  cursor: Color(0xFFAEAFAD),
  selection: Color(0xFFFFFF40),
  foreground: Color(0xFF000000),
  background: Color(0xFFFFFFFF),
  black: Color(0xFF000000),
  brightBlack: Color(0xFF686868),
  red: Color(0xFFC91B00),
  brightRed: Color(0xFFFF6E64),
  green: Color(0xFF00C200),
  brightGreen: Color(0xFF5FFA68),
  yellow: Color(0xFFC7C400),
  brightYellow: Color(0xFFFFF945),
  blue: Color(0xFF0225C7),
  brightBlue: Color(0xFF6871FF),
  magenta: Color(0xFFC930C7),
  brightMagenta: Color(0xFFFF77FF),
  cyan: Color(0xFF00C5C7),
  brightCyan: Color(0xFF60FDFF),
  white: Color(0xFFC7C7C7),
  brightWhite: Color(0xFFFFFFFF),
  searchHitBackground: Color(0xFFFFFF2B),
  searchHitBackgroundCurrent: Color(0xFF31FF26),
  searchHitForeground: Color(0xFF000000),
);
TerminalTheme theme = const TerminalTheme(
  cursor: Color(0XAAAEAFAD),
  selection: Color(0XFFFFFF40),
  foreground: Color(0XFF000000),
  background: Color(0XFFFFFFFF),
  black: Color(0XFF000000),
  brightBlack: Color(0XFF666666),
  red: Color(0XFF990100),
  brightRed: Color(0XFFE60001),
  green: Color(0XFF05A600),
  brightGreen: Color(0XFF00D900),
  yellow: Color(0XFF999900),
  blue: Color(0XFF2472C8),
  magenta: Color(0XFFBC3FBC),
  cyan: Color(0XFF11A8CD),
  white: Color(0XFFE5E5E5),
  brightYellow: Color(0XFFF5F543),
  brightBlue: Color(0XFF3B8EEA),
  brightMagenta: Color(0XFFD670D6),
  brightCyan: Color(0XFF29B8DB),
  brightWhite: Color(0XFFFFFFFF),
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);

const whiteOnBlack = TerminalTheme(
  cursor: Color(0XFFAEAFAD),
  selection: Color(0XFFAEAFAD),
  foreground: Color(0XFFFFFFFF),
  background: Color(0XFF000000),
  black: Color(0XFF000000),
  red: Color(0XFFCD3131),
  green: Color(0XFF0DBC79),
  yellow: Color(0XFFE5E510),
  blue: Color(0XFF2472C8),
  magenta: Color(0XFFBC3FBC),
  cyan: Color(0XFF11A8CD),
  white: Color(0XFFE5E5E5),
  brightBlack: Color(0XFF666666),
  brightRed: Color(0XFFF14C4C),
  brightGreen: Color(0XFF23D18B),
  brightYellow: Color(0XFFF5F543),
  brightBlue: Color(0XFF3B8EEA),
  brightMagenta: Color(0XFFD670D6),
  brightCyan: Color(0XFF29B8DB),
  brightWhite: Color(0XFFFFFFFF),
  searchHitBackground: Color(0XFFFFFF2B),
  searchHitBackgroundCurrent: Color(0XFF31FF26),
  searchHitForeground: Color(0XFF000000),
);
