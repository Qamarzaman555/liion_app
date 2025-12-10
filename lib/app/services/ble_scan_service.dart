import 'dart:async';
import 'package:flutter/services.dart';

class BleConnectionState {
  static const int disconnected = 0;
  static const int connecting = 1;
  static const int connected = 2;
}

class BleAdapterState {
  static const int off = 0;
  static const int turningOn = 1;
  static const int on = 2;
  static const int turningOff = 3;

  static String getName(int state) {
    switch (state) {
      case off:
        return 'Off';
      case turningOn:
        return 'Turning On';
      case on:
        return 'On';
      case turningOff:
        return 'Turning Off';
      default:
        return 'Unknown';
    }
  }
}

class PhoneBatteryInfo {
  final int level;
  final bool isCharging;

  PhoneBatteryInfo({required this.level, required this.isCharging});

  factory PhoneBatteryInfo.fromMap(Map<String, dynamic> map) {
    return PhoneBatteryInfo(
      level: map['level'] as int? ?? -1,
      isCharging: map['isCharging'] as bool? ?? false,
    );
  }
}

class ChargeLimitInfo {
  final int limit;
  final bool enabled;
  final bool confirmed;

  ChargeLimitInfo({
    required this.limit,
    required this.enabled,
    required this.confirmed,
  });

  factory ChargeLimitInfo.fromMap(Map<String, dynamic> map) {
    return ChargeLimitInfo(
      limit: map['limit'] as int? ?? 90,
      enabled: map['enabled'] as bool? ?? false,
      confirmed: map['confirmed'] as bool? ?? false,
    );
  }
}

class AdvancedModes {
  final bool ghostMode;
  final bool silentMode;
  final bool higherChargeLimit;

  AdvancedModes({
    required this.ghostMode,
    required this.silentMode,
    required this.higherChargeLimit,
  });

  factory AdvancedModes.fromMap(Map<dynamic, dynamic> map) {
    return AdvancedModes(
      ghostMode: map['ghostMode'] as bool? ?? false,
      silentMode: map['silentMode'] as bool? ?? false,
      higherChargeLimit: map['higherChargeLimit'] as bool? ?? false,
    );
  }
}

class BatteryHealthInfo {
  final int designedCapacityMah;
  final double estimatedCapacityMah;
  final double batteryHealthPercent;
  final bool calculationInProgress;
  final int calculationStartPercent;
  final int calculationProgress;
  final int healthReadingsCount;
  final double totalEstimatedValues;

  BatteryHealthInfo({
    required this.designedCapacityMah,
    required this.estimatedCapacityMah,
    required this.batteryHealthPercent,
    required this.calculationInProgress,
    required this.calculationStartPercent,
    required this.calculationProgress,
    required this.healthReadingsCount,
    required this.totalEstimatedValues,
  });

  factory BatteryHealthInfo.fromMap(Map<dynamic, dynamic> map) {
    return BatteryHealthInfo(
      designedCapacityMah: (map['designedCapacityMah'] as num?)?.toInt() ?? 0,
      estimatedCapacityMah:
          (map['estimatedCapacityMah'] as num?)?.toDouble() ?? 0.0,
      batteryHealthPercent:
          (map['batteryHealthPercent'] as num?)?.toDouble() ?? -1.0,
      calculationInProgress: map['calculationInProgress'] as bool? ?? false,
      calculationStartPercent:
          (map['calculationStartPercent'] as num?)?.toInt() ?? -1,
      calculationProgress: (map['calculationProgress'] as num?)?.toInt() ?? 0,
      healthReadingsCount: (map['healthReadingsCount'] as num?)?.toInt() ?? 0,
      totalEstimatedValues:
          (map['totalEstimatedValues'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MeasureData {
  final String voltage;
  final String current;

  MeasureData({required this.voltage, required this.current});

  factory MeasureData.fromMap(Map<dynamic, dynamic> map) {
    return MeasureData(
      voltage: map['voltage'] as String? ?? '',
      current: map['current'] as String? ?? '',
    );
  }
}

class BatteryMetrics {
  final double current; // mA
  final double voltage; // V
  final double temperature; // °C
  final double accumulatedMah; // mAh - resets on charging state change
  final int chargingTimeSeconds; // seconds - time spent charging
  final int dischargingTimeSeconds; // seconds - time spent discharging

  BatteryMetrics({
    required this.current,
    required this.voltage,
    required this.temperature,
    required this.accumulatedMah,
    required this.chargingTimeSeconds,
    required this.dischargingTimeSeconds,
  });

  factory BatteryMetrics.fromMap(Map<dynamic, dynamic> map) {
    return BatteryMetrics(
      current: (map['current'] as num?)?.toDouble() ?? 0.0,
      voltage: (map['voltage'] as num?)?.toDouble() ?? 0.0,
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.0,
      accumulatedMah: (map['accumulatedMah'] as num?)?.toDouble() ?? 0.0,
      chargingTimeSeconds: (map['chargingTimeSeconds'] as num?)?.toInt() ?? 0,
      dischargingTimeSeconds:
          (map['dischargingTimeSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class BleScanService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.liion_app/ble_service',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.liion_app/ble_devices',
  );
  static const EventChannel _connectionEventChannel = EventChannel(
    'com.liion_app/ble_connection',
  );
  static const EventChannel _adapterStateChannel = EventChannel(
    'com.liion_app/adapter_state',
  );
  static const EventChannel _dataReceivedChannel = EventChannel(
    'com.liion_app/data_received',
  );
  static const EventChannel _batteryChannel = EventChannel(
    'com.liion_app/phone_battery',
  );
  static const EventChannel _chargeLimitChannel = EventChannel(
    'com.liion_app/charge_limit',
  );
  static const EventChannel _ledTimeoutChannel = EventChannel(
    'com.liion_app/led_timeout',
  );
  static const EventChannel _advancedModesChannel = EventChannel(
    'com.liion_app/advanced_modes',
  );
  static const EventChannel _batteryHealthChannel = EventChannel(
    'com.liion_app/battery_health',
  );
  static const EventChannel _measureDataChannel = EventChannel(
    'com.liion_app/measure_data',
  );
  static const EventChannel _batteryMetricsChannel = EventChannel(
    'com.liion_app/battery_metrics',
  );
  static const EventChannel _otaProgressChannel = EventChannel(
    'com.liion_app/ota_progress',
  );

  static Stream<Map<String, String>>? _deviceStream;
  static Stream<Map<String, dynamic>>? _connectionStream;
  static Stream<int>? _adapterStateStream;
  static Stream<String>? _dataReceivedStream;
  static Stream<PhoneBatteryInfo>? _batteryStream;
  static Stream<ChargeLimitInfo>? _chargeLimitStream;
  static Stream<AdvancedModes>? _advancedModesStream;
  static Stream<int>? _ledTimeoutStream;
  static Stream<BatteryHealthInfo>? _batteryHealthStream;
  static Stream<MeasureData>? _measureDataStream;
  static Stream<BatteryMetrics>? _batteryMetricsStream;
  static Stream<Map<String, dynamic>>? _otaProgressStream;

  /// Start the foreground BLE scan service
  static Future<bool> startService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to start BLE service: ${e.message}');
      return false;
    }
  }

  /// Stop the foreground BLE scan service
  static Future<bool> stopService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopService');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to stop BLE service: ${e.message}');
      return false;
    }
  }

  /// Clear devices and restart scan
  static Future<bool> rescan() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('rescan');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to rescan: ${e.message}');
      return false;
    }
  }

  /// Check if Bluetooth is enabled
  static Future<bool> isBluetoothEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isBluetoothEnabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check Bluetooth status: ${e.message}');
      return false;
    }
  }

  /// Get current adapter state
  static Future<int> getAdapterState() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getAdapterState');
      return result ?? BleAdapterState.off;
    } on PlatformException catch (e) {
      print('Failed to get adapter state: ${e.message}');
      return BleAdapterState.off;
    }
  }

  /// Request to enable Bluetooth
  static Future<bool> requestEnableBluetooth() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestEnableBluetooth',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to request Bluetooth enable: ${e.message}');
      return false;
    }
  }

  /// Connect to a BLE device
  static Future<bool> connect(String address) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('connect', {
        'address': address,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to connect: ${e.message}');
      return false;
    }
  }

  /// Disconnect from the connected device
  static Future<bool> disconnect() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('disconnect');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to disconnect: ${e.message}');
      return false;
    }
  }

  /// Check if connected to a device
  static Future<bool> isConnected() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check connection: ${e.message}');
      return false;
    }
  }

  /// Get current connection state
  static Future<int> getConnectionState() async {
    try {
      final result = await _methodChannel.invokeMethod<int>(
        'getConnectionState',
      );
      return result ?? BleConnectionState.disconnected;
    } on PlatformException catch (e) {
      print('Failed to get connection state: ${e.message}');
      return BleConnectionState.disconnected;
    }
  }

  /// Get connected device address
  static Future<String?> getConnectedDeviceAddress() async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'getConnectedDeviceAddress',
      );
      return result;
    } on PlatformException catch (e) {
      print('Failed to get connected device: ${e.message}');
      return null;
    }
  }

  /// Send command to Leo device
  static Future<bool> sendCommand(String command) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('sendCommand', {
        'command': command,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to send command: ${e.message}');
      return false;
    }
  }

  /// Get the last known LED timeout (seconds) from the service cache.
  static Future<int> getLedTimeout() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getLedTimeout');
      return result ?? 300;
    } on PlatformException catch (e) {
      print('Failed to get LED timeout: ${e.message}');
      return 300;
    }
  }

  /// Request the service to fetch the LED timeout from the device.
  static Future<bool> requestLedTimeout() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestLedTimeout',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to request LED timeout: ${e.message}');
      return false;
    }
  }

  /// Update the LED timeout on the device via the service.
  static Future<bool> setLedTimeout(int seconds) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setLedTimeout', {
        'seconds': seconds,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set LED timeout: ${e.message}');
      return false;
    }
  }

  /// Get the latest advanced modes state from the service cache.
  static Future<AdvancedModes> getAdvancedModes() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getAdvancedModes');
      if (result == null) {
        return AdvancedModes(
          ghostMode: false,
          silentMode: false,
          higherChargeLimit: false,
        );
      }
      return AdvancedModes.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      print('Failed to get advanced modes: ${e.message}');
      return AdvancedModes(
        ghostMode: false,
        silentMode: false,
        higherChargeLimit: false,
      );
    }
  }

  /// Toggle ghost mode via the foreground service.
  static Future<bool> setGhostMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setGhostMode', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set ghost mode: ${e.message}');
      return false;
    }
  }

  /// Toggle silent mode via the foreground service.
  static Future<bool> setSilentMode(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setSilentMode', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set silent mode: ${e.message}');
      return false;
    }
  }

  /// Toggle higher charge limit via the foreground service.
  static Future<bool> setHigherChargeLimit(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setHigherChargeLimit',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set higher charge limit: ${e.message}');
      return false;
    }
  }

  /// Ask the service to re-query advanced modes from the device.
  static Future<bool> requestAdvancedModes() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'requestAdvancedModes',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to request advanced modes: ${e.message}');
      return false;
    }
  }

  /// Get phone battery info
  static Future<PhoneBatteryInfo> getPhoneBattery() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getPhoneBattery');
      if (result == null) {
        return PhoneBatteryInfo(level: -1, isCharging: false);
      }
      return PhoneBatteryInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      print('Failed to get phone battery: ${e.message}');
      return PhoneBatteryInfo(level: -1, isCharging: false);
    }
  }

  /// Set charge limit
  static Future<bool> setChargeLimit(int limit, bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setChargeLimit', {
        'limit': limit,
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set charge limit: ${e.message}');
      return false;
    }
  }

  /// Get charge limit info
  static Future<ChargeLimitInfo> getChargeLimit() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('getChargeLimit');
      if (result == null) {
        return ChargeLimitInfo(limit: 90, enabled: false, confirmed: false);
      }
      return ChargeLimitInfo.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      print('Failed to get charge limit: ${e.message}');
      return ChargeLimitInfo(limit: 90, enabled: false, confirmed: false);
    }
  }

  /// Enable or disable charge limit (saved to SharedPrefs, sends command immediately)
  static Future<bool> setChargeLimitEnabled(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'setChargeLimitEnabled',
        {'enabled': enabled},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set charge limit enabled: ${e.message}');
      return false;
    }
  }

  /// Check if battery optimization is disabled for this app
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isBatteryOptimizationDisabled',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check battery optimization: ${e.message}');
      return false;
    }
  }

  /// Request user to disable battery optimization for this app
  static Future<void> requestDisableBatteryOptimization() async {
    try {
      await _methodChannel.invokeMethod('requestDisableBatteryOptimization');
    } on PlatformException catch (e) {
      print('Failed to request battery optimization disable: ${e.message}');
    }
  }

  /// Get battery health info
  static Future<BatteryHealthInfo> getBatteryHealthInfo() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>(
        'getBatteryHealthInfo',
      );
      if (result == null) {
        return BatteryHealthInfo(
          designedCapacityMah: 0,
          estimatedCapacityMah: 0,
          batteryHealthPercent: -1,
          calculationInProgress: false,
          calculationStartPercent: -1,
          calculationProgress: 0,
          healthReadingsCount: 0,
          totalEstimatedValues: 0,
        );
      }
      return BatteryHealthInfo.fromMap(result);
    } on PlatformException catch (e) {
      print('Failed to get battery health info: ${e.message}');
      return BatteryHealthInfo(
        designedCapacityMah: 0,
        estimatedCapacityMah: 0,
        batteryHealthPercent: -1,
        calculationInProgress: false,
        calculationStartPercent: -1,
        calculationProgress: 0,
        healthReadingsCount: 0,
        totalEstimatedValues: 0,
      );
    }
  }

  /// Start battery health calculation
  static Future<bool> startBatteryHealthCalculation() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'startBatteryHealthCalculation',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to start battery health calculation: ${e.message}');
      return false;
    }
  }

  /// Stop battery health calculation
  static Future<void> stopBatteryHealthCalculation() async {
    try {
      await _methodChannel.invokeMethod('stopBatteryHealthCalculation');
    } on PlatformException catch (e) {
      print('Failed to stop battery health calculation: ${e.message}');
    }
  }

  /// Stream of battery health updates
  static Stream<BatteryHealthInfo> get batteryHealthStream {
    _batteryHealthStream ??= _batteryHealthChannel.receiveBroadcastStream().map(
      (event) => BatteryHealthInfo.fromMap(event as Map),
    );
    return _batteryHealthStream!;
  }

  /// Stream of measure data (voltage and current from Leo device)
  static Stream<MeasureData> get measureDataStream {
    _measureDataStream ??= _measureDataChannel.receiveBroadcastStream().map(
      (event) => MeasureData.fromMap(event as Map),
    );
    return _measureDataStream!;
  }

  /// Stream of battery metrics (current, voltage, temperature, accumulated mAh)
  /// Updated every second from foreground service
  static Stream<BatteryMetrics> get batteryMetricsStream {
    _batteryMetricsStream ??= _batteryMetricsChannel
        .receiveBroadcastStream()
        .map((event) => BatteryMetrics.fromMap(event as Map));
    return _batteryMetricsStream!;
  }

  /// Get all scanned devices
  static Future<List<Map<String, String>>> getScannedDevices() async {
    try {
      final result = await _methodChannel.invokeMethod<List>(
        'getScannedDevices',
      );
      if (result == null) return [];
      return result.map((e) => Map<String, String>.from(e as Map)).toList();
    } on PlatformException catch (e) {
      print('Failed to get scanned devices: ${e.message}');
      return [];
    }
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isServiceRunning',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check service status: ${e.message}');
      return false;
    }
  }

  /// Stream of newly discovered devices
  static Stream<Map<String, String>> get deviceStream {
    _deviceStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, String>.from(event as Map);
    });
    return _deviceStream!;
  }

  /// Stream of connection state changes
  static Stream<Map<String, dynamic>> get connectionStream {
    _connectionStream ??= _connectionEventChannel.receiveBroadcastStream().map((
      event,
    ) {
      return Map<String, dynamic>.from(event as Map);
    });
    return _connectionStream!;
  }

  /// Stream of adapter state changes
  static Stream<int> get adapterStateStream {
    _adapterStateStream ??= _adapterStateChannel.receiveBroadcastStream().map((
      event,
    ) {
      return event as int;
    });
    return _adapterStateStream!;
  }

  /// Stream of data received from Leo device
  static Stream<String> get dataReceivedStream {
    _dataReceivedStream ??= _dataReceivedChannel.receiveBroadcastStream().map((
      event,
    ) {
      return event as String;
    });
    return _dataReceivedStream!;
  }

  /// Stream of phone battery updates
  static Stream<PhoneBatteryInfo> get phoneBatteryStream {
    _batteryStream ??= _batteryChannel.receiveBroadcastStream().map((event) {
      return PhoneBatteryInfo.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _batteryStream!;
  }

  /// Stream of charge limit updates
  static Stream<ChargeLimitInfo> get chargeLimitStream {
    _chargeLimitStream ??= _chargeLimitChannel.receiveBroadcastStream().map((
      event,
    ) {
      return ChargeLimitInfo.fromMap(Map<String, dynamic>.from(event as Map));
    });
    return _chargeLimitStream!;
  }

  /// Stream of LED timeout updates from the service
  static Stream<int> get ledTimeoutStream {
    _ledTimeoutStream ??= _ledTimeoutChannel.receiveBroadcastStream().map((
      event,
    ) {
      return event as int;
    });
    return _ledTimeoutStream!;
  }

  /// Stream of advanced mode updates (ghost, silent, higher charge limit)
  static Stream<AdvancedModes> get advancedModesStream {
    _advancedModesStream ??= _advancedModesChannel.receiveBroadcastStream().map(
      (event) {
        return AdvancedModes.fromMap(Map<String, dynamic>.from(event as Map));
      },
    );
    return _advancedModesStream!;
  }

  /// Get battery session history
  static Future<List<Map<String, dynamic>>> getBatterySessionHistory() async {
    try {
      final result = await _methodChannel.invokeMethod<List>(
        'getBatterySessionHistory',
      );
      if (result == null) return [];
      return result.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on PlatformException catch (e) {
      print('Failed to get battery session history: ${e.message}');
      return [];
    }
  }

  /// Clear battery session history
  static Future<bool> clearBatterySessionHistory() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'clearBatterySessionHistory',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to clear battery session history: ${e.message}');
      return false;
    }
  }

  /// Start OTA update
  static Future<bool> startOtaUpdate(String filePath) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startOtaUpdate', {
        'filePath': filePath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to start OTA update: ${e.message}');
      return false;
    }
  }

  /// Cancel OTA update
  static Future<bool> cancelOtaUpdate() async {
    try {
      await _methodChannel.invokeMethod('cancelOtaUpdate');
      return true;
    } on PlatformException catch (e) {
      print('Failed to cancel OTA update: ${e.message}');
      return false;
    }
  }

  /// Get OTA progress
  static Future<int> getOtaProgress() async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getOtaProgress');
      return result ?? 0;
    } on PlatformException catch (e) {
      print('Failed to get OTA progress: ${e.message}');
      return 0;
    }
  }

  /// Check if OTA update is in progress
  static Future<bool> isOtaUpdateInProgress() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isOtaUpdateInProgress',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check OTA status: ${e.message}');
      return false;
    }
  }

  /// Stream of OTA progress updates
  static Stream<Map<String, dynamic>> get otaProgressStream {
    _otaProgressStream ??= _otaProgressChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
    return _otaProgressStream!;
  }
}
