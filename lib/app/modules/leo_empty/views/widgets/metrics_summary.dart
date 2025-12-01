import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/modules/leo_empty/graphs/charge_graph_widget.dart';
import 'package:liion_app/app/modules/leo_empty/utils/charge_models.dart';
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
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showModeSelectionDialog(context),
                      child: Obx(() {
                        final mode = controller.currentMode.value;
                        final svgIcon = _modeIcon(mode);
                        final label = _modeLabel(mode);
                        return Row(
                          children: [
                            _currentChargingMode(svgIcon),
                            const SizedBox(width: 8),
                            _chargingModeText(label),
                          ],
                        );
                      }),
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

  Widget _currentChargingMode(String svgIcon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAEAEA).withOpacity(0.6),
        border: Border.all(color: const Color(0xFF000000).withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SvgPicture.asset(svgIcon, height: 24, width: 24),
    );
  }

  Widget _chargingModeText(String mode) {
    return Text(
      mode,
      style: const TextStyle(
        color: Color(0xFF4DAEA7),
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Add method to show mode selection dialog
  Future<void> _showModeSelectionDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Select Charging Mode',
            style: TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                children: [
                  _buildModeOption(
                    context,
                    'Smart Mode',
                    'Optimizes charging to prioritize battery health and long-term longevity.',
                    Icons.smart_toy,
                    ChargingMode.smart,
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E5E5)),
                  _buildModeOption(
                    context,
                    'Ghost Mode',
                    'Enables fast, unrestricted charging with no battery-saving optimizations.',
                    Icons.power_settings_new,
                    ChargingMode.ghost,
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E5E5)),
                  _buildModeOption(
                    context,
                    'Safe Mode',
                    'Blocks data lines to protect your device when using public charging ports.',
                    Icons.shield,
                    ChargingMode.safe,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _modeLabel(ChargingMode mode) {
    switch (mode) {
      case ChargingMode.smart:
        return 'Smart Mode';
      case ChargingMode.ghost:
        return 'Ghost Mode';
      case ChargingMode.safe:
        return 'Safe Mode';
    }
  }

  String _modeIcon(ChargingMode mode, {bool filled = false}) {
    switch (mode) {
      case ChargingMode.smart:
        return filled ? SvgAssets.smartModeIconFilled : SvgAssets.smartModeIcon;
      case ChargingMode.ghost:
        return filled ? SvgAssets.ghostModeIconFilled : SvgAssets.ghostModeIcon;
      case ChargingMode.safe:
        return filled ? SvgAssets.safeModeIconFilled : SvgAssets.safeModeIcon;
    }
  }

  Widget _buildModeOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    ChargingMode mode,
  ) {
    final isSelected = controller.currentMode.value == mode;
    final svgIcon = _modeIcon(mode, filled: isSelected);

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        controller.updateChargingMode(mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondaryColor.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.secondaryColor
                    : AppColors.cardBGColor.withOpacity(0.6),
                border: Border.all(
                  color: const Color(0xFF000000).withOpacity(0.1),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(svgIcon, height: 36, width: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF282828),
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color(0xFF282828).withOpacity(0.6),
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            isSelected
                ? SvgPicture.asset(
                    SvgAssets.checkCircleFilled,
                    height: 28,
                    width: 28,
                  )
                : SvgPicture.asset(
                    SvgAssets.checkCircle,
                    height: 28,
                    width: 28,
                  ),
          ],
        ),
      ),
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
        const SizedBox(width: 8),
        trailing,
        const Spacer(),
        Text(extraLabel, style: const TextStyle()),
        const SizedBox(width: 8),
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
