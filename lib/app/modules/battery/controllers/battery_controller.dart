import 'dart:async';
import 'package:get/get.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class BatteryController extends GetxController {
  final phoneBatteryLevel = (-1).obs;
  final isPhoneCharging = false.obs;

  StreamSubscription? _batterySubscription;

  @override
  void onInit() {
    super.onInit();
    _loadInitialBattery();
    _listenToBatteryUpdates();
  }

  Future<void> _loadInitialBattery() async {
    final batteryInfo = await BleScanService.getPhoneBattery();
    phoneBatteryLevel.value = batteryInfo.level;
    isPhoneCharging.value = batteryInfo.isCharging;
  }

  void _listenToBatteryUpdates() {
    _batterySubscription = BleScanService.phoneBatteryStream.listen((info) {
      phoneBatteryLevel.value = info.level;
      isPhoneCharging.value = info.isCharging;
    });
  }

  @override
  void onClose() {
    _batterySubscription?.cancel();
    super.onClose();
  }
}
