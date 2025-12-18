import 'dart:async';
import 'dart:io' show Platform;
import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/services/ios_ble_scan_service.dart';

class BatteryController extends GetxController {
  final phoneBatteryLevel = (-1).obs;
  final isPhoneCharging = false.obs;

  // Real-time battery metrics from foreground service
  final batteryCurrent = 0.0.obs; // mA
  final batteryVoltage = 0.0.obs; // V
  final batteryTemperature = 0.0.obs; // °C
  final accumulatedMah = 0.0.obs; // mAh - resets on charging state change
  final chargingTimeSeconds = 0.obs; // seconds - time spent charging
  final dischargingTimeSeconds = 0.obs; // seconds - time spent discharging

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
  StreamSubscription? _batteryMetricsSubscription;
  bool? _lastChargingState;

  @override
  void onInit() {
    super.onInit();
    _loadInitialBattery();
    _loadInitialHealth();
    _listenToBatteryUpdates();
    _listenToHealthUpdates();
    _listenToBatteryMetrics();
  }

  Future<void> _loadInitialBattery() async {
    if (Platform.isIOS) {
      final batteryInfo = await IOSBleScanService.getPhoneBattery();
      phoneBatteryLevel.value = batteryInfo['level'] as int? ?? -1;
      isPhoneCharging.value = batteryInfo['isCharging'] as bool? ?? false;
    } else {
      final batteryInfo = await BleScanService.getPhoneBattery();
      phoneBatteryLevel.value = batteryInfo.level;
      isPhoneCharging.value = batteryInfo.isCharging;
    }
  }

  Future<void> _loadInitialHealth() async {
    // iOS: Battery health not supported - skip loading
    if (Platform.isIOS) return;

    final healthInfo = await BleScanService.getBatteryHealthInfo();
    _updateHealthInfo(healthInfo);
  }

  void _listenToBatteryUpdates() {
    // iOS: Battery updates managed via UIDevice notifications in native layer
    // Android: Use stream subscription
    if (Platform.isAndroid) {
      _batterySubscription = BleScanService.phoneBatteryStream.listen((info) {
        // Check if charging state changed - reset accumulated mAh
        if (_lastChargingState != null &&
            _lastChargingState != info.isCharging) {
          accumulatedMah.value = 0.0;
        }
        _lastChargingState = info.isCharging;

        phoneBatteryLevel.value = info.level;
        isPhoneCharging.value = info.isCharging;
      });
    }
  }

  void _listenToBatteryMetrics() {
    // iOS: Battery metrics not available - only level and charging state from UIDevice
    // Android: Use EventChannel stream for detailed metrics
    if (Platform.isAndroid) {
      _batteryMetricsSubscription = BleScanService.batteryMetricsStream.listen((
        metrics,
      ) {
        batteryCurrent.value = metrics.current;
        batteryVoltage.value = metrics.voltage;
        batteryTemperature.value = metrics.temperature;
        accumulatedMah.value = metrics.accumulatedMah;
        chargingTimeSeconds.value = metrics.chargingTimeSeconds;
        dischargingTimeSeconds.value = metrics.dischargingTimeSeconds;
      });
    }
  }

  void _listenToHealthUpdates() {
    // iOS: Battery health calculation not implemented yet
    // Android: Use stream subscription
    if (Platform.isAndroid) {
      _healthSubscription = BleScanService.batteryHealthStream.listen((info) {
        _updateHealthInfo(info);
      });
    }
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
    // iOS: Battery health calculation not implemented yet
    if (Platform.isIOS) {
      return;
    }

    final success = await BleScanService.startBatteryHealthCalculation();
    if (!success) {
      AppSnackbars.showSuccess(
        title: 'Cannot Start',
        message: 'Device must be charging and battery below 40%',
      );
    }
  }

  Future<void> stopHealthCalculation() async {
    // iOS: Battery health calculation not implemented yet
    if (Platform.isIOS) return;

    await BleScanService.stopBatteryHealthCalculation();
  }

  Future<void> resetHealthReadings() async {
    // iOS: Battery health calculation not implemented yet
    if (Platform.isIOS) return;

    final success = await BleScanService.resetBatteryHealthReadings();
    if (success) {
      // Reload health info to reflect the reset
      await _loadInitialHealth();
      AppSnackbars.showSuccess(
        title: 'Success',
        message: 'Battery health readings reset',
      );
    } else {
      AppSnackbars.showSuccess(
        title: 'Error',
        message: 'Failed to reset battery health readings',
      );
    }
  }

  @override
  void onClose() {
    _batterySubscription?.cancel();
    _healthSubscription?.cancel();
    _batteryMetricsSubscription?.cancel();
    super.onClose();
  }
}
