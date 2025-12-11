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
    print('🔵 [Home View] _showFirmwareUpdateDialog called');
    final otaController = Get.put(LeoOtaController());

    // If the post-OTA install timer is still running, show the timer dialog.
    // Check both timer active state and if seconds are remaining (timer might be active but dialog dismissed)
    if (otaController.isInstallTimerActive ||
        otaController.isTimerDialogOpen.value ||
        (otaController.wasOtaCompleted &&
            otaController.secondsRemaining.value > 0)) {
      print('🟡 [Home View] Timer is active - showing wait dialog');
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const WaitForInstallDialogBox(),
      );
      return;
    }

    // Check if OTA is already in progress - show existing progress dialog
    if (otaController.isOtaInProgress.value ||
        otaController.isDownloadingFirmware.value ||
        otaController.isOtaProgressDialogOpen.value) {
      print(
        '🟡 [Home View] OTA already in progress - showing existing progress dialog',
      );
      print(
        '🟡 [Home View] isOtaInProgress: ${otaController.isOtaInProgress.value}, progress: ${otaController.otaProgress.value}',
      );
      // OTA is already in progress, just show the progress dialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => const LeoFirmwareUpdateDialog(),
      );
      return;
    }

    // Check internet connectivity only if starting new OTA
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

    // Show firmware update dialog immediately
    print('🔵 [Home View] Starting new OTA - showing firmware update dialog');
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LeoFirmwareUpdateDialog(),
    );
  }
}

/// Listener widget that shows the wait dialog when timer starts
/// if progress dialog was dismissed, and shows done dialog when device reconnects
class _OtaDoneDialogListener extends StatefulWidget {
  @override
  State<_OtaDoneDialogListener> createState() => _OtaDoneDialogListenerState();
}

class _OtaDoneDialogListenerState extends State<_OtaDoneDialogListener> {
  bool _hasShownDoneDialog = false;
  bool _hasShownWaitDialog = false;

  @override
  Widget build(BuildContext context) {
    final otaController = Get.put(LeoOtaController());

    return Obx(() {
      // Reset wait dialog flag if timer is not active (timer completed or OTA reset)
      if (!otaController.isInstallTimerActive &&
          !otaController.wasOtaCompleted) {
        _hasShownWaitDialog = false;
      }

      // Check if timer started but wait dialog is not shown (progress dialog was dismissed)
      // This happens when progress reaches 100% but progress dialog was dismissed
      // Only show if progress dialog is not open (it was dismissed before reaching 100%)
      if (otaController.isTimerDialogOpen.value &&
          otaController.wasOtaCompleted &&
          otaController.isInstallTimerActive &&
          !otaController.isOtaProgressDialogOpen.value &&
          !_hasShownWaitDialog) {
        print(
          '🟡 [Done Dialog Listener] Timer started but progress dialog was dismissed - showing wait dialog',
        );
        print(
          '🟡 [Done Dialog Listener] secondsRemaining: ${otaController.secondsRemaining.value}',
        );
        _hasShownWaitDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Double-check conditions before showing (in case wait dialog was shown by progress dialog transition)
            if (otaController.isTimerDialogOpen.value &&
                !otaController.isOtaProgressDialogOpen.value &&
                otaController.isInstallTimerActive) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => const WaitForInstallDialogBox(),
              ).then((_) {
                // Reset flag when wait dialog is closed
                print('🟡 [Done Dialog Listener] Wait dialog closed');
                _hasShownWaitDialog = false;
              });
            } else {
              // Wait dialog was already shown by progress dialog transition
              print(
                '🟡 [Done Dialog Listener] Wait dialog already shown, skipping',
              );
              _hasShownWaitDialog = false;
            }
          }
        });
      }

      // Only show done dialog if:
      // 1. Flag is set
      // 2. We haven't shown it yet
      // 3. Wait dialog is NOT open (to prevent duplicate dialogs)
      //    The wait dialog will handle showing done dialog when it's open
      if (otaController.shouldShowDoneDialog.value &&
          !_hasShownDoneDialog &&
          !otaController.isTimerDialogOpen.value) {
        print(
          '🟢 [Done Dialog Listener] shouldShowDoneDialog is true, showing done dialog',
        );
        print(
          '🟢 [Done Dialog Listener] isTimerDialogOpen: ${otaController.isTimerDialogOpen.value}, secondsRemaining: ${otaController.secondsRemaining.value}',
        );
        _hasShownDoneDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Reset the flag
            otaController.shouldShowDoneDialog.value = false;
            // Show the done dialog
            print('🟢 [Done Dialog Listener] Showing done dialog');
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const OTAUpdateDone(),
            ).then((_) {
              // Reset flag when dialog is closed
              print('🟢 [Done Dialog Listener] Done dialog closed');
              _hasShownDoneDialog = false;
            });
          }
        });
      }

      return const SizedBox.shrink();
    });
  }
}
