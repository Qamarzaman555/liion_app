import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import '../controllers/battery_controller.dart';

class BatteryView extends GetView<BatteryController> {
  const BatteryView({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 40, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Battery",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        color: AppColors.yellowColor,
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: 1,
                          bottom: 1,
                        ),
                        child: Obx(
                          () => Text(
                            "${controller.phoneBatteryLevel.value}%",
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12),
              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
                child: CustomButton(
                  height: 70,

                  text: "Set Charge Limit ",
                  onPressed: () {},
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12, width: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            "This Device Battery",
                            style: TextStyle(
                              color: Color(0xFF282828),
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                            child: SvgPicture.asset(
                              SvgAssets.leoChargingIcon,
                              height: 20,
                              width: 20,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),

                      _buildStateRow("Current", "0.0002A", screenHeight),
                      SizedBox(height: 12),
                      _buildStateRow("Voltage", "0.0002A", screenHeight),
                      SizedBox(height: 12),

                      _buildStateRow("Temprature", "0.0002A", screenHeight),
                      SizedBox(height: 12),

                      Obx(
                        () => _buildStateRow(
                          "maH ${controller.isPhoneCharging.value ? "charging" : "discharging"}",
                          "0.0002A",
                          screenHeight,
                        ),
                      ),
                      SizedBox(height: 12),

                      Obx(
                        () => _buildStateRow(
                          "Time ${controller.isPhoneCharging.value ? "charged" : "discharged"}",
                          "0.0002A",
                          screenHeight,
                        ),
                      ),

                      const SizedBox(height: 30),
                      // Actual Current Row
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
                              // Removing left padding to eliminate the gap
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
                                controller.healthReadingsCount.value < 1
                                    ? "--"
                                    : "${(controller.healthReadingsCount.value > 100 ? 100 : controller.healthReadingsCount.value.toStringAsFixed(2))}%",
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

                      SizedBox(height: 16),
                      Obx(
                        () => LinearProgressIndicator(
                          value: (controller.healthReadingsCount.value < 1
                              ? 0
                              : controller.healthReadingsCount.value / 100),
                          backgroundColor: Colors.grey.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF97CF43),
                          ),
                        ),
                      ),
                      // Health Readings Info
                      if (controller.healthReadingsCount.value > 0)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
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
                        ),

                      if (controller.healthReadingsCount.value > 0)
                        const SizedBox(height: 20),

                      _capacityRow(
                        "Designated Capacity",
                        controller.designedCapacityMah.value < 1
                            ? "--"
                            : controller.designedCapacityMah.value.toString(),
                      ),
                      _capacityRow(
                        "Estimated Capacity",
                        controller.estimatedCapacityMah.value < 1
                            ? "--"
                            : controller.estimatedCapacityMah.value.toString(),
                      ),
                    ],
                  ),
                ),
              ),

              // Battery Card
              Obx(() => _buildBatteryCard()),
              const SizedBox(height: 20),
              // Battery Info
              Obx(() => _buildBatteryInfo()),
              const SizedBox(height: 24),
              // Battery Health Section
              Obx(() => _buildBatteryHealthSection()),
            ],
          ),
        ),
      ),
    );
  }

  Row _capacityRow(label, value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 15.0),
          child: Text(
            label,
            style: TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        Padding(padding: const EdgeInsets.only(top: 15.0), child: Text(value)),
      ],
    );
  }

  Row _buildStateRow(title, value, screenHeight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Color(0xFF282828),
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          width: 150,
          height: screenHeight * 0.06,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: AppColors.secondaryColor,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Center(
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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
        if (isCharging) const Icon(Icons.bolt, color: Colors.white, size: 40),
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

  Widget _buildBatteryHealthSection() {
    final healthPercent = controller.batteryHealthPercent.value;
    final estimatedCapacity = controller.estimatedCapacityMah.value;
    final designedCapacity = controller.designedCapacityMah.value;
    final isCalculating = controller.healthCalculationInProgress.value;
    final progress = controller.healthCalculationProgress.value;
    final isCharging = controller.isPhoneCharging.value;
    final batteryLevel = controller.phoneBatteryLevel.value;
    final healthReadingsCount = controller.healthReadingsCount.value;
    final totalEstimatedValues = controller.totalEstimatedValues.value;

    Color healthColor;
    String healthStatus;
    if (healthPercent < 0) {
      healthColor = Colors.grey;
      healthStatus = 'Not calculated';
    } else if (healthPercent >= 80) {
      healthColor = Colors.green;
      healthStatus = 'Good';
    } else if (healthPercent >= 50) {
      healthColor = Colors.orange;
      healthStatus = 'Fair';
    } else {
      healthColor = Colors.red;
      healthStatus = 'Poor';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Battery Health',
            style: TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Health Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  healthColor.withOpacity(0.1),
                  healthColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: healthColor.withOpacity(0.3)),
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
                          'Health',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          healthPercent < 0
                              ? '--'
                              : '${healthPercent.toInt()}%',
                          style: TextStyle(
                            color: healthColor,
                            fontFamily: 'Inter',
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          healthStatus,
                          style: TextStyle(
                            color: healthColor,
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.health_and_safety, color: healthColor, size: 60),
                  ],
                ),

                if (isCalculating) ...[
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Calculating...',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$progress%',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Capacity Info
          _buildInfoTile(
            icon: Icons.battery_std,
            iconColor: AppColors.primaryColor,
            title: 'Designed Capacity',
            value: designedCapacity > 0 ? '$designedCapacity mAh' : 'Unknown',
          ),
          const SizedBox(height: 12),
          _buildInfoTile(
            icon: Icons.battery_full,
            iconColor: healthColor,
            title: 'Estimated Capacity',
            value: estimatedCapacity > 0
                ? '${estimatedCapacity.toInt()} mAh'
                : 'Not calculated',
          ),

          const SizedBox(height: 20),

          // Health Readings Info
          if (healthReadingsCount > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Text(
                'Health reading based on $healthReadingsCount charge cycles (${healthReadingsCount * 60}% charged) ${totalEstimatedValues.toInt()} mAh total',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (healthReadingsCount > 0) const SizedBox(height: 20),

          // Start/Stop Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isCalculating
                  ? controller.stopHealthCalculation
                  : (isCharging && batteryLevel <= 40)
                  ? controller.startHealthCalculation
                  : null,
              icon: Icon(isCalculating ? Icons.stop : Icons.play_arrow),
              label: Text(
                isCalculating
                    ? 'Stop Calculation'
                    : isCharging
                    ? (batteryLevel <= 40
                          ? 'Start Health Calculation'
                          : 'Battery too high (need ≤40%)')
                    : 'Plug in charger to calculate',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCalculating
                    ? Colors.red
                    : AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            'Note: Health calculation requires 60% charge increase. '
            'Keep device plugged in during calculation.',
            style: TextStyle(
              color: Colors.grey[600],
              fontFamily: 'Inter',
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
