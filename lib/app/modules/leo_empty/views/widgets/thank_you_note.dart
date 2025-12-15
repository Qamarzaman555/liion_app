import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_texts.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';

class ThankYouNote extends StatelessWidget {
  const ThankYouNote({super.key, required this.controller});

  final LeoHomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => controller.showThankYouNote.value
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  AppTexts.firstTimeThankYouNote.trim(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
