import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class AboutController extends GetxController {
  final appName = ''.obs;
  final packageName = ''.obs;
  final version = ''.obs;
  final buildNumber = ''.obs;
  final isConnected = false.obs;
  final leoFirmwareVersion = ''.obs;

  @override
  void onInit() {
    super.onInit();
    getAppDetails();
    checkConnectionStatus();
  }

  Future<void> getAppDetails() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appName.value = packageInfo.appName;
      packageName.value = packageInfo.packageName;
      version.value = packageInfo.version;
      buildNumber.value = packageInfo.buildNumber;
    } catch (e) {
      print('Error getting app details: $e');
    }
  }

  Future<void> checkConnectionStatus() async {
    try {
      final connected = await BleScanService.isConnected();
      isConnected.value = connected;

      if (connected) {
        // Try to get firmware version by sending a command
        // Note: This would need to be implemented based on your Leo device protocol
        // For now, we'll leave it empty or you can implement the command to get firmware
        leoFirmwareVersion.value =
            ''; // TODO: Implement firmware version retrieval
      }
    } catch (e) {
      print('Error checking connection: $e');
    }
  }
}
