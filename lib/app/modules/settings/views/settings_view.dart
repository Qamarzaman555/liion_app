import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 40, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: Color(0xFF282828),
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              _customSettingButton(
                text: "FAQ",
                icon: Icons.question_answer_outlined,
                onPressed: () => controller.openFaq(),
              ),
              const SizedBox(height: 12),
              _customSettingButton(
                text: "Feedback",
                icon: Icons.message_outlined,
                onPressed: () => Get.toNamed(AppRoutes.feedbackView),
              ),

              const SizedBox(height: 12),

              _customSettingButton(
                text: "Manual",
                iconPath: SvgAssets.leoManualIcon,
                onPressed: () => Get.toNamed(AppRoutes.leoManual),
              ),
              const SizedBox(height: 12),

              _customSettingButton(
                text: "Leo Troubleshoot",
                icon: Icons.troubleshoot_outlined,
                onPressed: () => Get.toNamed(AppRoutes.leoTroubleshoot),
              ),

              const SizedBox(height: 12),

              _customSettingButton(
                text: "Update Leo",
                icon: Icons.repeat_rounded,
                onPressed: () {},
              ),

              const SizedBox(height: 12),

              _customSettingButton(
                text: "Advanced Settings",
                icon: Icons.settings,
                onPressed: () => Get.toNamed(AppRoutes.advanceSettings),
              ),
              // const SizedBox(height: 12),
              // const SizedBox(height: 8),
              // _buildSettingsTile(
              //   icon: Icons.battery_charging_full,
              //   title: 'Set Charge Limit',
              //   subtitle: 'Configure maximum charge percentage',
              //   onTap: () => Get.toNamed(AppRoutes.setChargeLimitView),
              // ),

              // const SizedBox(height: 24),

              // // Advanced Section
              // const Text(
              //   'Advanced',
              //   style: TextStyle(
              //     fontSize: 14,
              //     fontWeight: FontWeight.w600,
              //     color: Color(0xFF888888),
              //   ),
              // ),
              // const SizedBox(height: 8),
              // _buildSettingsTile(
              //   icon: Icons.settings_applications,
              //   title: 'Advanced Settings',
              //   subtitle: 'Configure advanced options',
              //   onTap: () => Get.toNamed(AppRoutes.advanceSettings),
              // ),
              // _buildSettingsTile(
              //   icon: Icons.build_circle_outlined,
              //   title: 'Troubleshoot',
              //   subtitle: 'Diagnose and fix issues',
              //   onTap: () => Get.toNamed(AppRoutes.leoTroubleshoot),
              // ),

              // const SizedBox(height: 24),

              // // Support Section
              // const Text(
              //   'Support',
              //   style: TextStyle(
              //     fontSize: 14,
              //     fontWeight: FontWeight.w600,
              //     color: Color(0xFF888888),
              //   ),
              // ),
              // const SizedBox(height: 8),
              // _buildSettingsTile(
              //   icon: Icons.feedback_outlined,
              //   title: 'Feedback',
              //   subtitle: 'Send us your feedback',
              //   onTap: () => Get.toNamed(AppRoutes.feedbackView),
              // ),
              // _buildSettingsTile(
              //   icon: Icons.info_outline,
              //   title: 'About',
              //   subtitle: 'App version and information',
              //   onTap: () => Get.toNamed(AppRoutes.aboutView),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  CustomButton _customSettingButton({
    required String text,
    String? iconPath,
    IconData? icon,
    required VoidCallback onPressed,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,

      borderRadius: 10,
      backgroundColor: AppColors.primaryColor,
      textColor: AppColors.whiteColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.whiteColor,
            ),
          ),
          if (iconPath != null)
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              color: AppColors.whiteColor,
            ),
          if (icon != null) Icon(icon, color: AppColors.whiteColor, size: 24),
        ],
      ),
    );
  }
}
