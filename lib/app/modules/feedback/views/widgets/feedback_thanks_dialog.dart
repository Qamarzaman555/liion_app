import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';

class FeedbackThanksDialog extends StatelessWidget {
  const FeedbackThanksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 5.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          border: Border.all(color: AppColors.whiteColor, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thank You!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF282828),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'With your feedback we can improve Leo and provide a better experience for you in the future.',
              style: TextStyle(
                color: Color(0xFF282828),
                fontSize: 14,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Continue',
              onPressed: () {
                Get.back();
                Get.back();
              },
              backgroundColor: AppColors.secondaryColor,
              height: 50,
            ),
          ],
        ),
      ),
    );
  }
}
