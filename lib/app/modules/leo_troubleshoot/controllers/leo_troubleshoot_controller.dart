import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/leo_firmware_update_dialog.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LeoTroubleshootController extends GetxController {
  final isResetting = false.obs;
  final isUpdating = false.obs;

  Future<void> resetLeo() async {
    try {
      isResetting.value = true;
      final success = await BleScanService.sendCommand("reboot");
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
      isUpdating.value = true;
      
      // Get OTA controller first
      final otaController = Get.put(LeoOtaController());
      
      // Check if OTA is already in progress - if so, just show progress dialog
      if (otaController.isOtaInProgress.value ||
          otaController.isDownloadingFirmware.value ||
          otaController.isOtaProgressDialogOpen.value) {
        // OTA is already in progress, just show the progress dialog
        final context = Get.context;
        if (context != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const LeoFirmwareUpdateDialog(),
          );
        }
        return;
      }
      
      // Show file picker only if OTA is not in progress
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['bin'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        
        // Double-check OTA is still not in progress (in case it started while picking file)
        if (otaController.isOtaInProgress.value ||
            otaController.isDownloadingFirmware.value) {
          // OTA started while picking file, just show progress dialog
          final context = Get.context;
          if (context != null) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const LeoFirmwareUpdateDialog(),
            );
          }
          return;
        }
        
        // Get context from Get
        final context = Get.context;
        if (context != null) {
          // Show progress dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const LeoFirmwareUpdateDialog(),
          );
          
          // Start OTA update
          await otaController.startOtaUpdate(filePath);
        }
      }
    } catch (e) {
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'Failed to start OTA update: $e',
      );
    } finally {
      isUpdating.value = false;
    }
  }
}
