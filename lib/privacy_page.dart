import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:global_repository/global_repository.dart';
import 'package:settings/settings.dart';

class PrivacyAgreePage extends StatefulWidget {
  const PrivacyAgreePage({Key key}) : super(key: key);

  @override
  State<PrivacyAgreePage> createState() => _PrivacyAgreePageState();
}

class _PrivacyAgreePageState extends State<PrivacyAgreePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Expanded(child: PrivacyPage()),
          Row(
            children: [
              Expanded(
                child: GestureWithScale(
                  onTap: () {
                    SystemNavigator.pop();
                  },
                  child: Container(
                    height: 48.w,
                    color: const Color(0xffe8e9ee),
                    child: Center(
                      child: Text(
                        '我不同意',
                        style: TextStyle(
                          fontSize: 16.w,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureWithScale(
                  onTap: () {
                    'privacy'.set = true;
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    color: Theme.of(context).primaryColor,
                    height: 48.w,
                    child: Center(
                      child: Text(
                        '同意继续',
                        style: TextStyle(
                          fontSize: 16.w,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({Key key}) : super(key: key);

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  String data;
  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/privacy_policy.md').then((value) {
      data = value;
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Markdown(
          controller: ScrollController(),
          selectable: true,
          data: data ?? 'Insert emoji here😀 ',
        ),
      ),
    );
  }
}
