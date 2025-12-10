import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/leo_firmware_update_dialog.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

import '../controllers/leo_home_controller.dart';
import 'widgets/bluetooth_connection_dialog.dart';
import 'widgets/connection_buttons.dart';
import 'widgets/metrics_summary.dart';
import 'widgets/wait_for_install_dialog.dart';
import 'widgets/ota_done_dialog.dart';

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
        child: Stack(
          children: [
            Padding(
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
            // Listener for showing done dialog on reconnection
            _OtaDoneDialogListener(),
          ],
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
    final otaController = Get.put(LeoOtaController());

    // If the post-OTA install timer is still running, show the timer dialog.
    // Check both timer active state and if seconds are remaining (timer might be active but dialog dismissed)
    if (otaController.isInstallTimerActive ||
        otaController.isTimerDialogOpen.value ||
        (otaController.wasOtaCompleted &&
            otaController.secondsRemaining.value > 0)) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const WaitForInstallDialogBox(),
      );
      return;
    }

    // Check internet connectivity
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        AppSnackbars.showSuccess(
          title: 'No Internet Connection',
          message: 'Please check your internet connection and try again.',
        );
        return;
      }
    } catch (e) {
      AppSnackbars.showSuccess(
        title: 'No Internet Connection',
        message: 'Please check your internet connection and try again.',
      );
      return;
    }

    // Check if OTA is already in progress
    if (otaController.isOtaInProgress.value ||
        otaController.isDownloadingFirmware.value ||
        otaController.isOtaProgressDialogOpen.value) {
      // OTA is already in progress, just show the progress dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LeoFirmwareUpdateDialog(),
      );
      return;
    }

    // Show firmware update dialog immediately
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LeoFirmwareUpdateDialog(),
    );
  }
}

/// Listener widget that shows the OTA done dialog when device reconnects
/// after OTA completion, even if the wait dialog was dismissed
class _OtaDoneDialogListener extends StatefulWidget {
  @override
  State<_OtaDoneDialogListener> createState() => _OtaDoneDialogListenerState();
}

class _OtaDoneDialogListenerState extends State<_OtaDoneDialogListener> {
  bool _hasShownDialog = false;

  @override
  Widget build(BuildContext context) {
    final otaController = Get.put(LeoOtaController());

    return Obx(() {
      // If flag is set and we haven't shown the dialog yet, show it
      if (otaController.shouldShowDoneDialog.value && !_hasShownDialog) {
        print(
          'OtaDoneDialogListener: shouldShowDoneDialog is true, showing done dialog',
        );
        _hasShownDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Reset the flag
            otaController.shouldShowDoneDialog.value = false;
            // Show the done dialog
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const OTAUpdateDone(),
            ).then((_) {
              // Reset flag when dialog is closed
              _hasShownDialog = false;
            });
          }
        });
      }

      return const SizedBox.shrink();
    });
  }
}
