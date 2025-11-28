import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import '../controllers/battery_controller.dart';
import '../utils/battery_helpers.dart';
import '../utils/battery_formatters.dart';
import 'battery_capacity_row.dart';

class BatteryHealthSection extends GetView<BatteryController> {
  const BatteryHealthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final healthPercent = controller.batteryHealthPercent.value;
        final estimatedCapacity = controller.estimatedCapacityMah.value;
        final designedCapacity = controller.designedCapacityMah.value;
        final isCalculating = controller.healthCalculationInProgress.value;
        final progress = controller.healthCalculationProgress.value;
        final isCharging = controller.isPhoneCharging.value;
        final batteryLevel = controller.phoneBatteryLevel.value;
        final healthReadingsCount = controller.healthReadingsCount.value;
        final totalEstimatedValues = controller.totalEstimatedValues.value;

        final healthInfo = BatteryHelpers.getBatteryHealth(healthPercent);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Battery Health',
                style: TextStyle(
                  color: Color(0xFF282828),
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _HealthCard(
                healthPercent: healthPercent,
                healthInfo: healthInfo,
                isCalculating: isCalculating,
                progress: progress,
              ),
              const SizedBox(height: 16),
              _CapacityInfo(
                designedCapacity: designedCapacity,
                estimatedCapacity: estimatedCapacity,
                healthColor: healthInfo.color,
              ),
              if (healthReadingsCount > 0) ...[
                const SizedBox(height: 20),
                _HealthReadingsInfo(
                  healthReadingsCount: healthReadingsCount,
                  totalEstimatedValues: totalEstimatedValues,
                ),
              ],
              const SizedBox(height: 20),
              _HealthCalculationButton(
                isCalculating: isCalculating,
                isCharging: isCharging,
                batteryLevel: batteryLevel,
                onStart: controller.startHealthCalculation,
                onStop: controller.stopHealthCalculation,
              ),
              const SizedBox(height: 12),
              const _CalculationNote(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _HealthCard extends StatelessWidget {
  final double healthPercent;
  final BatteryHealthInfo healthInfo;
  final bool isCalculating;
  final int progress;

  const _HealthCard({
    required this.healthPercent,
    required this.healthInfo,
    required this.isCalculating,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            healthInfo.color.withOpacity(0.1),
            healthInfo.color.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: healthInfo.color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    BatteryFormatters.formatHealthPercent(healthPercent),
                    style: TextStyle(
                      color: healthInfo.color,
                      fontFamily: 'Inter',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    healthInfo.status,
                    style: TextStyle(
                      color: healthInfo.color,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(Icons.health_and_safety, color: healthInfo.color, size: 60),
            ],
          ),
          if (isCalculating) ...[
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Calculating...',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(healthInfo.color),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CapacityInfo extends StatelessWidget {
  final int designedCapacity;
  final double estimatedCapacity;
  final Color healthColor;

  const _CapacityInfo({
    required this.designedCapacity,
    required this.estimatedCapacity,
    required this.healthColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BatteryCapacityRow(
          label: 'Designed Capacity',
          value: BatteryFormatters.formatCapacity(designedCapacity),
        ),
        const SizedBox(height: 12),
        BatteryCapacityRow(
          label: 'Estimated Capacity',
          value: BatteryFormatters.formatEstimatedCapacity(estimatedCapacity),
        ),
      ],
    );
  }
}

class _HealthReadingsInfo extends StatelessWidget {
  final int healthReadingsCount;
  final double totalEstimatedValues;

  const _HealthReadingsInfo({
    required this.healthReadingsCount,
    required this.totalEstimatedValues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Text(
        'Health reading based on $healthReadingsCount charge cycles (${healthReadingsCount * 60}% charged) ${totalEstimatedValues.toInt()} mAh total',
        style: TextStyle(
          color: Colors.grey[700],
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _HealthCalculationButton extends StatelessWidget {
  final bool isCalculating;
  final bool isCharging;
  final int batteryLevel;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _HealthCalculationButton({
    required this.isCalculating,
    required this.isCharging,
    required this.batteryLevel,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    String buttonText;
    VoidCallback? onPressed;

    if (isCalculating) {
      buttonText = 'Stop Calculation';
      onPressed = onStop;
    } else if (isCharging && batteryLevel <= 40) {
      buttonText = 'Start Health Calculation';
      onPressed = onStart;
    } else if (isCharging) {
      buttonText = 'Battery too high (need ≤40%)';
      onPressed = null;
    } else {
      buttonText = 'Plug in charger to calculate';
      onPressed = null;
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(isCalculating ? Icons.stop : Icons.play_arrow),
        label: Text(buttonText),
        style: ElevatedButton.styleFrom(
          backgroundColor: isCalculating ? Colors.red : AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _CalculationNote extends StatelessWidget {
  const _CalculationNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Note: Health calculation requires 60% charge increase. '
      'Keep device plugged in during calculation.',
      style: TextStyle(
        color: Colors.grey[600],
        fontFamily: 'Inter',
        fontSize: 12,
      ),
      textAlign: TextAlign.center,
    );
  }
}

