import 'dart:io' show Platform;
import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/services/ios_ble_scan_service.dart';

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

    // Refresh the latest states from the service
    if (Platform.isAndroid) {
      BleScanService.requestAdvancedModes();
    } else if (Platform.isIOS) {
      IOSBleScanService.requestAdvancedModes();
    }
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

    final success = Platform.isAndroid
        ? await BleScanService.setGhostMode(value)
        : await IOSBleScanService.setGhostMode(value);
    ghostModeEnabled.value = value;

    AppSnackbars.showSuccess(
      title: success ? "Ghost Mode Updated" : "Update Failed",
      message: success
          ? "Ghost Mode has been updated to ${value ? "Enabled" : "Disabled"}"
          : "Could not update Ghost Mode. Please try again.",
    );
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

    final success = Platform.isAndroid
        ? await BleScanService.setSilentMode(value)
        : await IOSBleScanService.setSilentMode(value);
    silentModeEnabled.value = value;

    AppSnackbars.showSuccess(
      title: success ? "Silent Mode Updated" : "Update Failed",
      message: success
          ? "Silent Mode has been updated to ${value ? "Enabled" : "Disabled"}"
          : "Could not update Silent Mode. Please try again.",
    );
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

    final success = Platform.isAndroid
        ? await BleScanService.setHigherChargeLimit(value)
        : await IOSBleScanService.setHigherChargeLimit(value);
    higherChargeLimitEnabled.value = value;

    AppSnackbars.showSuccess(
      title: success ? "Higher Charge Limit Updated" : "Update Failed",
      message: success
          ? "Higher Charge Limit has been updated to ${value ? "Enabled" : "Disabled"}"
          : "Could not update Higher Charge Limit. Please try again.",
    );
  }
}
