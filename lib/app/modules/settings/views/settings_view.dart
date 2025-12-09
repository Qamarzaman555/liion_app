import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

              CustomButton(
                text: "Manual",
                onPressed: () {
                  Get.toNamed(AppRoutes.leoManual);
                },
              ),
              const SizedBox(height: 12),

              CustomButton(
                text: "Leo Troubleshoot",
                onPressed: () {
                  Get.toNamed(AppRoutes.leoTroubleshoot);
                },
              ),
              const SizedBox(height: 12),

              CustomButton(
                text: "Feedback",
                onPressed: () {
                  Get.toNamed(AppRoutes.feedbackView);
                },
              ),
              const SizedBox(height: 12),

              CustomButton(
                text: "About",
                onPressed: () {
                  Get.toNamed(AppRoutes.aboutView);
                },
              ),

              const SizedBox(height: 12),

              CustomButton(
                text: "Advanced Settings",
                onPressed: () {
                  Get.toNamed(AppRoutes.advanceSettings);
                },
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

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.cardBGColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF282828),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF888888)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
