import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/modules/leo_empty/utils/charge_models.dart';

class ChargingModeExpansionTile extends GetView<LeoHomeController> {
  const ChargingModeExpansionTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentMode = controller.currentMode.value;
      final modeName = _getModeName(currentMode);
      final modeDescription = _getModeDescription(currentMode);

      return Container(
        decoration: BoxDecoration(
          color: NewAppColors.whiteBackground,
          borderRadius: BorderRadius.circular(AppSizes.md),
          border: Border.all(color: NewAppColors.containerBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header (always visible)
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: NewAppColors.whiteBackground,
                      borderRadius: BorderRadius.circular(
                        AppSizes.cardRadiusSm,
                      ),
                      border: Border.all(
                        color: NewAppColors.containerBorder,
                        width: 1,
                      ),
                    ),
                    child: Image.asset(
                      _getModeIcon(currentMode),
                      height: 50,
                      width: 50,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          modeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: "SF Pro Text",
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          modeDescription,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade600,
                            fontFamily: "SF Pro Text",
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Expandable content - show all modes
            Padding(
              padding: const EdgeInsets.all(AppSizes.sm),
              child: Column(
                children: [
                  ChargingMode.smart,
                  ChargingMode.ghost,
                  ChargingMode.safe,
                ].map((mode) {
                  final isSelected = currentMode == mode;
                  final modeName = _getModeName(mode);
                  final modeDesc = _getModeDescription(mode);

                  return GestureDetector(
                    onTap: () => controller.updateChargingMode(mode),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSizes.sm),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEDEDED)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppSizes.cardRadiusMd + 2,
                        ),
                        border: Border.all(
                          color: NewAppColors.containerBorder,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: AppSizes.md - 3,
                        ),
                        child: Row(
                          children: [
                            // Icon Container
                            Container(
                              padding: const EdgeInsets.all(AppSizes.xs),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.cardRadiusSm,
                                ),
                                border: Border.all(
                                  color: NewAppColors.containerBorder,
                                  width: 1,
                                ),
                              ),
                              child: Image.asset(
                                _getModeIcon(mode),
                                height: 40,
                                width: 40,
                              ),
                            ),
                            const SizedBox(width: AppSizes.md),
                            // Text Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    modeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontFamily: "SF Pro Text",
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.xs),
                                  Text(
                                    modeDesc,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                      fontFamily: "SF Pro Text",
                                      color: Colors.grey.shade600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Selection Indicator
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: NewAppColors.accent,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    });
  }

  String _getModeName(ChargingMode mode) {
    switch (mode) {
      case ChargingMode.smart:
        return 'Smart Mode';
      case ChargingMode.ghost:
        return 'Ghost Mode';
      case ChargingMode.safe:
        return 'Safe Mode';
    }
  }

  String _getModeDescription(ChargingMode mode) {
    switch (mode) {
      case ChargingMode.smart:
        return 'Optimizes charging to prioritize battery health';
      case ChargingMode.ghost:
        return 'Fast, unrestricted charging with no optimizations';
      case ChargingMode.safe:
        return 'Blocks data lines for public charging ports';
    }
  }

  String _getModeIcon(ChargingMode mode) {
    switch (mode) {
      case ChargingMode.smart:
        return AppImages.smartChargingModeImage;
      case ChargingMode.ghost:
        return AppImages.ghostChargingModeImage;
      case ChargingMode.safe:
        return AppImages.safeChargingModeImage;
    }
  }
}
