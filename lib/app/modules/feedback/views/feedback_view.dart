import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import '../controllers/feedback_controller.dart';

class FeedbackView extends GetView<FeedbackController> {
  const FeedbackView({super.key});

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
          'Feedback',
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
            const Text(
              'We\'d love to hear from you!',
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please share your thoughts, suggestions, or report any issues you\'ve encountered.',
              style: TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Your Feedback',
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Enter your feedback here...',
                hintStyle: const TextStyle(
                  color: Color(0xFF888888),
                  fontFamily: 'Inter',
                ),
                filled: true,
                fillColor: AppColors.cardBGColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
              onChanged: (value) => controller.setFeedback(value),
            ),

            const SizedBox(height: 32),
            Obx(
              () => CustomButton(
                text: 'Submit Feedback',
                onPressed: () {
                  if (controller.feedbackText.value.trim().isNotEmpty) {
                    _submitFeedback(context);
                  }
                },
                backgroundColor: controller.feedbackText.value.trim().isEmpty
                    ? AppColors.greyColor
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            _buildContactInfo(),
          ],
        ),
      ),
    );
  }

  void _submitFeedback(BuildContext context) {
    if (controller.feedbackText.value.trim().isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter your feedback',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.errorColor,
        colorText: AppColors.whiteColor,
      );
      return;
    }

    // TODO: Implement actual feedback submission
    Get.snackbar(
      'Thank You!',
      'Your feedback has been submitted successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.primaryColor,
      colorText: AppColors.whiteColor,
    );

    // Clear feedback and go back
    controller.setFeedback('');
    Future.delayed(const Duration(seconds: 1), () => Get.back());
  }

  Widget _buildContactInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBGColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Contact Information',
                style: TextStyle(
                  color: Color(0xFF282828),
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Email: support@liionpower.nl',
            style: TextStyle(
              color: Color(0xFF888888),
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Website: www.liionpower.nl',
            style: TextStyle(
              color: Color(0xFF888888),
              fontFamily: 'Inter',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
