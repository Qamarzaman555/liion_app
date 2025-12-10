import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import '../controllers/leo_troubleshoot_controller.dart';

class LeoTroubleshootView extends GetView<LeoTroubleshootController> {
  const LeoTroubleshootView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 26,
                      color: AppColors.blackColor,
                      weight: 8,
                    ),
                    onPressed: () => Get.back(),
                  ),
                  const Text(
                    'Leo Troubleshoot',
                    style: TextStyle(
                      color: Color(0xFF282828),
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Obx(
                () => _buildActionButton(
                  text: 'Leo Reset',
                  icon: Icons.lock_reset_outlined,
                  onPressed: controller.isResetting.value
                      ? () {}
                      : () => controller.resetLeo(),
                  isLoading: controller.isResetting.value,
                ),
              ),
              const SizedBox(height: 16),
              _buildActionButton(
                text: 'FAQ',
                icon: Icons.question_answer_outlined,
                onPressed: () => controller.openFaq(),
              ),
              const SizedBox(height: 16),
              Obx(
                () => _buildActionButton(
                  text: 'Update From File',
                  icon: Icons.repeat_rounded,
                  onPressed: controller.isUpdating.value
                      ? () {}
                      : () => controller.updateFromFile(),
                  isLoading: controller.isUpdating.value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: isLoading ? () {} : onPressed,
      isLoading: isLoading,
      borderRadius: 10,
      backgroundColor: AppColors.primaryColor,
      textColor: AppColors.whiteColor,
    );
  }
}
