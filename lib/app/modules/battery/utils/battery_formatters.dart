class BatteryFormatters {
  /// Format time in seconds to readable string (e.g., "1h 23m 45s")
  static String formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m ${secs}s";
    } else if (minutes > 0) {
      return "${minutes}m ${secs}s";
    } else {
      return "${secs}s";
    }
  }

  /// Format current from mA to A with 4 decimal places
  static String formatCurrent(double currentMa) {
    return "${(currentMa / 1000).toStringAsFixed(4)} A";
  }

  /// Format voltage with 2 decimal places
  static String formatVoltage(double voltage) {
    return "${voltage.toStringAsFixed(2)} V";
  }

  /// Format temperature with 1 decimal place
  static String formatTemperature(double temperature) {
    return "${temperature.toStringAsFixed(1)}°C";
  }

  /// Format mAh with 2 decimal places
  static String formatMah(double mah) {
    return "${mah.toStringAsFixed(2)} mAh";
  }

  /// Format battery health percentage
  static String formatHealthPercent(double healthPercent) {
    if (healthPercent < 0) return "--";
    return "${healthPercent.toInt()}%";
  }

  /// Format capacity
  static String formatCapacity(int capacity) {
    if (capacity < 1) return "--";
    return "$capacity mAh";
  }

  /// Format estimated capacity
  static String formatEstimatedCapacity(double capacity) {
    if (capacity < 1) return "--";
    return "${capacity.toStringAsFixed(2)} mAh";
  }
}
