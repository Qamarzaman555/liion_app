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

  static Stream<Map<String, String>>? _deviceStream;
  static Stream<Map<String, dynamic>>? _connectionStream;
  static Stream<int>? _adapterStateStream;

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

  /// Connect to a BLE device (handled by foreground service)
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

  /// Disconnect from the connected device (handled by foreground service)
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

  /// Get all scanned devices (Leo Usb filtered)
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

  /// Stream of connection state changes (from foreground service)
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
}
