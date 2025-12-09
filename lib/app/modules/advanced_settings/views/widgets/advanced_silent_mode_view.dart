import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import 'package:liion_app/app/modules/advanced_settings/controllers/advanced_settings_controller.dart';
import 'package:liion_app/app/modules/advanced_settings/utils/dialog_helper.dart';

class AdvancedSilentModeView extends StatelessWidget {
  const AdvancedSilentModeView({super.key, required this.controller});
  final AdvancedSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: 'Silent Mode',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Silent Mode',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
          Obx(
            () => SvgPicture.asset(
              controller.silentModeEnabled.value
                  ? SvgAssets.silentModeIconFilled
                  : SvgAssets.silentModeIcon,
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
      onPressed: () {
        DialogHelper.showConfirmationDialog(
          context,
          title: "Silent Mode",
          middleTextWidget: const Text.rich(
            TextSpan(
              text: '',
              children: [
                TextSpan(
                  text:
                      "Activating this feature powers down Bluetooth after some time preventing unwanted noise from the Bluetooth antenna.\n\n",
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
                      "• Some people have noticed a slight ticking sound when charging, this feature reduces the ticking sound by disabling Bluetooth 3 minutes after startup.\n\n",
                ),
                TextSpan(
                  text: "• Bluetooth will be reactivated for 3 minutes by ",
                ),
                TextSpan(
                  text:
                      "pressing and holding the button on Leo for at least 1 second.\n\n",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF282828),
                  ),
                ),
                TextSpan(
                  text:
                      "• Bluetooth will remain enabled if there is an active connection with the app.\n",
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
                    value: controller.silentModeEnabled.value,
                    onChanged: (value) {
                      controller.requestAdvancedSilentMode(value);
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
