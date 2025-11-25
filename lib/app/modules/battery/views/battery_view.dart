import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import '../controllers/battery_controller.dart';

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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Text(
                  "Phone",
                  style: TextStyle(
                    color: Color(0xFF282828),
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Battery Card
              Obx(() => _buildBatteryCard()),
              const SizedBox(height: 20),
              // Battery Info
              Obx(() => _buildBatteryInfo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryCard() {
    final level = controller.phoneBatteryLevel.value;
    final isCharging = controller.isPhoneCharging.value;

    Color batteryColor;
    if (level < 0) {
      batteryColor = Colors.grey;
    } else if (level <= 20) {
      batteryColor = Colors.red;
    } else if (level <= 50) {
      batteryColor = Colors.orange;
    } else {
      batteryColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            batteryColor,
            batteryColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: batteryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
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
                    isCharging ? 'Charging' : 'Battery',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        level < 0 ? '--' : '$level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(
                          '%',
                          style: TextStyle(
                            color: Colors.white70,
                            fontFamily: 'Inter',
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Battery icon with level indicator
              _buildBatteryIcon(level, isCharging),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryIcon(int level, bool isCharging) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 80,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Battery cap
              Container(
                width: 30,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 100 - (level < 0 ? 0 : level),
                        child: Container(),
                      ),
                      Expanded(
                        flex: level < 0 ? 0 : level,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isCharging)
          const Icon(
            Icons.bolt,
            color: Colors.white,
            size: 40,
          ),
      ],
    );
  }

  Widget _buildBatteryInfo() {
    final level = controller.phoneBatteryLevel.value;
    final isCharging = controller.isPhoneCharging.value;

    String statusText;
    IconData statusIcon;
    Color statusColor;

    if (level < 0) {
      statusText = 'Unknown';
      statusIcon = Icons.help_outline;
      statusColor = Colors.grey;
    } else if (isCharging) {
      statusText = 'Charging';
      statusIcon = Icons.battery_charging_full;
      statusColor = Colors.green;
    } else if (level <= 20) {
      statusText = 'Low Battery';
      statusIcon = Icons.battery_alert;
      statusColor = Colors.red;
    } else if (level <= 50) {
      statusText = 'Medium';
      statusIcon = Icons.battery_4_bar;
      statusColor = Colors.orange;
    } else {
      statusText = 'Good';
      statusIcon = Icons.battery_full;
      statusColor = Colors.green;
    }

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
          _buildInfoTile(
            icon: statusIcon,
            iconColor: statusColor,
            title: 'Status',
            value: statusText,
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.percent,
            iconColor: AppColors.primaryColor,
            title: 'Level',
            value: level < 0 ? 'Unknown' : '$level%',
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.power,
            iconColor: isCharging ? Colors.green : Colors.grey,
            title: 'Power Source',
            value: isCharging ? 'Connected' : 'Battery',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
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
