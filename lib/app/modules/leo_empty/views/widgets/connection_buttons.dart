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
            height: 70,
            backgroundColor: controller.connectionState.value ==
                    BleConnectionState.connected
                ? AppColors.primaryColor
                : AppColors.primaryInvertColor,
            text: controller.connectionState.value ==
                    BleConnectionState.connected
                ? 'Connected'
                : controller.connectionState.value ==
                        BleConnectionState.connecting
                    ? 'Connecting...'
                    : 'Disconnected',
            onPressed: onConnectionButtonPressed,
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => CustomButton(
            height: 70,
            backgroundColor: controller.connectionState.value ==
                    BleConnectionState.disconnected
                ? AppColors.primaryColor
                : AppColors.primaryInvertColor,
            text: controller.connectionState.value ==
                    BleConnectionState.connected
                ? 'Leo is up-to-date'
                : 'Update Leo',
            onPressed: () {
              if (!controller.isBluetoothOn) {
                BleScanService.requestEnableBluetooth();
                return;
              }

              if (controller.connectionState.value ==
                  BleConnectionState.connected) {
                controller.disconnectDevice();
              } else if (controller.scannedDevices.isNotEmpty) {
                controller.connectToDevice(
                  controller.scannedDevices.first['address'] ?? '',
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

