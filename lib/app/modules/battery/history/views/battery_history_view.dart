import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/modules/battery/history/controllers/battery_history_controller.dart';
import 'package:liion_app/app/modules/battery/history/widgets/battery_usage_widget.dart';

class BatteryHistoryView extends GetView<BatteryHistoryController> {
  const BatteryHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: AppBar(
        title: const Text('Battery History'),
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.battery_charging_full,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No battery sessions yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sessions will appear here as you charge or discharge',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: controller.sessions.length,
            itemBuilder: (context, index) {
              final session = controller.sessions[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: BatteryUsageWidget(
                  formattedTotalChargeTime: session.formattedDuration,
                  formattedChargeStartTime: session.formattedStartTime,
                  initialBatteryLevel: session.initialLevel,
                  finalBatteryLevel: session.finalLevel,
                  batteryUsage: session.batteryUsageString,
                  consumptionRate: session.consumptionRate,
                  isCharging: session.isCharging,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
