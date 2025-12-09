import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import '../controllers/silent_mode_controller.dart';

class SilentModeView extends GetView<SilentModeController> {
  const SilentModeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.blackColor),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Silent Mode',
          style: TextStyle(
            color: AppColors.blackColor,
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: SvgPicture.asset(
                SvgAssets.silentModeIcon,
                width: 80,
                height: 80,
                colorFilter: const ColorFilter.mode(
                  AppColors.primaryColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Silent Mode',
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Configure silent mode settings to reduce notifications and minimize interruptions during charging.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 0,
              color: AppColors.cardBGColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Silent Mode',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF282828),
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Reduce notifications and alerts',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                      () => CustomSwitch(
                        value: controller.advancedSilentModeEnabled.value,
                        onChanged: (value) {
                          controller.toggleSilentMode(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

