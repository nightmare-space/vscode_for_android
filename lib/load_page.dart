import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:global_repository/global_repository.dart';
import 'package:vscode_for_android/script.dart';
import 'package:vscode_for_android/terminal_page.dart';

class LoadPage extends StatefulWidget {
  const LoadPage({Key ?key}) : super(key: key);

  @override
  State<LoadPage> createState() => _LoadPageState();
}

class _LoadPageState extends State<LoadPage> {
  TextEditingController controller = TextEditingController()..text = '4.9.1';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '输入加载的版本号',
            style: TextStyle(color: Colors.white, fontSize: 16.w),
          ),
          TextField(
            controller: controller,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration: InputDecoration(
              fillColor: Colors.grey.shade900,
              filled: true,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  version = controller.text;
                  setState(() {});
                  Get.to(const TerminalPage());
                },
                child: const Text('启动Code FA'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
