import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_colors.dart';

class AppSnackbars {
  const AppSnackbars._();

  static void showSuccess({required String title, required String message}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.secondaryColor.withOpacity(0.3),
      colorText: Colors.black,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.only(bottom: 6),
    );
  }
}
