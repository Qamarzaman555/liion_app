import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class SetChargeLimitController extends GetxController {
  final chargeLimit = 90.obs;
  final chargeLimitEnabled = false.obs;
  final chargeLimitConfirmed = false.obs;
  final isConnected = false.obs;

  final TextEditingController limitTextController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  StreamSubscription? _chargeLimitSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadInitialState();
    _listenToChargeLimitUpdates();
    _listenToConnectionUpdates();
  }

  Future<void> _loadInitialState() async {
    final info = await BleScanService.getChargeLimit();
    chargeLimit.value = info.limit;
    chargeLimitEnabled.value = info.enabled;
    chargeLimitConfirmed.value = info.confirmed;
    limitTextController.text = info.limit.toString();

    final connectionState = await BleScanService.getConnectionState();
    isConnected.value = connectionState == BleConnectionState.connected;
  }

  void _listenToChargeLimitUpdates() {
    _chargeLimitSubscription = BleScanService.chargeLimitStream.listen((info) {
      chargeLimit.value = info.limit;
      chargeLimitEnabled.value = info.enabled;
      chargeLimitConfirmed.value = info.confirmed;
    });
  }

  void _listenToConnectionUpdates() {
    _connectionSubscription = BleScanService.connectionStream.listen((event) {
      final state = event['state'] as int;
      isConnected.value = state == BleConnectionState.connected;
    });
  }

  String? validateLimit(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a charge limit';
    }
    final limit = int.tryParse(value);
    if (limit == null) {
      return 'Please enter a valid number';
    }
    if (limit < 0 || limit > 100) {
      return 'Limit must be between 0 and 100';
    }
    return null;
  }

  Future<bool> saveChargeLimit() async {
    if (!formKey.currentState!.validate()) {
      return false;
    }

    final limit = int.parse(limitTextController.text);
    final success = await BleScanService.setChargeLimit(limit, true);

    if (success) {
      chargeLimit.value = limit;
      chargeLimitEnabled.value = true;
      Get.snackbar(
        'Success',
        'Charge limit set to $limit%',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        'Error',
        'Failed to set charge limit',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }

    return success;
  }

  /// Toggle charge limit on/off - saves to SharedPrefs and sends command immediately
  /// When enabled: sends the saved charge limit value
  /// When disabled: sends 0 (no limit)
  Future<void> toggleChargeLimit(bool enabled) async {
    final success = await BleScanService.setChargeLimitEnabled(enabled);
    if (success) {
      chargeLimitEnabled.value = enabled;
      Get.snackbar(
        enabled ? 'Charge Limit Enabled' : 'Charge Limit Disabled',
        enabled
            ? 'Limit set to ${chargeLimit.value}%'
            : 'Charging will continue to 100%',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: enabled ? Colors.green : Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  void onClose() {
    _chargeLimitSubscription?.cancel();
    _connectionSubscription?.cancel();
    limitTextController.dispose();
    super.onClose();
  }
}
