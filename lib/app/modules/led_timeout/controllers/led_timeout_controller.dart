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
  }

  // @override
  // void onClose() {
  //   timeoutTextController.dispose();
  //   super.onClose();
  // }

  Future<void> updateTimeoutFromInput() async {
    if (formKey.currentState?.validate() != true) return;
    final parsed = int.tryParse(timeoutTextController.text) ?? 0;
    timeoutSeconds.value = parsed;
    print('parsed: $parsed');
    final sent = await BleScanService.sendCommand(
      'app_msg led_time_before_dim $parsed',
    );
    if (!sent) {
      print('Failed to send LED timeout command');
      return;
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await BleScanService.sendCommand('py_msg');
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
