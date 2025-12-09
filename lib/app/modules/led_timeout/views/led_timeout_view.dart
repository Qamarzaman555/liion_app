import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/widgets/custom_switch.dart';
import '../controllers/led_timeout_controller.dart';

class LedTimeoutView extends GetView<LedTimeoutController> {
  const LedTimeoutView({super.key});

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
          'LED Timeout',
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
                SvgAssets.ledTimeBtnIcon,
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
              'LED Timeout',
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Configure how long the LED indicator should remain active before automatically turning off.',
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
                            'Enable LED Timeout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF282828),
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Automatically turn off LED after timeout',
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
                        value: controller.isEnabled.value,
                        onChanged: (value) {
                          controller.toggleLedTimeout(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Obx(
              () => controller.isEnabled.value
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Timeout Duration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF282828),
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...controller.timeoutOptions.map(
                          (minutes) => Obx(
                            () => _buildTimeoutOption(
                              minutes: minutes,
                              isSelected: controller.timeoutMinutes.value == minutes,
                              onTap: () => controller.updateTimeout(minutes),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutOption({
    required int minutes,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: isSelected
          ? AppColors.primaryColor.withOpacity(0.1)
          : AppColors.cardBGColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? AppColors.primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          minutes == 1
              ? '$minutes minute'
              : minutes < 60
                  ? '$minutes minutes'
                  : '${minutes ~/ 60} hour${minutes == 60 ? '' : 's'}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.primaryColor
                : const Color(0xFF282828),
            fontFamily: 'Inter',
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: AppColors.primaryColor,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}



