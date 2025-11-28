import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/leo_home_controller.dart';

class ChargeGraphWidget extends StatelessWidget {
  const ChargeGraphWidget({
    super.key,
    this.isCurrentCharge = true,
    this.height = 250,
    this.animationDuration = const Duration(milliseconds: 250),
  });

  final bool isCurrentCharge;
  final double height;
  final Duration animationDuration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Obx(
        () => LineChart(
          isCurrentCharge ? _getCurrentChargeData() : _getLastChargeData(),
          duration: animationDuration,
        ),
      ),
    );
  }

  LineChartData _getCurrentChargeData() {
    final controller = Get.find<LeoHomeController>();
    final points = controller.currentGraphPoints.toList();
    final spots = points
        .map((point) => FlSpot(point.seconds, point.current))
        .toList(growable: false);

    const stepSize = 0.1;
    const double minimumMaxY = 0.2;
    double maxDataValue = points.isEmpty
        ? 0.0
        : points.fold<double>(
            0,
            (previous, element) =>
                element.current > previous ? element.current : previous,
          );

    double interval;
    double finalMaxY;

    if (points.isEmpty) {
      finalMaxY = 0.5;
      interval = 0.1;
    } else {
      finalMaxY =
          ((max(maxDataValue, minimumMaxY) / stepSize).ceil() * stepSize)
              .toDouble();
      interval = finalMaxY <= 0.5 ? 0.1 : 0.5;
    }

    return LineChartData(
      lineTouchData: _lineTouchData,
      gridData: _gridData(interval),
      titlesData: _titlesData(interval, isCurrent: true),
      borderData: _borderData,
      lineBarsData: [_buildLineBarData(spots, const Color(0xFFFFBC00))],
      minX: controller.currentGraphXAxisMinLimit.value,
      maxX: controller.currentGraphXAxisLimit.value,
      maxY: finalMaxY,
      minY: 0.0,
      clipData: const FlClipData.all(),
    );
  }

  LineChartData _getLastChargeData() {
    final controller = Get.find<LeoHomeController>();
    final points = controller.lastChargeGraphPoints.toList();
    final spots = points
        .map((point) => FlSpot(point.seconds, point.current))
        .toList(growable: false);

    const stepSize = 0.1;
    const double minimumMaxY = 0.2;
    double maxDataValue = points.isEmpty
        ? 0.0
        : points.fold<double>(
            0,
            (previous, element) =>
                element.current > previous ? element.current : previous,
          );

    double interval;
    double finalMaxY;

    if (points.isEmpty) {
      finalMaxY = 0.5;
      interval = 0.1;
    } else {
      finalMaxY =
          ((max(maxDataValue, minimumMaxY) / stepSize).ceil() * stepSize)
              .toDouble();
      interval = finalMaxY <= 0.5 ? 0.1 : 0.5;
    }

    return LineChartData(
      lineTouchData: _lineTouchData,
      gridData: _gridData(interval),
      titlesData: _titlesData(interval, isCurrent: false),
      borderData: _borderData,
      lineBarsData: [_buildLineBarData(spots, const Color(0xFF01B2A8))],
      minX: controller.lastGraphXAxisMinLimit.value,
      maxX: controller.lastGraphXAxisLimit.value,
      maxY: finalMaxY,
      minY: 0,
      clipData: const FlClipData.all(),
    );
  }

  LineTouchData get _lineTouchData => LineTouchData(
    handleBuiltInTouches: true,
    touchTooltipData: LineTouchTooltipData(
      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
    ),
  );

  FlTitlesData _titlesData(double interval, {required bool isCurrent}) =>
      FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: isCurrent ? _bottomTitles : _bottomTitles2,
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: _leftTitles(interval)),
      );

  LineChartBarData _buildLineBarData(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      isCurved: false,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: false,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 4.0,
            color: Colors.white,
            strokeWidth: 2.0,
            strokeColor: const Color(0xFFFFBC00),
          );
        },
      ),
      belowBarData: BarAreaData(show: false, color: color.withOpacity(0.3)),
      spots: spots,
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.w400, fontSize: 10);
    final text = value.toStringAsFixed(1);
    return Text("$text A", style: style, textAlign: TextAlign.center);
  }

  SideTitles _leftTitles(double interval) => SideTitles(
    getTitlesWidget: _leftTitleWidgets,
    showTitles: true,
    interval: interval,
    reservedSize: 32,
  );

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.w400, fontSize: 10);
    final controller = Get.find<LeoHomeController>();
    final label = controller.formatTimeForBottomGraph(value);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      angle: 0,
      child: Text(label, style: style),
    );
  }

  Widget _bottomTitleWidgets2(double value, TitleMeta meta) {
    const style = TextStyle(fontWeight: FontWeight.w400, fontSize: 10);
    final controller = Get.find<LeoHomeController>();
    final label = controller.formatTimeForBottomGraph(value);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      angle: 0,
      child: Text(label, style: style),
    );
  }

  SideTitles get _bottomTitles {
    final controller = Get.find<LeoHomeController>();
    return SideTitles(
      showTitles: true,
      reservedSize: 32,
      interval: controller.currentGraphXAxisInterval.value,
      getTitlesWidget: _bottomTitleWidgets,
    );
  }

  SideTitles get _bottomTitles2 {
    final controller = Get.find<LeoHomeController>();
    return SideTitles(
      showTitles: true,
      reservedSize: 22,
      interval: controller.lastGraphXAxisInterval.value,
      getTitlesWidget: _bottomTitleWidgets2,
    );
  }

  FlGridData _gridData(double interval) => FlGridData(
    show: true,
    drawHorizontalLine: true,
    drawVerticalLine: false,
    horizontalInterval: interval,
    verticalInterval: 1,
    getDrawingHorizontalLine: (value) {
      return FlLine(
        color: Colors.black12,
        strokeWidth: 1,
        dashArray: value % interval == 0 ? null : [5],
      );
    },
    getDrawingVerticalLine: (value) {
      return value % 30 == 0
          ? const FlLine(color: Colors.black12, strokeWidth: 1, dashArray: [5])
          : const FlLine(color: Colors.transparent);
    },
  );

  FlBorderData get _borderData => FlBorderData(
    show: true,
    border: const Border(
      bottom: BorderSide(
        color: Colors.black12,
        width: 1,
        style: BorderStyle.solid,
      ),
      left: BorderSide(
        color: Colors.black12,
        width: 1,
        style: BorderStyle.solid,
      ),
      right: BorderSide(
        color: Colors.black12,
        width: 1,
        style: BorderStyle.solid,
      ),
      top: BorderSide(
        color: Colors.black12,
        width: 1,
        style: BorderStyle.solid,
      ),
    ),
  );
}
