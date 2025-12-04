import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

import '../../controllers/leo_home_controller.dart';

class LeoFirmwareUpdateDialog extends StatelessWidget {
  const LeoFirmwareUpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final LeoHomeController controller = Get.find();
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: screenWidth,
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OTA Update Progress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 24),
              LinearProgressIndicator(
                value: 0.5,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Colors.grey[300],
              ),
              SizedBox(height: 32),
              CustomButton(
                text: 'Cancel',
                textColor: AppColors.blackColor,
                borderColor: AppColors.blackColor,
                backgroundColor: AppColors.transparentColor,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blackColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
