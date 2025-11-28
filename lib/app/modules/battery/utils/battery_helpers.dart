import 'package:flutter/material.dart';

class BatteryHelpers {
  /// Get battery color based on level
  static Color getBatteryColor(int level) {
    if (level < 0) {
      return Colors.grey;
    } else if (level <= 20) {
      return Colors.red;
    } else if (level <= 50) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  /// Get battery status info
  static BatteryStatusInfo getBatteryStatus(int level, bool isCharging) {
    if (level < 0) {
      return BatteryStatusInfo(
        text: 'Unknown',
        icon: Icons.help_outline,
        color: Colors.grey,
      );
    } else if (isCharging) {
      return BatteryStatusInfo(
        text: 'Charging',
        icon: Icons.battery_charging_full,
        color: Colors.green,
      );
    } else if (level <= 20) {
      return BatteryStatusInfo(
        text: 'Low Battery',
        icon: Icons.battery_alert,
        color: Colors.red,
      );
    } else if (level <= 50) {
      return BatteryStatusInfo(
        text: 'Medium',
        icon: Icons.battery_4_bar,
        color: Colors.orange,
      );
    } else {
      return BatteryStatusInfo(
        text: 'Good',
        icon: Icons.battery_full,
        color: Colors.green,
      );
    }
  }

  /// Get battery health info
  static BatteryHealthInfo getBatteryHealth(double healthPercent) {
    if (healthPercent < 0) {
      return BatteryHealthInfo(
        color: Colors.grey,
        status: 'Not calculated',
      );
    } else if (healthPercent >= 80) {
      return BatteryHealthInfo(
        color: Colors.green,
        status: 'Good',
      );
    } else if (healthPercent >= 50) {
      return BatteryHealthInfo(
        color: Colors.orange,
        status: 'Fair',
      );
    } else {
      return BatteryHealthInfo(
        color: Colors.red,
        status: 'Poor',
      );
    }
  }
}

class BatteryStatusInfo {
  final String text;
  final IconData icon;
  final Color color;

  BatteryStatusInfo({
    required this.text,
    required this.icon,
    required this.color,
  });
}

class BatteryHealthInfo {
  final Color color;
  final String status;

  BatteryHealthInfo({
    required this.color,
    required this.status,
  });
}

