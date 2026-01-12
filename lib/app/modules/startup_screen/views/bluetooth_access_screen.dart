import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_texts.dart';
import 'package:liion_app/app/modules/startup_screen/views/widgets/access_screen_widget.dart';
import 'package:liion_app/app/routes/app_routes.dart';

class BluetoothAccessScreen extends StatelessWidget {
  const BluetoothAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccessScreensWidget(
      titleText: AppTexts.btAccessTitle,
      subTitleText: AppTexts.btAccessSubTitle,
      onNextTap: () {
        Get.toNamed(AppRoutes.notificationAccessScreen);
      },
      onSkipTap: () {
        Get.toNamed(AppRoutes.notificationAccessScreen);
      },
      showBackButton: false,
    );
  }
}
