import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/modules/leo_empty/graphs/charge_graph_widget.dart';
import '../../controllers/leo_home_controller.dart';

class LeoMetricsSummary extends StatelessWidget {
  const LeoMetricsSummary({super.key, required this.controller});

  final LeoHomeController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          color: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _MetricRow(
                  leading: const _MetricLabel(
                    icon: Icons.bolt,
                    label: 'Current',
                  ),
                  trailing: Obx(
                    () =>
                        _MetricValueChip(value: controller.currentValue.value),
                  ),
                  extra: Obx(
                    () =>
                        _MetricValueChip(value: controller.voltageValue.value),
                  ),
                  extraLabel: 'Voltage',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Power'),
                    const SizedBox(width: 12),
                    Obx(
                      () =>
                          _MetricValueChip(value: controller.powerValue.value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Firmware'),
                    const SizedBox(width: 12),
                    Obx(
                      () => _MetricValueChip(
                        value: controller.binFileFromLeoName.value.isEmpty
                            ? 'N/A'
                            : controller.binFileFromLeoName.value,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const ChargeGraphWidget(isCurrentCharge: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: AppColors.whiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    const Icon(
                      Icons.bolt,
                      color: AppColors.secondaryColor,
                      size: 22,
                    ),
                    const Text('Total Charges'),
                    const SizedBox(width: 12),
                    Obx(
                      () => _MetricValueChip(value: controller.mwhValue.value),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ChargeGraphWidget(isCurrentCharge: false),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.leading,
    required this.trailing,
    required this.extra,
    required this.extraLabel,
  });

  final Widget leading;
  final Widget trailing;
  final Widget extra;
  final String extraLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        SizedBox(width: 8),
        trailing,
        const Spacer(),
        Text(extraLabel, style: TextStyle()),
        SizedBox(width: 8),
        extra,
      ],
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.secondaryColor, size: 22),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class _MetricValueChip extends StatelessWidget {
  const _MetricValueChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4DAEA7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          value,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
