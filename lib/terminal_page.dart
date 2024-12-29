import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:vscode_for_android/utils/extension.dart';
import 'terminal_controller.dart';
import 'utils/plugin_util.dart';
import 'xterm_wrapper.dart';

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

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
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: PopScope(
          onPopInvoked: (didpop) {
            controller.pseudoTerminal!.writeString('\x03');
          },
          canPop: true,
          child: Stack(
            alignment: Alignment.center,
            children: [
              XTermWrapper(
                terminal: controller.terminal,
                pseudoTerminal: controller.pseudoTerminal,
              ),
              Center(
                child: Material(
                  borderRadius: BorderRadius.circular(12.w),
                  color: Theme.of(context).colorScheme.surfaceContainer,
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
                        SizedBox(height: 4.w),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Stack(
                            children: [
                              Container(
                                height: 4.w,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(5.w),
                                ),
                              ),
                              AnimatedContainer(
                                duration: 300.milliseconds,
                                height: 4.w,
                                width: 300.w * controller.progress,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(5.w),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Text(
                        //   controller.lastLine,
                        //   style: TextStyle(
                        //     color: Colors.black,
                        //     fontSize: 12.w,
                        //   ),
                        // ),
                      ],
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
