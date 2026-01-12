import 'package:flutter/material.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';

class AccessScreensWidget extends StatelessWidget {
  final String titleText;
  final String subTitleText;
  final bool showBackButton;
  final VoidCallback onNextTap;
  final VoidCallback onSkipTap;
  const AccessScreensWidget({
    super.key,
    required this.titleText,
    required this.subTitleText,
    this.showBackButton = true,
    required this.onNextTap,
    required this.onSkipTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSizes.spaceBtwSections * 2,
            horizontal: AppSizes.spaceBtwSections,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showBackButton)
                InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {}
                  },
                  child: Icon(Icons.arrow_back_ios_new_rounded),
                ),
              const SizedBox(height: AppSizes.spaceBtwSections),
              Text(
                titleText,
                style: const TextStyle(
                  fontSize: AppSizes.fontSizeExtraLg,
                  fontFamily: 'SF Pro Text',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSizes.spaceBtwTexts),
              Text(
                subTitleText,
                style: const TextStyle(
                  fontSize: AppSizes.fontSizeSm,
                  color: NewAppColors.textSecondary,
                  fontFamily: 'SF Pro Text',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: CustomButton(text: "Next", onPressed: onNextTap),
              ),
              const SizedBox(height: AppSizes.spaceBtwTexts),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: CustomButton(
                  text: "Skip",
                  onPressed: onSkipTap,
                  backgroundColor: NewAppColors.transparent,
                  textColor: NewAppColors.darkerGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
