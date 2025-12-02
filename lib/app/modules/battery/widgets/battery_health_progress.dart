import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import '../controllers/battery_controller.dart';

class BatteryHealthProgress extends GetView<BatteryController> {
  const BatteryHealthProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 0, right: 8),
                  child: Text(
                    "Battery Health",
                    style: TextStyle(
                      color: Color(0xFF282828),
                      fontFamily: 'Inter',
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SvgPicture.asset(
                      SvgAssets.greenEllipse,
                      width: 22,
                      height: 22,
                    ),
                    SvgPicture.asset(
                      SvgAssets.mdiBattery,
                      width: 22,
                      height: 20,
                    ),
                  ],
                ),
              ],
            ),
            Obx(
              () => Padding(
                padding: const EdgeInsets.only(left: 0),
                child: Text(
                  controller.batteryHealthPercent.value < 0
                      ? "--"
                      : "${(controller.batteryHealthPercent.value > 100 ? 100 : controller.batteryHealthPercent.value.toStringAsFixed(0))}%",
                  style: const TextStyle(
                    color: Color(0xFF282828),
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Obx(
          () => LinearProgressIndicator(
            value: (controller.batteryHealthPercent.value < 0
                ? 0
                : controller.batteryHealthPercent.value / 100),
            backgroundColor: Colors.grey.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF97CF43)),
          ),
        ),
        Obx(
          () => controller.healthReadingsCount.value > 0
              ? Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Text(
                    'Health reading based on ${controller.healthReadingsCount.value} charge cycles (${controller.healthReadingsCount.value * 60}% charged) ${controller.totalEstimatedValues.value.toInt()} mAh total',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
