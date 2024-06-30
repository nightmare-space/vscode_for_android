import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:vscode_for_android/utils/extension.dart';
import 'terminal_controller.dart';
import 'utils/plugin_util.dart';
import 'xterm_wrapper.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({Key? key}) : super(key: key);

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  HomeController controller = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(builder: (controller) {
      if (controller.pseudoTerminal == null) {
        return const SizedBox();
      }
      return Scaffold(
        backgroundColor: Colors.black,
        body: PopScope(
          onPopInvoked: (didpop) {
            controller.pseudoTerminal!.writeString('\x03');
          },
          canPop: true,
          child: Stack(
            children: [
              if (controller.pseudoTerminal != null)
                SafeArea(
                  child: XTermWrapper(
                    terminal: controller.terminal,
                    pseudoTerminal: controller.pseudoTerminal,
                  ),
                ),
              if (controller.webviewHasOpen)
                Center(
                  child: Material(
                    color: const Color(0xfff3f4f9),
                    borderRadius: BorderRadius.circular(12.w),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        PluginUtil.openWebView();
                      },
                      child: SizedBox(
                        height: 48.w,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.vsCodeStaring)
                                SpinKitDualRing(
                                  color: Theme.of(context).primaryColor,
                                  size: 18.w,
                                  lineWidth: 2.w,
                                ),
                              if (controller.vsCodeStaring)
                                const SizedBox(
                                  width: 8,
                                ),
                              Text(
                                controller.vsCodeStaring ? 'VS Code 启动中...' : '回到VS Code窗口',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontSize: 16.w,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
