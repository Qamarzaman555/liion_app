import 'dart:async';
import 'package:flutter/services.dart';

/// iOS BLE Scan Service
/// Handles all iOS-specific BLE operations via native Swift BLEService
class IOSBleScanService {
  /// iOS Method Channel (communicates with BackgroundServiceChannel.swift)
  static const MethodChannel _channel = MethodChannel(
    'com.liion.app/background_service',
  );

  // Stream controllers for iOS (polling-based)
  static Timer? _scanTimer;
  static StreamController<Map<String, String>>? _deviceStreamController;
  static StreamController<Map<String, dynamic>>? _connectionStreamController;
  static StreamController<int>? _adapterStateStreamController;

  // Track previous states for change detection
  static Set<String> _previousDeviceIds = {};
  static bool _previousConnectionState = false;
  static bool _previousBluetoothState = false;

  // ============================================================================
  // SERVICE LIFECYCLE
  // ============================================================================

  /// Start iOS BLE service (automatically starts, no foreground service needed)
  static Future<bool> startService() async {
    try {
      await _channel.invokeMethod('startService');
      return true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to start BLE service: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // BLUETOOTH STATE
  // ============================================================================

  /// Get Bluetooth state
  static Future<String> getBluetoothState() async {
    try {
      final result = await _channel.invokeMethod<String>('getBluetoothState');
      return result ?? 'unknown';
    } on PlatformException catch (e) {
      print('[iOS] Failed to get Bluetooth state: ${e.message}');
      return 'unknown';
    }
  }

  /// Check if Bluetooth is enabled
  static Future<bool> isBluetoothEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isBluetoothEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to check Bluetooth: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // SCANNING
  // ============================================================================

  /// Start BLE scan
  static Future<bool> startScan() async {
    try {
      await _channel.invokeMethod('startScan');
      return true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to start scan: ${e.message}');
      return false;
    }
  }

  /// Stop BLE scan
  static Future<bool> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
      return true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to stop scan: ${e.message}');
      return false;
    }
  }

  /// Get discovered devices
  static Future<List<Map<String, String>>> getDiscoveredDevices() async {
    try {
      final result = await _channel.invokeMethod<List>('getDiscoveredDevices');
      if (result == null) return [];

      return result.map((device) {
        final map = Map<String, dynamic>.from(device as Map);
        return <String, String>{
          'name': map['name']?.toString() ?? 'Unknown',
          'address': map['id']?.toString() ?? '',
        };
      }).toList();
    } on PlatformException catch (e) {
      print('[iOS] Failed to get devices: ${e.message}');
      return [];
    }
  }

  /// Rescan (stop + start)
  static Future<bool> rescan() async {
    await stopScan();
    await Future.delayed(const Duration(milliseconds: 500));
    return await startScan();
  }

  // ============================================================================
  // CONNECTION
  // ============================================================================

  /// Connect to device
  static Future<bool> connect(String deviceId) async {
    try {
      final result = await _channel.invokeMethod<Map>('connectToDevice', {
        'deviceId': deviceId,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to connect: ${e.message}');
      return false;
    }
  }

  /// Disconnect from device
  static Future<bool> disconnect() async {
    try {
      final result = await _channel.invokeMethod<Map>('disconnectFromDevice');
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to disconnect: ${e.message}');
      return false;
    }
  }

  /// Check if connected
  static Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to check connection: ${e.message}');
      return false;
    }
  }

  /// Get connected device
  static Future<Map<String, String>?> getConnectedDevice() async {
    try {
      final result = await _channel.invokeMethod<Map>('getConnectedDevice');
      if (result == null) return null;

      return <String, String>{
        'name': result['name']?.toString() ?? 'Unknown',
        'address': result['id']?.toString() ?? '',
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to get connected device: ${e.message}');
      return null;
    }
  }

  // ============================================================================
  // AUTO-CONNECT
  // ============================================================================

  /// Enable/disable auto-connect
  static Future<bool> setAutoConnectEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setAutoConnectEnabled', {
        'enabled': enabled,
      });
      return true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to set auto-connect: ${e.message}');
      return false;
    }
  }

  /// Check if auto-connect is enabled
  static Future<bool> isAutoConnectEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAutoConnectEnabled');
      return result ?? true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to check auto-connect: ${e.message}');
      return true;
    }
  }

  /// Get last connected device
  static Future<Map<String, String>?> getLastConnectedDevice() async {
    try {
      final result = await _channel.invokeMethod<Map>('getLastConnectedDevice');
      if (result == null) return null;

      return <String, String>{
        'name': result['name']?.toString() ?? 'Unknown',
        'address': result['id']?.toString() ?? '',
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to get last connected device: ${e.message}');
      return null;
    }
  }

  /// Clear last connected device
  static Future<bool> clearLastConnectedDevice() async {
    try {
      await _channel.invokeMethod('clearLastConnectedDevice');
      return true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to clear last connected device: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // STREAMS (Polling-based for iOS)
  // ============================================================================

  /// Stream of discovered devices (polls every 2 seconds)
  static Stream<Map<String, String>> getDeviceStream() {
    _deviceStreamController ??=
        StreamController<Map<String, String>>.broadcast();

    // Start polling if not already started
    _scanTimer ??= Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final devices = await getDiscoveredDevices();

        // Only emit new devices
        for (final device in devices) {
          final deviceId = device['address'] ?? '';
          if (deviceId.isNotEmpty && !_previousDeviceIds.contains(deviceId)) {
            _previousDeviceIds.add(deviceId);
            _deviceStreamController?.add(device);
          }
        }
      } catch (e) {
        print('[iOS] Error polling devices: $e');
      }
    });

    return _deviceStreamController!.stream;
  }

  /// Stream of connection state changes (polls every 1 second)
  static Stream<Map<String, dynamic>> getConnectionStream() {
    _connectionStreamController ??=
        StreamController<Map<String, dynamic>>.broadcast();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final connected = await isConnected();

        // Emit state changes
        if (connected != _previousConnectionState) {
          _previousConnectionState = connected;

          final device = await getConnectedDevice();
          _connectionStreamController?.add({
            'state': connected ? 2 : 0, // connected : disconnected
            'address': device?['address'],
          });
        }
      } catch (e) {
        print('[iOS] Error polling connection: $e');
      }
    });

    return _connectionStreamController!.stream;
  }

  /// Stream of Bluetooth adapter state changes (polls every 2 seconds)
  static Stream<int> getAdapterStateStream() {
    _adapterStateStreamController ??= StreamController<int>.broadcast();

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final enabled = await isBluetoothEnabled();

        // Emit state changes
        if (enabled != _previousBluetoothState) {
          _previousBluetoothState = enabled;
          _adapterStateStreamController?.add(enabled ? 2 : 0); // on : off
        }
      } catch (e) {
        print('[iOS] Error polling Bluetooth state: $e');
      }
    });

    return _adapterStateStreamController!.stream;
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Dispose all streams and timers
  static void dispose() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _deviceStreamController?.close();
    _deviceStreamController = null;
    _connectionStreamController?.close();
    _connectionStreamController = null;
    _adapterStateStreamController?.close();
    _adapterStateStreamController = null;
    _previousDeviceIds.clear();
  }
}
