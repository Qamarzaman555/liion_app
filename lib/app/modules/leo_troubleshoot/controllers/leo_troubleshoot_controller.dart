import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/leo_firmware_update_dialog.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/wait_for_install_dialog.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/services/ios_ble_scan_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LeoTroubleshootController extends GetxController {
  final isResetting = false.obs;
  final isUpdating = false.obs;

  Future<void> resetLeo() async {
    try {
      isResetting.value = true;
      final success = Platform.isAndroid
          ? await BleScanService.sendCommand("reboot")
          : await IOSBleScanService.sendCommand("reboot");
      if (success) {
        AppSnackbars.showSuccess(
          title: 'Success',
          message: 'Leo device reset command sent',
        );
      } else {
        AppSnackbars.showSuccess(
          title: 'Error',
          message:
              'Failed to send reset command. Please ensure device is connected.',
        );
      }
    } catch (e) {
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'An error occurred: $e',
      );
    } finally {
      isResetting.value = false;
    }
  }

  Future<void> openFaq() async {
    try {
      const url = 'https://liionpower.tech/pages/faq';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AppSnackbars.showSuccess(
          title: 'Error',
          message: 'Could not open FAQ page',
        );
      }
    } catch (e) {
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'An error occurred: $e',
      );
    }
  }

  Future<void> updateFromFile() async {
    try {
      print('🔵 [Troubleshoot] updateFromFile called');
      isUpdating.value = true;

      // Get OTA controller first
      final otaController = Get.put(LeoOtaController());

      // If the post-OTA install timer is still running, show the timer dialog instead
      // Check both timer active state and if seconds are remaining (timer might be active but dialog dismissed)
      if (otaController.isInstallTimerActive ||
          otaController.isTimerDialogOpen.value ||
          (otaController.wasOtaCompleted &&
              otaController.secondsRemaining.value > 0)) {
        print('🟡 [Troubleshoot] Timer is active - showing wait dialog');
        final context = Get.context;
        if (context != null) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) => const WaitForInstallDialogBox(),
          );
        }
        return;
      }

      // Check if OTA is already in progress - if so, just show progress dialog
      if (otaController.isOtaInProgress.value ||
          otaController.isDownloadingFirmware.value ||
          otaController.isOtaProgressDialogOpen.value) {
        print(
          '🟡 [Troubleshoot] OTA already in progress - showing existing progress dialog',
        );
        print(
          '🟡 [Troubleshoot] isOtaInProgress: ${otaController.isOtaInProgress.value}, progress: ${otaController.otaProgress.value}',
        );
        // OTA is already in progress, just show the progress dialog
        final context = Get.context;
        if (context != null) {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) =>
                const LeoFirmwareUpdateDialog(autoDownloadFromCloud: false),
          );
        }
        return;
      }

      // Show file picker only if OTA is not in progress
      print('🔵 [Troubleshoot] Showing file picker');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        print('🔵 [Troubleshoot] File selected: $filePath');

        // Double-check OTA is still not in progress (in case it started while picking file)
        if (otaController.isOtaInProgress.value ||
            otaController.isDownloadingFirmware.value ||
            otaController.isOtaProgressDialogOpen.value) {
          // OTA started while picking file, just show progress dialog
          print(
            '🟡 [Troubleshoot] OTA started while picking file - showing existing progress dialog',
          );
          final context = Get.context;
          if (context != null) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (_) =>
                  const LeoFirmwareUpdateDialog(autoDownloadFromCloud: false),
            );
          }
          return;
        }

        // Get context from Get
        final context = Get.context;
        if (context != null) {
          // Show progress dialog
          print('🔵 [Troubleshoot] Starting new OTA - showing progress dialog');
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (_) =>
                const LeoFirmwareUpdateDialog(autoDownloadFromCloud: false),
          );

          // Start OTA update
          await otaController.startOtaUpdate(filePath);
        }
      } else {
        print('🔵 [Troubleshoot] No file selected');
      }
    } catch (e) {
      print('🔴 [Troubleshoot] Error: $e');
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'Failed to start OTA update: $e',
      );
    } finally {
      isUpdating.value = false;
    }
  }
}
