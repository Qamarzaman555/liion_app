import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import 'package:liion_app/app/modules/advanced_settings/controllers/advanced_settings_controller.dart';
import 'package:liion_app/app/modules/advanced_settings/utils/dialog_helper.dart';

class AdvancedGhostMode extends StatelessWidget {
  const AdvancedGhostMode({super.key, required this.controller});
  final AdvancedSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: 'Ghost Mode Beta',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Ghost Mode Beta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
          Obx(
            () => SvgPicture.asset(
              controller.ghostModeEnabled.value
                  ? SvgAssets.fastChargeIconFilled
                  : SvgAssets.fastChargeIcon,
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
      onPressed: () {
        DialogHelper.showConfirmationDialog(
          context,
          title: "100W Ghost Mode (Beta)",
          middleTextWidget: const Text.rich(
            TextSpan(
              text: '',
              children: [
                TextSpan(
                  text:
                      "This feature allows Leo to charge up to 100W charging speeds.\n\n",
                ),
                TextSpan(
                  text: "Important Notes:\n\n",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF282828),
                  ),
                ),
                TextSpan(
                  text:
                      "• To achieve 100W charging, your charger, cables, and device must all support this speed. Leo cannot increase the charging speed beyond the capability of your existing setup.\n\n",
                ),
                TextSpan(
                  text:
                      "• With this feature enabled, Leo will restart multiple times when switching to Ghost Mode. This behavior is expected and required for proper operation.\n",
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF282828),
            ),
          ),
          customSwitch: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () => CustomSwitch(
                    value: controller.ghostModeEnabled.value,
                    onChanged: (value) {
                      controller.requestAdvancedGhostMode(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
