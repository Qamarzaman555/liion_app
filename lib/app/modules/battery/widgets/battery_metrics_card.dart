import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import '../controllers/battery_controller.dart';
import '../utils/battery_formatters.dart';
import 'battery_metric_row.dart';
import 'battery_health_progress.dart';
import 'battery_capacity_row.dart';

class BatteryMetricsCard extends GetView<BatteryController> {
  const BatteryMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 32),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            _buildMetrics(screenHeight),
            const SizedBox(height: 30),
            const BatteryHealthProgress(),
            const SizedBox(height: 20),
            _buildCapacityRows(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Text(
          "This Device Battery",
          style: TextStyle(
            color: Color(0xFF282828),
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
          child: SvgPicture.asset(
            SvgAssets.leoChargingIcon,
            height: 20,
            width: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(double screenHeight) {
    return Column(
      children: [
        Obx(
          () => BatteryMetricRow(
            title: "Current",
            value: BatteryFormatters.formatCurrent(
              controller.batteryCurrent.value,
            ),
            screenHeight: screenHeight,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => BatteryMetricRow(
            title: "Voltage",
            value: BatteryFormatters.formatVoltage(
              controller.batteryVoltage.value,
            ),
            screenHeight: screenHeight,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => BatteryMetricRow(
            title: "Temperature",
            value: BatteryFormatters.formatTemperature(
              controller.batteryTemperature.value,
            ),
            screenHeight: screenHeight,
          ),
        ),
        const SizedBox(height: 12),
        Obx(
          () => BatteryMetricRow(
            title:
                "mAh ${controller.isPhoneCharging.value ? "charging" : "discharging"}",
            value: BatteryFormatters.formatMah(controller.accumulatedMah.value),
            screenHeight: screenHeight,
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final timeSeconds = controller.isPhoneCharging.value
              ? controller.chargingTimeSeconds.value
              : controller.dischargingTimeSeconds.value;
          return BatteryMetricRow(
            title:
                "Time ${controller.isPhoneCharging.value ? "charged" : "discharged"}",
            value: BatteryFormatters.formatTime(timeSeconds),
            screenHeight: screenHeight,
          );
        }),
      ],
    );
  }

  Widget _buildCapacityRows(BuildContext context) {
    return Column(
      children: [
        Obx(
          () => BatteryCapacityRow(
            label: "Designed Capacity",
            value: BatteryFormatters.formatCapacity(
              controller.designedCapacityMah.value,
            ),
          ),
        ),
        Obx(
          () => BatteryCapacityRow(
            label: "Estimated Capacity",
            value: BatteryFormatters.formatEstimatedCapacity(
              controller.estimatedCapacityMah.value,
            ),
          ),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Reset health button
            GestureDetector(
              onTap: () => _showClearHealthDialog(context, controller),
              child: const Text(
                "Reset Health",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.lightGreen,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showClearHealthDialog(
    BuildContext context,
    BatteryController batteryController,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text(
            'Clear Battery Health Data',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'Are you sure you want to clear the estimated capacity and battery health values? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await batteryController.resetHealthReadings();
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.lightGreen),
              ),
            ),
          ],
        );
      },
    );
  }
}
