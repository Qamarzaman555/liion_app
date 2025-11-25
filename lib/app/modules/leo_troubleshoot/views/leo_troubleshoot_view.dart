import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/leo_troubleshoot_controller.dart';

class LeoTroubleshootView extends GetView<LeoTroubleshootController> {
  const LeoTroubleshootView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Leo Troubleshoot View'),
      ),
    );
  }
}

