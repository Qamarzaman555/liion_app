import 'package:flutter/material.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';

class ChargingModeExpansionTile extends StatelessWidget {
  const ChargingModeExpansionTile({super.key});

  @override
  Widget build(BuildContext context) {
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
          GestureDetector(
            onTap: () {},
            child: Padding(
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
                      _getModeIcon('Smart Mode', 'Smart Mode'),
                      height: 50,
                      width: 50,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Mode',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            fontFamily: "SF Pro Text",
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Smart Mode',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      color: Colors.black87,
                      fontFamily: "SF Pro Text",
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          // if (controller.isExpanded.value)
          if (true)
            Padding(
              padding: const EdgeInsets.all(AppSizes.sm),
              child: Column(
                children: ['Smart Mode', 'Safe Mode'].map((mode) {
                  final isSelected = 'Smart Mode' == mode;
                  return GestureDetector(
                    onTap: () {},
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
                                _getModeIcon(mode, 'Smart Mode'),
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
                                    mode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: Colors.black87,
                                      fontFamily: "SF Pro Text",
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.xs),
                                  Text(
                                    'Smart Mode',
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
  }
}

String _getModeIcon(String mode, String selectedMode) {
  switch (mode) {
    case 'Smart Mode':
      return selectedMode == 'Smart Mode'
          ? AppImages.smartChargingModeImage
          : AppImages.smartChargingModeImage; // Green leaf for eco-friendly
    case 'Safe Mode':
      return selectedMode == 'Safe Mode'
          ? AppImages.safeChargingModeImage
          : AppImages.safeChargingModeImage;
    case 'Ghost Mode':
      return selectedMode == 'Ghost Mode'
          ? AppImages.ghostChargingModeImage
          : AppImages.ghostChargingModeImage; // Lightning bolt for speed
    default:
      return AppImages.smartChargingModeImage;
  }
}

Color _getModeIconColor(String mode) {
  switch (mode) {
    case 'Smart Mode':
      return Colors.green; // Green for eco-friendly
    case 'Safe Mode':
      return Colors.green; // Green shield
    case 'Ghost Mode':
      return Colors.blue; // Blue for speed/performance
    default:
      return NewAppColors.error;
  }
}
