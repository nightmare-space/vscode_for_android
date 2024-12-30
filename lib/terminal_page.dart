import 'package:code_lfa/utils/pty_util.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:xterm/xterm.dart';
import 'terminal_controller.dart';
import 'xterm_theme.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  HomeController controller = Get.put(HomeController());
  bool visible = false;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(builder: (controller) {
      if (controller.pseudoTerminal == null) {
        return const SizedBox();
      }
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: PopScope(
          // FIXME:
          onPopInvoked: (didpop) {
            controller.pseudoTerminal!.writeString('\x03');
          },
          canPop: true,
          child: GestureDetector(
            onTap: () {
              visible = !visible;
              setState(() {});
            },
            behavior: HitTestBehavior.translucent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Visibility(
                  visible: visible,
                  // IgnorePointer
                  child: AbsorbPointer(
                    child: TerminalView(
                      controller.terminal,
                      readOnly: false,
                      backgroundOpacity: 0,
                      theme: macTheme,
                    ),
                  ),
                ),
                Center(
                  child: Material(
                    borderRadius: BorderRadius.circular(12.w),
                    // color: Theme.of(context).colorScheme.surfaceContainer,
                    child: SizedBox(
                      width: 300.w,
                      height: 60.w,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: LoadingProgress(
                              minRadius: 6,
                              strokeWidth: 3,
                              increaseRadius: 3,
                            ),
                          ),
                          SizedBox(height: 12.w),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w),
                            child: Stack(
                              children: [
                                Container(
                                  height: 5.w,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(3.w),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: 300.milliseconds,
                                  height: 5.w,
                                  width: 300.w * controller.progress,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(3.w),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
