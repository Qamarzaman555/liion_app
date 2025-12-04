import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/leo_firmware_update_dialog.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

import '../controllers/leo_home_controller.dart';
import 'widgets/bluetooth_connection_dialog.dart';
import 'widgets/connection_buttons.dart';
import 'widgets/metrics_summary.dart';

class LeoHomeView extends GetView<LeoHomeController> {
  const LeoHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: AppBar(
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          flexibleSpace: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(50, 50, 50, 0),
              child: Image.asset(
                PngAssets.leoMainLogo,
                height: 60,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LeoConnectionButtons(
                  controller: controller,
                  onConnectionButtonPressed: () =>
                      _handleConnectionButtonTap(context),
                  onFirmwareUpdateButtonPressed: () =>
                      _showFirmwareUpdateDialog(context),
                ),
                const SizedBox(height: 20),
                LeoMetricsSummary(controller: controller),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleConnectionButtonTap(BuildContext context) {
    if (!controller.isBluetoothOn) {
      BleScanService.requestEnableBluetooth();
      return;
    }

    _showDeviceSelectionDialog(context);
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const BluetoothConnectionDialog(),
    );
  }

  void _showFirmwareUpdateDialog(BuildContext context) async {
    // Get OTA controller
    final otaController = Get.put(LeoOtaController());

    // Check if OTA is already in progress
    if (otaController.isOtaInProgress.value ||
        otaController.isDownloadingFirmware.value ||
        otaController.isOtaProgressDialogOpen.value) {
      // OTA is already in progress, just show the progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LeoFirmwareUpdateDialog(),
      );
      return;
    }

    // Show folder name input dialog for cloud download
    final TextEditingController folderController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Firmware'),
        content: TextField(
          controller: folderController,
          decoration: const InputDecoration(
            labelText: 'Firebase Storage Folder Name',
            hintText: 'e.g., firmware/leo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (folderController.text.isNotEmpty) {
                Navigator.pop(context, folderController.text);
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LeoFirmwareUpdateDialog(),
      );

      // Download firmware and start OTA
      await otaController.downloadFolder(result);
      if (otaController.cloudBinFilePath.value.isNotEmpty) {
        await otaController.startOtaUpdate(
          otaController.cloudBinFilePath.value,
        );
      }
    }
  }
}
