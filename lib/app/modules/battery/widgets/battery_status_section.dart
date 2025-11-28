import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import '../controllers/battery_controller.dart';
import '../utils/battery_helpers.dart';

class BatteryStatusSection extends GetView<BatteryController> {
  const BatteryStatusSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Battery Status',
            style: TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final level = controller.phoneBatteryLevel.value;
            final isCharging = controller.isPhoneCharging.value;
            final statusInfo = BatteryHelpers.getBatteryStatus(
              level,
              isCharging,
            );

            return Column(
              children: [
                _BatteryInfoTile(
                  icon: statusInfo.icon,
                  iconColor: statusInfo.color,
                  title: 'Status',
                  value: statusInfo.text,
                ),
                const SizedBox(height: 12),
                _BatteryInfoTile(
                  icon: Icons.percent,
                  iconColor: AppColors.primaryColor,
                  title: 'Level',
                  value: level < 0 ? 'Unknown' : '$level%',
                ),
                const SizedBox(height: 12),
                _BatteryInfoTile(
                  icon: Icons.power,
                  iconColor: isCharging ? Colors.green : Colors.grey,
                  title: 'Power Source',
                  value: isCharging ? 'Connected' : 'Battery',
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _BatteryInfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _BatteryInfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF282828),
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
