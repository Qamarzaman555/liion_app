import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
// import 'package:liion_app/app/modules/leo_empty/views/widgets/update_leo_text.dart';
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
          return Column(
            children: [
              CustomButton(
                backgroundColor:
                    controller.firmwareVersionStatusText.value ==
                            "Leo is up-to-date" ||
                        controller.connectionState.value !=
                            BleConnectionState.connected ||
                        controller.cloudBinFileName.value.isEmpty
                    ? AppColors.primaryInvertColor
                    : AppColors.primaryColor,
                text:
                    controller.connectionState.value !=
                            BleConnectionState.connected ||
                        controller.cloudBinFileName.value.isEmpty
                    ? 'Leo is up-to-date'
                    : controller.firmwareVersionStatusText.value,
                onPressed: onFirmwareUpdateButtonPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.connectionState.value !=
                                  BleConnectionState.connected ||
                              controller.cloudBinFileName.value.isEmpty
                          ? 'Leo is up-to-date'
                          : controller.firmwareVersionStatusText.value,
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
        }),
      ],
    );
  }
}
