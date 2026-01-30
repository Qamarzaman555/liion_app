import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class AdvancedSettingsController extends GetxController {
  final ghostModeEnabled = false.obs;
  final silentModeEnabled = false.obs;
  final higherChargeLimitEnabled = false.obs;
  final LeoHomeController _leoHomeController = Get.find<LeoHomeController>();

  @override
  void onInit() {
    super.onInit();

    ghostModeEnabled.value = _leoHomeController.advancedGhostModeEnabled.value;
    silentModeEnabled.value =
        _leoHomeController.advancedSilentModeEnabled.value;
    higherChargeLimitEnabled.value =
        _leoHomeController.advancedHigherChargeLimitEnabled.value;

    // Refresh the latest states from the foreground service.
    BleScanService.requestAdvancedModes();
  }

  Future<void> requestAdvancedGhostMode(bool value) async {
    if (_leoHomeController.connectionState.value !=
        BleConnectionState.connected) {
      AppSnackbars.showSuccess(
        title: "No Device Connected",
        message: "Please connect to a device to update Ghost Mode",
      );
      return;
    }

    await BleScanService.setGhostMode(value);
    ghostModeEnabled.value = value;
  }

  Future<void> requestAdvancedSilentMode(bool value) async {
    if (_leoHomeController.connectionState.value !=
        BleConnectionState.connected) {
      AppSnackbars.showSuccess(
        title: "No Device Connected",
        message: "Please connect to a device to update Silent Mode",
      );
      return;
    }

    await BleScanService.setSilentMode(value);
    silentModeEnabled.value = value;
  }

  Future<void> requestAdvancedHigherChargeLimit(bool value) async {
    if (_leoHomeController.connectionState.value !=
        BleConnectionState.connected) {
      AppSnackbars.showSuccess(
        title: "No Device Connected",
        message: "Please connect to a device to update Higher Charge Limit",
      );
      return;
    }

    await BleScanService.setHigherChargeLimit(value);
    higherChargeLimitEnabled.value = value;
  }
}
