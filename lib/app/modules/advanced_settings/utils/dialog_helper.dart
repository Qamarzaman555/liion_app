import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class DialogHelper {
  static void showConfirmationDialog(
    BuildContext context, {
    String? title,
    Widget? middleTextWidget,
    Widget? customSwitch,
  }) {
    Get.defaultDialog(
      title: title ?? '',
      titlePadding: const EdgeInsets.only(top: 20, bottom: 10),
      titleStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.only(left: 20, right: 20),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.of(context).size.height * 0.6, // Constrain height
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (middleTextWidget != null) middleTextWidget,
              if (customSwitch != null) customSwitch,
            ],
          ),
        ),
      ),
    );
  }

  static void showLedTimeoutDialog(
    BuildContext context, {
    int? initialValue,
    ValueChanged<int>? onSubmit,
  }) {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: initialValue?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        actionsPadding: const EdgeInsets.only(top: 0, bottom: 12, right: 16),
        title: const Text(
          'LED Timeout',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Time in seconds before LEDs switch off. (Safe mode will always show LEDs)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: InputDecoration(
                      hintText: 'Enter value between 0-99999',
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Time value can\'t be empty';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null) {
                        return 'Invalid time value';
                      }
                      if (parsed < 0 || parsed > 99999) {
                        return 'Time must be between 0 and 99999 seconds';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              final parsed = int.tryParse(controller.text.trim()) ?? 0;
              onSubmit?.call(parsed);
              final sent = await BleScanService.sendCommand(
                'app_msg led_time_before_dim $parsed',
              );
              if (!sent) {
                AppSnackbars.showSuccess(
                  title: 'Update Failed',
                  message: 'Could not send command. Please try again.',
                );
                return;
              }
              await Future.delayed(const Duration(milliseconds: 200));
              await BleScanService.sendCommand('app_msg led_time_before_dim');
              await Future.delayed(const Duration(milliseconds: 200));
              await BleScanService.sendCommand('py_msg');
              AppSnackbars.showSuccess(
                title: 'LED Timeout Updated',
                message: 'LED Timeout has been updated to $parsed seconds',
              );
              Navigator.pop(context);
            },
            child: const Text(
              'Set',
              style: TextStyle(color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }
}
