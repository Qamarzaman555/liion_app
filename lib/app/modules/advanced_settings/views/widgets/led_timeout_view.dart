import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/modules/advanced_settings/utils/dialog_helper.dart';
import 'package:liion_app/app/modules/led_timeout/controllers/led_timeout_controller.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class LedTimeoutView extends StatelessWidget {
  const LedTimeoutView({super.key, required this.controller});
  final LedTimeoutController controller;

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: 'LED Timeout',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'LED Timeout',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
          SvgPicture.asset(SvgAssets.ledTimeBtnIcon, width: 24, height: 24),
        ],
      ),
      onPressed: () {
        if (Get.find<LeoHomeController>().connectionState.value ==
            BleConnectionState.connected) {
          DialogHelper.showLedTimeoutDialog(
            context,
            initialValue: controller.timeoutSeconds.value,
            onSubmit: (value) => controller.setTimeout(value),
          );
        } else {
          AppSnackbars.showSuccess(
            title: 'No Device Connected',
            message: 'Please connect to a device to update the LED timeout',
          );
        }
      },
    );
  }
}
