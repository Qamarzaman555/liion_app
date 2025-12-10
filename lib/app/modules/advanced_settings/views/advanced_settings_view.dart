import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/modules/advanced_settings/views/widgets/100W_%20ghost_mode_view.dart';
import 'package:liion_app/app/modules/advanced_settings/views/widgets/advance_higher_charge_mode_view.dart';
import 'package:liion_app/app/modules/advanced_settings/views/widgets/advance_settings_header.dart';
import 'package:liion_app/app/modules/advanced_settings/views/widgets/advanced_silent_mode_view.dart';
import 'package:liion_app/app/modules/advanced_settings/views/widgets/led_timeout_view.dart';
import 'package:liion_app/app/modules/led_timeout/controllers/led_timeout_controller.dart';
import '../controllers/advanced_settings_controller.dart';

class AdvancedSettingsView extends GetView<AdvancedSettingsController> {
  const AdvancedSettingsView({super.key});

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const AdvanceSettingsHeader(),
            const SizedBox(height: 20),

            AdvancedGhostMode(controller: controller),

            const SizedBox(height: 12),
            AdvancedSilentModeView(controller: controller),

            const SizedBox(height: 12),
            AdvanceHigherChargeModeView(controller: controller),

            const SizedBox(height: 12),

            LedTimeoutView(controller: Get.find<LedTimeoutController>()),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
