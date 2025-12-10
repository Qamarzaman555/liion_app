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

    try {
      ghostModeEnabled.value = value;
      // 1) Send desired state to Leo.
      final sent = await BleScanService.sendCommand(
        'app_msg ghost_mode ${value ? "1" : "0"}',
      );
      if (!sent) {
        throw Exception('Failed to send command');
      }

      // 2) Let device process before querying to avoid BLE write collisions.
      await Future.delayed(const Duration(milliseconds: 300));

      // 3) Query current ghost mode state.
      await _leoHomeController.requestAdvancedGhostMode();

      // 4) Give a moment, then flush.
      await Future.delayed(const Duration(milliseconds: 300));
      await BleScanService.sendCommand('py_msg');

      AppSnackbars.showSuccess(
        title: "Ghost Mode Updated",
        message:
            "Ghost Mode has been updated to ${value ? "Enabled" : "Disabled"}",
      );
    } catch (_) {
      AppSnackbars.showSuccess(
        title: "Update Failed",
        message: "Could not update Ghost Mode. Please try again.",
      );
    }
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

    try {
      silentModeEnabled.value = value;
      // 1) Send desired state to Leo.
      final sent = await BleScanService.sendCommand(
        'app_msg quiet_mode ${value ? "1" : "0"}',
      );
      if (!sent) {
        throw Exception('Failed to send command');
      }

      // 2) Let device process before querying to avoid BLE write collisions.
      await Future.delayed(const Duration(milliseconds: 300));

      // 3) Query current silent mode state.
      await _leoHomeController.requestAdvancedSilentMode();

      // 4) Give a moment, then flush.
      await Future.delayed(const Duration(milliseconds: 300));
      await BleScanService.sendCommand('py_msg');

      AppSnackbars.showSuccess(
        title: "Silent Mode Updated",
        message:
            "Silent Mode has been updated to ${value ? "Enabled" : "Disabled"}",
      );
    } catch (_) {
      AppSnackbars.showSuccess(
        title: "Update Failed",
        message: "Could not update Silent Mode. Please try again.",
      );
    }
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

    try {
      higherChargeLimitEnabled.value = value;
      // 1) Send desired state to Leo.
      final sent = await BleScanService.sendCommand(
        'app_msg charge_limit ${value ? "1" : "0"}',
      );
      if (!sent) {
        throw Exception('Failed to send command');
      }

      // 2) Let device process before querying to avoid BLE write collisions.
      await Future.delayed(const Duration(milliseconds: 300));

      // 3) Query current higher charge limit state.
      await _leoHomeController.requestAdvancedHigherChargeLimit();

      // 4) Give a moment, then flush.
      await Future.delayed(const Duration(milliseconds: 300));
      await BleScanService.sendCommand('py_msg');

      AppSnackbars.showSuccess(
        title: "Higher Charge Limit Updated",
        message:
            "Higher Charge Limit has been updated to ${value ? "Enabled" : "Disabled"}",
      );
    } catch (_) {
      AppSnackbars.showSuccess(
        title: "Update Failed",
        message: "Could not update Higher Charge Limit. Please try again.",
      );
    }
  }
}
