import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/modules/battery/charge_limit/controllers/charge_limit_controller.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import '../controllers/battery_controller.dart';
import '../widgets/battery_header.dart';
import '../widgets/battery_metrics_card.dart';

class BatteryView extends GetView<BatteryController> {
  const BatteryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BatteryHeader(),
              const SizedBox(height: 12),
              _buildChargeLimitButton(),
              if (Platform.isAndroid) ...[
                const BatteryMetricsCard(),
                _buildHistoryButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChargeLimitButton() {
    final chargeLimitController = Get.find<ChargeLimitController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomButton(
        text: "Set Charge Limit",
        onPressed: () => Get.toNamed(AppRoutes.setChargeLimitView),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Set Charge Limit",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.whiteColor,
              ),
            ),
            Obx(
              () => Text(
                "${chargeLimitController.chargeLimit.value}%",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomButton(
        text: "View Battery History",
        onPressed: () => Get.toNamed(AppRoutes.batteryHistoryView),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "View Battery History",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.whiteColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
