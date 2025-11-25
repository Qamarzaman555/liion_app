import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/advanced_settings_controller.dart';

class AdvancedSettingsView extends GetView<AdvancedSettingsController> {
  const AdvancedSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Advanced Settings View'),
      ),
    );
  }
}

