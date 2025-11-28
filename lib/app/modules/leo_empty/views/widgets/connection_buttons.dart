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
  });

  final LeoHomeController controller;
  final VoidCallback onConnectionButtonPressed;

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
                ? 'Connected'
                : controller.connectionState.value ==
                      BleConnectionState.connecting
                ? 'Connecting...'
                : 'Disconnected',

            onPressed: onConnectionButtonPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  controller.connectionState.value ==
                          BleConnectionState.connected
                      ? 'Connected'
                      : controller.connectionState.value ==
                            BleConnectionState.connecting
                      ? 'Connecting...'
                      : 'Disconnected',
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
        CustomButton(
          backgroundColor: AppColors.primaryInvertColor,
          text: "Leo is up-to-date",

          onPressed: onConnectionButtonPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Leo is up-to-date",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
