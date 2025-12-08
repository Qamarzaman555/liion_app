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
        actions: [
          Obx(() {
            if (controller.sessions.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final confirmed = await Get.dialog<bool>(
                  AlertDialog(
                    title: const Text('Clear Sessions'),
                    content: const Text(
                      'Are you sure you want to clear all battery session history? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await controller.clearSessions();
                }
              },
              tooltip: 'Clear all sessions',
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondaryColor),
          );
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
          onRefresh: controller.refreshLoadSessions,
          color: AppColors.secondaryColor,

          child: Obx(
            () => ListView.builder(
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
          ),
        );
      }),
    );
  }
}
