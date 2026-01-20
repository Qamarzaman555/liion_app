import 'package:flutter/material.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';

class DisconnectDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String? title;
  final String? message;
  final String? confirmText;
  final String? cancelText;

  const DisconnectDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    this.title,
    this.message,
    this.confirmText,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSizes.lg),
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            color: NewAppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.cardRadiusLg * 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                title ?? 'Disconnect Device',
                style: const TextStyle(
                  fontSize: AppSizes.fontSizeMd,
                  fontWeight: FontWeight.w600,
                  color: NewAppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // Message
              Text(
                message ??
                    'Are you sure you want to disconnect from this device?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppSizes.fontSizeSm,
                  color: NewAppColors.darkGrey,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Action buttons
              Row(
                children: [
                  // No button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NewAppColors.mediumContainer,
                        foregroundColor: NewAppColors.black,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.cardRadiusLg * 2,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        cancelText ?? 'Cancel',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSizeSm - 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),

                  // Yes button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NewAppColors.mediumContainer,
                        foregroundColor: NewAppColors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.cardRadiusLg * 2,
                          ),
                        ),
                        elevation: 0,
                      ),

                      child: Text(
                        confirmText ?? 'Disconnect',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSizeSm - 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
