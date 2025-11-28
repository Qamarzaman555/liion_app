import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/modules/battery/charge_limit/controllers/charge_limit_controller.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import '../controllers/battery_controller.dart';
import '../widgets/battery_header.dart';
import '../widgets/battery_metrics_card.dart';
import '../widgets/battery_level_card.dart';
import '../widgets/battery_status_section.dart';
import '../widgets/battery_health_section.dart';

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
              const BatteryMetricsCard(),
              // const BatteryLevelCard(),
              // const SizedBox(height: 20),
              // const BatteryStatusSection(),
              // const SizedBox(height: 24),
              // const BatteryHealthSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChargeLimitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomButton(
        text: "Set Charge Limit",
        onPressed: () => Get.toNamed(AppRoutes.setChargeLimitView),
        child: Row(
          children: [
            Text(
              "Set Charge Limit",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.whiteColor,
              ),
            ),
            // Text(
            //   "(${Get.find<ChargeLimitController>().chargeLimit.value}%)",
            //   style: TextStyle(
            //     fontSize: 16,
            //     fontWeight: FontWeight.w600,
            //     color: AppColors.whiteColor,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
