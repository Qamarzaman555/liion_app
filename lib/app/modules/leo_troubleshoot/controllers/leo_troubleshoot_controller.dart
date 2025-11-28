import 'package:get/get.dart';
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
        Get.snackbar(
          'Success',
          'Leo device reset command sent',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to send reset command. Please ensure device is connected.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        snackPosition: SnackPosition.BOTTOM,
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
        Get.snackbar(
          'Error',
          'Could not open FAQ page',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> updateFromFile() async {
    // TODO: Implement OTA update functionality
    // This would require the OTA package and related controllers
    Get.snackbar(
      'Info',
      'OTA update functionality coming soon',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
