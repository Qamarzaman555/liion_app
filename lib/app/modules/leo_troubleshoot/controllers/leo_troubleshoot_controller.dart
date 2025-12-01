import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
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
    // TODO: Implement OTA update functionality
    // This would require the OTA package and related controllers
    AppSnackbars.showSuccess(
      title: 'Info',
      message: 'OTA update functionality coming soon',
    );
  }
}
