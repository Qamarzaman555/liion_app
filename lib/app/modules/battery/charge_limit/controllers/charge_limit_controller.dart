import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/services/ios_ble_scan_service.dart';

class ChargeLimitController extends GetxController {
  final chargeLimit = 90.obs;
  final chargeLimitEnabled = false.obs;
  final chargeLimitConfirmed = false.obs;
  final isConnected = false.obs;

  final TextEditingController limitTextController = TextEditingController();
  final sliderValue = 0.0.obs;
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
    // Get charge limit info based on platform
    if (Platform.isIOS) {
      final info = await IOSBleScanService.getChargeLimitInfo();
      chargeLimit.value = info['limit'] as int? ?? 90;
      chargeLimitEnabled.value = info['enabled'] as bool? ?? false;
      chargeLimitConfirmed.value = info['confirmed'] as bool? ?? false;
      limitTextController.text = chargeLimit.value.toString();
      sliderValue.value = chargeLimit.value.toDouble();
      
      final connected = await IOSBleScanService.isConnected();
      isConnected.value = connected;
    } else {
      final info = await BleScanService.getChargeLimit();
      chargeLimit.value = info.limit;
      chargeLimitEnabled.value = info.enabled;
      chargeLimitConfirmed.value = info.confirmed;
      limitTextController.text = info.limit.toString();
      sliderValue.value = info.limit.toDouble();

      final connectionState = await BleScanService.getConnectionState();
      isConnected.value = connectionState == BleConnectionState.connected;
    }
  }

  void _listenToChargeLimitUpdates() {
    // iOS: Charge limit updates are handled via direct state management
    // Android: Use stream subscription
    if (Platform.isAndroid) {
      _chargeLimitSubscription = BleScanService.chargeLimitStream.listen((info) {
        chargeLimit.value = info.limit;
        chargeLimitEnabled.value = info.enabled;
        chargeLimitConfirmed.value = info.confirmed;
      });
    }
    // For iOS: charge limit state is managed locally and persisted in native layer
  }

  void _listenToConnectionUpdates() {
    if (Platform.isIOS) {
      _connectionSubscription = IOSBleScanService.getConnectionStream().listen((event) {
        final state = event['state'] as int;
        isConnected.value = state == 2; // 2 = connected
      });
    } else {
      _connectionSubscription = BleScanService.connectionStream.listen((event) {
        final state = event['state'] as int;
        isConnected.value = state == BleConnectionState.connected;
      });
    }
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

  void updateSlider(double value) {
    final clampedValue = value.clamp(0, 100).toDouble();
    sliderValue.value = clampedValue;
    limitTextController.text = clampedValue.toInt().toString();
  }

  void updateFromText(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) return;
    sliderValue.value = parsed.clamp(0, 100).toDouble();
  }

  Future<bool> saveChargeLimit() async {
    if (!formKey.currentState!.validate()) {
      return false;
    }

    final limit = int.parse(limitTextController.text);
    final success = Platform.isIOS
        ? await IOSBleScanService.setChargeLimit(limit, true)
        : await BleScanService.setChargeLimit(limit, true);

    if (success) {
      chargeLimit.value = limit;
      chargeLimitEnabled.value = true;
      AppSnackbars.showSuccess(
        title: 'Success',
        message: 'Charge limit set to $limit%',
      );
    } else {
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'Failed to set charge limit',
      );
    }

    return success;
  }

  Future<void> toggleChargeLimit(bool enabled) async {
    final success = Platform.isIOS
        ? await IOSBleScanService.setChargeLimitEnabled(enabled)
        : await BleScanService.setChargeLimitEnabled(enabled);
    if (success) {
      chargeLimitEnabled.value = enabled;
      AppSnackbars.showSuccess(
        title: enabled ? 'Charge Limit Enabled' : 'Charge Limit Disabled',
        message: enabled
            ? 'Limit set to ${chargeLimit.value}%'
            : 'Leo will use default charge limit',
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
