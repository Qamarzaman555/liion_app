import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import 'package:liion_app/app/modules/advanced_settings/controllers/advanced_settings_controller.dart';
import 'package:liion_app/app/modules/advanced_settings/utils/dialog_helper.dart';

class AdvanceHigherChargeModeView extends StatelessWidget {
  const AdvanceHigherChargeModeView({super.key, required this.controller});
  final AdvancedSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: 'Higher Charge Limit',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Higher Charge Limit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
          Obx(
            () => SvgPicture.asset(
              controller.higherChargeLimitEnabled.value
                  ? SvgAssets.higherChargeIconFilled
                  : SvgAssets.higherChargeIcon,
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
      onPressed: () {
        DialogHelper.showConfirmationDialog(
          context,
          title: "Higher Charge Limit",
          middleTextWidget: const Text.rich(
            TextSpan(
              text: '',
              children: [
                TextSpan(
                  text:
                      "This feature adjusts Leo's autonomous charge limit in Smart Mode to a higher percentage in specific cases where the default limit feels too low.\n\n",
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
                      "• For some users or devices, the default limit may feel insufficient for daily needs. Enabling this feature allows devices to charge further before stopping.\n\n",
                ),
                TextSpan(
                  text:
                      "• For older or long-unused devices with slightly degraded batteries, this feature can help prevent premature charging stops.\n",
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
                    value: controller.higherChargeLimitEnabled.value,
                    onChanged: (value) {
                      controller.requestAdvancedHigherChargeLimit(value);
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
