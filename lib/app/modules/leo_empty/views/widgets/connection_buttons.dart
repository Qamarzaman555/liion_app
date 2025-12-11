import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

import '../../controllers/leo_home_controller.dart';

class LeoConnectionButtons extends StatelessWidget {
  const LeoConnectionButtons({
    super.key,
    required this.controller,
    required this.onConnectionButtonPressed,
    required this.onFirmwareUpdateButtonPressed,
  });

  final LeoHomeController controller;
  final VoidCallback onConnectionButtonPressed;
  final VoidCallback onFirmwareUpdateButtonPressed;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => CustomButton(
            backgroundColor:
                controller.connectionState.value == BleConnectionState.connected
                ? AppColors.primaryInvertColor
                : AppColors.primaryColor,
            text:
                controller.connectionState.value == BleConnectionState.connected
                ? 'Leo is Connected'
                : controller.connectionState.value ==
                      BleConnectionState.connecting
                ? 'Connecting...'
                : 'Connect Leo',

            onPressed: onConnectionButtonPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  controller.connectionState.value ==
                          BleConnectionState.connected
                      ? 'Leo is Connected'
                      : controller.connectionState.value ==
                            BleConnectionState.connecting
                      ? 'Connecting...'
                      : 'Connect Leo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final statusText = _firmwareStatusText();
          return CustomButton(
            backgroundColor: AppColors.primaryInvertColor,
            text: statusText,
            onPressed: onFirmwareUpdateButtonPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.whiteColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _firmwareStatusText() {
    if (controller.isFirmwareDownloading.value) {
      return 'Checking updates...';
    }

    final cloudVersion = controller.cloudBinFileName.value.trim();
    final leoVersion = controller.binFileFromLeoName.value.trim();

    if (cloudVersion.isEmpty || leoVersion.isEmpty) {
      return 'Checking updates...';
    }

    return cloudVersion == leoVersion ? 'Leo is up-to-date' : 'Update Leo';
  }
}
