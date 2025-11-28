import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/battery_controller.dart';
import '../utils/battery_helpers.dart';

class BatteryLevelCard extends GetView<BatteryController> {
  const BatteryLevelCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final level = controller.phoneBatteryLevel.value;
        final isCharging = controller.isPhoneCharging.value;
        final batteryColor = BatteryHelpers.getBatteryColor(level);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [batteryColor, batteryColor.withOpacity(0.7)],
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
          child: Row(
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
              _BatteryIcon(level: level, isCharging: isCharging),
            ],
          ),
        );
      },
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  final int level;
  final bool isCharging;

  const _BatteryIcon({
    required this.level,
    required this.isCharging,
  });

  @override
  Widget build(BuildContext context) {
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
          const Icon(Icons.bolt, color: Colors.white, size: 40),
      ],
    );
  }
}

