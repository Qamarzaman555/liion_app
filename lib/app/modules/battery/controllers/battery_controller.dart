import 'dart:async';
import 'package:get/get.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class BatteryController extends GetxController {
  final phoneBatteryLevel = (-1).obs;
  final isPhoneCharging = false.obs;

  // Battery health
  final designedCapacityMah = 0.obs;
  final estimatedCapacityMah = 0.0.obs;
  final batteryHealthPercent = (-1.0).obs;
  final healthCalculationInProgress = false.obs;
  final healthCalculationProgress = 0.obs;
  final healthReadingsCount = 0.obs;
  final totalEstimatedValues = 0.0.obs;

  StreamSubscription? _batterySubscription;
  StreamSubscription? _healthSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadInitialBattery();
    _loadInitialHealth();
    _listenToBatteryUpdates();
    _listenToHealthUpdates();
  }

  Future<void> _loadInitialBattery() async {
    final batteryInfo = await BleScanService.getPhoneBattery();
    phoneBatteryLevel.value = batteryInfo.level;
    isPhoneCharging.value = batteryInfo.isCharging;
  }

  Future<void> _loadInitialHealth() async {
    final healthInfo = await BleScanService.getBatteryHealthInfo();
    _updateHealthInfo(healthInfo);
  }

  void _listenToBatteryUpdates() {
    _batterySubscription = BleScanService.phoneBatteryStream.listen((info) {
      phoneBatteryLevel.value = info.level;
      isPhoneCharging.value = info.isCharging;
    });
  }

  void _listenToHealthUpdates() {
    _healthSubscription = BleScanService.batteryHealthStream.listen((info) {
      _updateHealthInfo(info);
    });
  }

  void _updateHealthInfo(BatteryHealthInfo info) {
    designedCapacityMah.value = info.designedCapacityMah;
    estimatedCapacityMah.value = info.estimatedCapacityMah;
    batteryHealthPercent.value = info.batteryHealthPercent;
    healthCalculationInProgress.value = info.calculationInProgress;
    healthCalculationProgress.value = info.calculationProgress;
    healthReadingsCount.value = info.healthReadingsCount;
    totalEstimatedValues.value = info.totalEstimatedValues;
  }

  Future<void> startHealthCalculation() async {
    final success = await BleScanService.startBatteryHealthCalculation();
    if (!success) {
      Get.snackbar(
        'Cannot Start',
        'Device must be charging and battery below 40%',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> stopHealthCalculation() async {
    await BleScanService.stopBatteryHealthCalculation();
  }

  @override
  void onClose() {
    _batterySubscription?.cancel();
    _healthSubscription?.cancel();
    super.onClose();
  }
}
