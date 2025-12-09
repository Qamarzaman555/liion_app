import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/modules/advanced_settings/views/widgets/advance_settings_header.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import '../controllers/advanced_settings_controller.dart';

class AdvancedSettingsView extends GetView<AdvancedSettingsController> {
  const AdvancedSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final leoController = Get.find<LeoHomeController>();

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

            Obx(() {
              final enabled = leoController.advancedGhostModeEnabled.value;
              return buildCustomButton(
                text: 'Ghost Mode Beta',
                iconPath: enabled
                    ? SvgAssets.fastChargeIconFilled
                    : SvgAssets.fastChargeIcon,
                onPressed: () {
                  Get.toNamed(AppRoutes.ghostModeBeta);
                },
              );
            }),
            const SizedBox(height: 12),
            Obx(() {
              final enabled = leoController.advancedSilentModeEnabled.value;
              return buildCustomButton(
                text: 'Silent Mode',
                iconPath: enabled
                    ? SvgAssets.silentModeIconFilled
                    : SvgAssets.silentModeIcon,
                onPressed: () {
                  Get.toNamed(AppRoutes.silentMode);
                },
              );
            }),
            const SizedBox(height: 12),
            Obx(() {
              final enabled =
                  leoController.advancedHigherChargeLimitEnabled.value;
              return buildCustomButton(
                text: 'Higher Charge Limit',
                iconPath: enabled
                    ? SvgAssets.higherChargeIconFilled
                    : SvgAssets.higherChargeIcon,
                onPressed: () {
                  Get.toNamed(AppRoutes.higherChargeLimit);
                },
              );
            }),
            const SizedBox(height: 12),
            buildCustomButton(
              text: 'LED Timeout',
              iconPath: SvgAssets.ledTimeBtnIcon,
              onPressed: () {
                Get.toNamed(AppRoutes.ledTimeout);
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget buildCustomButton({
    required String text,
    required String iconPath,
    required VoidCallback onPressed,
  }) {
    return CustomButton(
      text: text,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
          SvgPicture.asset(iconPath, width: 24, height: 24),
        ],
      ),
      onPressed: () {
        onPressed();
      },
    );
  }
}
