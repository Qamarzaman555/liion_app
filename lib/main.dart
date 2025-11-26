import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app/routes/app_pages.dart';
import 'app/services/ble_scan_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request permissions and start service on Android
  if (Platform.isAndroid) {
    await _requestPermissionsAndStartService();
  }

  runApp(const MyApp());
}

Future<void> _requestPermissionsAndStartService() async {
  // Request BLE and notification permissions
  final statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
    Permission.notification,
  ].request();

  // Check if BLE permissions are granted
  if (statuses[Permission.bluetoothScan]!.isGranted &&
      statuses[Permission.bluetoothConnect]!.isGranted) {
    await BleScanService.startService();
    
    // Check and request battery optimization exemption
    _checkBatteryOptimization();
  }
}

Future<void> _checkBatteryOptimization() async {
  // Small delay to ensure service is started
  await Future.delayed(const Duration(seconds: 2));
  
  final isDisabled = await BleScanService.isBatteryOptimizationDisabled();
  if (!isDisabled) {
    // Request user to disable battery optimization
    await BleScanService.requestDisableBatteryOptimization();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Liion Power App',
      debugShowCheckedModeBanner: false,
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
