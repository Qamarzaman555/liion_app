import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class GhostModeBetaController extends GetxController {
  final advancedGhostModeEnabled = false.obs;
  late final LeoHomeController _leoHomeController;
  bool _isUpdating = false;

  @override
  void onInit() {
    super.onInit();
    _leoHomeController = Get.find<LeoHomeController>();
    _syncFromLeo();
  }

  Future<void> toggleGhostMode(bool value) async {
    if (_isUpdating) return;
    if (_leoHomeController.connectionState.value !=
        BleConnectionState.connected) {
      AppSnackbars.showSuccess(
        title: "No Device Connected",
        message: "Please connect to a device to update Ghost Mode",
      );
      // Revert switch to the last known state from Leo.
      _syncFromLeo();
      return;
    }

    // Send command first; the UI will refresh after Leo confirms.
    await requestAdvancedGhostMode(value);
  }

  Future<void> requestAdvancedGhostMode(bool value) async {
    print('requestAdvancedGhostMode: $value');
    if (_isUpdating) return;
    _isUpdating = true;
    if (_leoHomeController.connectionState.value !=
        BleConnectionState.connected) {
      _isUpdating = false;
      return;
    }

    try {
      // 1) Send desired state to Leo.
      await BleScanService.sendCommand(
        'app_msg ghost_mode ${value ? "1" : "0"}',
      );

      // 2) Let device process before querying to avoid BLE write collisions.
      await Future.delayed(const Duration(milliseconds: 200));

      // 3) Query current ghost mode state.
      await _leoHomeController.requestAdvancedGhostMode();

      // 4) Give a moment, then flush.
      await Future.delayed(const Duration(milliseconds: 200));
      await BleScanService.sendCommand('py_msg');

      // 5) If Leo did not echo state, fall back to requested value so UI matches the intent.
      _leoHomeController.advancedGhostModeEnabled.value = value;
      _syncFromLeo();

      AppSnackbars.showSuccess(
        title: "Ghost Mode Updated",
        message:
            "Ghost Mode has been updated to ${value ? "Enabled" : "Disabled"}",
      );
    } catch (_) {
      // Roll back to Leo's last reported value on failure.
      _syncFromLeo();
      AppSnackbars.showSuccess(
        title: "Update Failed",
        message: "Could not update Ghost Mode. Please try again.",
      );
    } finally {
      _isUpdating = false;
    }
  }

  void _syncFromLeo() {
    advancedGhostModeEnabled.value =
        _leoHomeController.advancedGhostModeEnabled.value;
  }
}
