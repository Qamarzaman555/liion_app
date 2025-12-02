class BatterySession {
  final int startTime; // milliseconds since epoch
  final int endTime; // milliseconds since epoch
  final int initialLevel; // percentage
  final int finalLevel; // percentage
  final bool isCharging;
  final int durationSeconds;
  final double accumulatedMah; // mAh

  BatterySession({
    required this.startTime,
    required this.endTime,
    required this.initialLevel,
    required this.finalLevel,
    required this.isCharging,
    required this.durationSeconds,
    required this.accumulatedMah,
  });

  factory BatterySession.fromMap(Map<dynamic, dynamic> map) {
    return BatterySession(
      startTime: (map['startTime'] as num?)?.toInt() ?? 0,
      endTime: (map['endTime'] as num?)?.toInt() ?? 0,
      initialLevel: (map['initialLevel'] as num?)?.toInt() ?? 0,
      finalLevel: (map['finalLevel'] as num?)?.toInt() ?? 0,
      isCharging: map['isCharging'] as bool? ?? false,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      accumulatedMah: (map['accumulatedMah'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Calculate battery usage percentage (final - initial)
  int get batteryUsage => finalLevel - initialLevel;

  /// Get formatted battery usage string (e.g., "+15%" or "-20%")
  String get batteryUsageString {
    final usage = batteryUsage;
    return usage >= 0 ? "+$usage%" : "$usage%";
  }

  /// Get formatted duration string (e.g., "1h 23m 45s")
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m ${secs}s";
    } else if (minutes > 0) {
      return "${minutes}m ${secs}s";
    } else {
      return "${secs}s";
    }
  }

  /// Get formatted start time string
  String get formattedStartTime {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(startTime);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // Format time as h:mm AM/PM
    final hour12 = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour;
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    final timeString =
        "$hour12:${dateTime.minute.toString().padLeft(2, '0')} $period";

    if (sessionDate == today) {
      // Today: show "today, --time"
      return "today, $timeString";
    } else if (sessionDate == yesterday) {
      // Yesterday: show "yesterday, --time"
      return "yesterday, $timeString";
    } else {
      // Other days: show "1 Dec, --time"
      const monthAbbreviations = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return "${dateTime.day} ${monthAbbreviations[dateTime.month - 1]}, $timeString";
    }
  }

  /// Get formatted consumption rate (mAh)
  String get consumptionRate {
    return accumulatedMah.toStringAsFixed(2);
  }
}
