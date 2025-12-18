import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class LedTimeoutController extends GetxController {
  /// Stores the timeout value in seconds. Defaults to 300 (5 minutes).
  final timeoutSeconds = 300.obs;

  /// Form and text controller for validating user input.
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController timeoutTextController;
  @override
  void onInit() {
    super.onInit();
    timeoutTextController = TextEditingController(
      text: timeoutSeconds.value.toString(),
    );
    _loadInitialTimeout();
  }

  @override
  void onClose() {
    timeoutTextController.dispose();
    super.onClose();
  }

  Future<void> _loadInitialTimeout() async {
    // LED timeout feature is only supported on Android
    if (Platform.isAndroid) {
      await _setValueFromService();
    }
  }

  Future<bool> refreshTimeout() async {
    // LED timeout feature is only supported on Android
    if (!Platform.isAndroid) {
      return false;
    }
    
    final requested = await BleScanService.requestLedTimeout();
    if (!requested) return false;
    // Allow service to process and cache the value
    await Future.delayed(const Duration(milliseconds: 200));
    await _setValueFromService();
    return true;
  }

  Future<bool> updateTimeoutFromInput() async {
    if (formKey.currentState?.validate() != true) return false;
    final parsed = int.tryParse(timeoutTextController.text) ?? 0;
    return setTimeout(parsed);
  }

  Future<bool> setTimeout(int seconds) async {
    // LED timeout feature is only supported on Android
    if (!Platform.isAndroid) {
      return false;
    }
    
    timeoutSeconds.value = seconds;
    timeoutTextController.text = seconds.toString();
    final sent = await BleScanService.setLedTimeout(seconds);
    if (!sent) {
      print('Failed to send LED timeout command');
      return false;
    }
    return true;
  }

  Future<void> _setValueFromService() async {
    // LED timeout feature is only supported on Android
    if (!Platform.isAndroid) {
      return;
    }
    
    final cached = await BleScanService.getLedTimeout();
    timeoutSeconds.value = cached;
    timeoutTextController.text = cached.toString();
  }

  String? validateTimeout(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Time value can\'t be empty';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Invalid number';
    }
    if (parsed < 0 || parsed > 99999) {
      return 'Time must be between 0 and 99999 seconds';
    }
    return null;
  }
}
