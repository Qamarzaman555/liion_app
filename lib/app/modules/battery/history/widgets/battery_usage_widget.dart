import 'package:flutter/material.dart';

class BatteryUsageWidget extends StatefulWidget {
  final String formattedTotalChargeTime;
  final String formattedChargeStartTime;
  final int initialBatteryLevel;
  final int finalBatteryLevel;
  final String batteryUsage;
  final String consumptionRate;
  final bool isCharging;

  const BatteryUsageWidget({
    super.key,
    required this.formattedTotalChargeTime,
    required this.formattedChargeStartTime,
    required this.initialBatteryLevel,
    required this.finalBatteryLevel,
    required this.batteryUsage,
    required this.consumptionRate,
    required this.isCharging,
  });

  @override
  State<BatteryUsageWidget> createState() => _BatteryUsageWidgetState();
}

class _BatteryUsageWidgetState extends State<BatteryUsageWidget> {
  Color _getBatteryUsageColor() {
    if (widget.isCharging) {
      return Colors.green;
    } else if (!widget.isCharging) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${widget.isCharging ? "Charged for" : "Discharged for"} ${widget.formattedTotalChargeTime}",
                  style: const TextStyle(fontSize: 12.56),
                ),
                Text(
                  widget.formattedChargeStartTime,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${widget.initialBatteryLevel}% to ${widget.finalBatteryLevel}%",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  widget.batteryUsage,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: _getBatteryUsageColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Text(
                  "${widget.consumptionRate.length >= 6
                      ? widget.isCharging
                            ? "+${widget.consumptionRate.substring(0, 6)}"
                            : "-${widget.consumptionRate.substring(0, 6)}"
                      : widget.isCharging
                      ? "+${widget.consumptionRate}"
                      : "-${widget.consumptionRate}"} mAh",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
