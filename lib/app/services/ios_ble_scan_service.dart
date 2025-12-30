import 'dart:async';
import 'package:flutter/services.dart';

/// iOS BLE Scan Service
/// Handles all iOS-specific BLE operations via native Swift BLEService
class IOSBleScanService {
  /// iOS Method Channel (communicates with BackgroundServiceChannel.swift)
  static const MethodChannel _channel = MethodChannel(
    'nl.liionpower.app/background_service',
  );

  // Stream controllers for iOS (polling-based)
  static Timer? _scanTimer;
  static Timer? _measureDataTimer;
  static Timer? _dataReceivedTimer;
  static Timer? _advancedModesTimer;
  static StreamController<Map<String, String>>? _deviceStreamController;
  static StreamController<Map<String, dynamic>>? _connectionStreamController;
  static StreamController<int>? _adapterStateStreamController;
  static StreamController<Map<String, String>>? _measureDataStreamController;
  static StreamController<String>? _dataReceivedStreamController;
  static StreamController<Map<String, bool>>? _advancedModesStreamController;
  static StreamController<Map<String, dynamic>>? _otaProgressStreamController;

  // Track previous states for change detection
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
      final result = await _channel.invokeMethod<Map>('isBluetoothEnabled');
      return result?['isEnabled'] as bool? ?? false;
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
      final result = await _channel.invokeMethod<Map>('getDiscoveredDevices');
      final devicesList = result?['devices'] as List?;
      if (devicesList == null) return [];

      return devicesList.map((device) {
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

  /// Stop device stream polling
  static void stopDeviceStream() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _deviceStreamController?.close();
    _deviceStreamController = null;
  }

  /// Restart device stream (useful when reopening device list)
  static void restartDeviceStream() {
    stopDeviceStream();
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
      final result = await _channel.invokeMethod<Map>('isConnected');
      return result?['isConnected'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to check connection: ${e.message}');
      return false;
    }
  }

  /// Get connection state (0=disconnected, 1=connecting, 2=connected)
  static Future<int> getConnectionState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getConnectionState');
      return result?['state'] as int? ?? 0;
    } on PlatformException catch (e) {
      print('[iOS] Failed to get connection state: ${e.message}');
      return 0;
    }
  }

  /// Get connected device
  static Future<Map<String, String>?> getConnectedDevice() async {
    try {
      final result = await _channel.invokeMethod<Map>('getConnectedDevice');
      if (result == null) return null;

      final device = result['device'];
      if (device == null || device is! Map) return null;

      final deviceMap = Map<String, dynamic>.from(device);
      return <String, String>{
        'name': deviceMap['name']?.toString() ?? 'Unknown',
        'address': deviceMap['id']?.toString() ?? '',
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
      final result = await _channel.invokeMethod<Map>('isAutoConnectEnabled');
      return result?['enabled'] as bool? ?? true;
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

      final device = result['device'];
      if (device == null || device is! Map) return null;

      final deviceMap = Map<String, dynamic>.from(device);
      return <String, String>{
        'name': deviceMap['name']?.toString() ?? 'Unknown',
        'address': deviceMap['id']?.toString() ?? '',
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

  /// Stream of discovered devices (polls every 1 second)
  /// Emits all currently discovered devices on each poll - controller handles deduplication
  static Stream<Map<String, String>> getDeviceStream() {
    _deviceStreamController ??=
        StreamController<Map<String, String>>.broadcast();

    // Start polling if not already started
    if (_scanTimer == null) {
      // Immediately emit all currently discovered devices
      getDiscoveredDevices().then((devices) {
        for (final device in devices) {
          _deviceStreamController?.add(device);
        }
      });

      // Then start periodic polling - emit ALL devices each time
      // Controller will handle deduplication
      _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final devices = await getDiscoveredDevices();

          // Emit all devices - let controller handle deduplication
          for (final device in devices) {
            _deviceStreamController?.add(device);
          }
        } catch (e) {
          print('[iOS] Error polling devices: $e');
        }
      });
    }

    return _deviceStreamController!.stream;
  }

  /// Stream of connection state changes (polls every 1 second)
  static Stream<Map<String, dynamic>> getConnectionStream() {
    _connectionStreamController ??=
        StreamController<Map<String, dynamic>>.broadcast();

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // Get connection state (0=disconnected, 1=connecting, 2=connected)
        final state = await getConnectionState();

        // Get device info if connected or connecting
        Map<String, String>? device;
        if (state == 1 || state == 2) {
          // If connecting, try to get device from pending connection
          // If connected, get from connected device
          device = await getConnectedDevice();

          // If no device found but we're connecting, try to get last connected device
          if (device == null && state == 1) {
            final lastDevice = await getLastConnectedDevice();
            if (lastDevice != null) {
              device = {
                'address': lastDevice['address'] ?? '',
                'name': lastDevice['name'] ?? 'Unknown',
              };
            }
          }
        }

        // Emit state changes (always emit to ensure UI updates)
        _connectionStreamController?.add({
          'state': state, // 0=disconnected, 1=connecting, 2=connected
          'address': device?['address'],
          'name': device?['name'], // Include device name for UI display
        });
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
  // CHARGE LIMIT
  // ============================================================================

  /// Set charge limit
  /// Returns a map with success status and the rounded limit value
  static Future<Map<String, dynamic>> setChargeLimit(
    int limit,
    bool enabled,
  ) async {
    try {
      final result = await _channel.invokeMethod<Map>('setChargeLimit', {
        'limit': limit,
        'enabled': enabled,
      });

      if (result == null) {
        return {'success': false, 'limit': limit};
      }

      return {
        'success': result['success'] as bool? ?? false,
        'limit': result['limit'] as int? ?? limit, // iOS returns rounded value
        'enabled': result['enabled'] as bool? ?? enabled,
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to set charge limit: ${e.message}');
      return {'success': false, 'limit': limit};
    }
  }

  /// Set charge limit enabled state
  static Future<bool> setChargeLimitEnabled(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<Map>('setChargeLimitEnabled', {
        'enabled': enabled,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to set charge limit enabled: ${e.message}');
      return false;
    }
  }

  /// Get charge limit info
  static Future<Map<String, dynamic>> getChargeLimitInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getChargeLimitInfo');
      if (result == null) {
        return {
          'limit': 90,
          'enabled': false,
          'confirmed': false,
          'chargingTime': 0,
          'dischargingTime': 0,
        };
      }

      return {
        'limit': result['limit'] as int? ?? 90,
        'enabled': result['enabled'] as bool? ?? false,
        'confirmed': result['confirmed'] as bool? ?? false,
        'chargingTime': result['chargingTime'] as int? ?? 0,
        'dischargingTime': result['dischargingTime'] as int? ?? 0,
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to get charge limit info: ${e.message}');
      return {
        'limit': 90,
        'enabled': false,
        'confirmed': false,
        'chargingTime': 0,
        'dischargingTime': 0,
      };
    }
  }

  /// Send a command to the device
  static Future<bool> sendCommand(String command) async {
    try {
      final result = await _channel.invokeMethod<Map>('sendCommand', {
        'command': command,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to send command: ${e.message}');
      return false;
    }
  }

  /// Send UI-ready commands (mwh, swversion, chmode) - called once from Flutter when UI is ready
  /// This prevents duplicate commands from being sent repeatedly
  static Future<bool> sendUIReadyCommands() async {
    try {
      final result = await _channel.invokeMethod<Map>('sendUIReadyCommands');
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to send UI-ready commands: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // BATTERY METHODS
  // ============================================================================

  /// Get phone battery info
  static Future<Map<String, dynamic>> getPhoneBattery() async {
    try {
      final result = await _channel.invokeMethod<Map>('getPhoneBattery');
      if (result == null) {
        return {'level': -1, 'isCharging': false, 'currentMicroAmps': 0};
      }

      return {
        'level': result['level'] as int? ?? -1,
        'isCharging': result['isCharging'] as bool? ?? false,
        'currentMicroAmps': result['currentMicroAmps'] as int? ?? 0,
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to get phone battery: ${e.message}');
      return {'level': -1, 'isCharging': false, 'currentMicroAmps': 0};
    }
  }

  // ============================================================================
  // ADVANCED MODES
  // ============================================================================

  /// Get advanced modes state
  static Future<Map<String, bool>> getAdvancedModes() async {
    try {
      final result = await _channel.invokeMethod<Map>('getAdvancedModes');
      if (result == null) {
        return {
          'ghostMode': false,
          'silentMode': false,
          'higherChargeLimit': false,
        };
      }

      return {
        'ghostMode': result['ghostMode'] as bool? ?? false,
        'silentMode': result['silentMode'] as bool? ?? false,
        'higherChargeLimit': result['higherChargeLimit'] as bool? ?? false,
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to get advanced modes: ${e.message}');
      return {
        'ghostMode': false,
        'silentMode': false,
        'higherChargeLimit': false,
      };
    }
  }

  /// Set ghost mode
  static Future<bool> setGhostMode(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<Map>('setGhostMode', {
        'enabled': enabled,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to set ghost mode: ${e.message}');
      return false;
    }
  }

  /// Set silent mode
  static Future<bool> setSilentMode(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<Map>('setSilentMode', {
        'enabled': enabled,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to set silent mode: ${e.message}');
      return false;
    }
  }

  /// Set higher charge limit
  static Future<bool> setHigherChargeLimit(bool enabled) async {
    try {
      final result = await _channel.invokeMethod<Map>('setHigherChargeLimit', {
        'enabled': enabled,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to set higher charge limit: ${e.message}');
      return false;
    }
  }

  /// Request advanced modes from device
  static Future<bool> requestAdvancedModes() async {
    try {
      final result = await _channel.invokeMethod<Map>('requestAdvancedModes');
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to request advanced modes: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // LED TIMEOUT
  // ============================================================================

  /// Set LED timeout (seconds)
  static Future<bool> setLedTimeout(int seconds) async {
    try {
      final result = await _channel.invokeMethod<Map>('setLedTimeout', {
        'seconds': seconds,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to set LED timeout: ${e.message}');
      return false;
    }
  }

  /// Request LED timeout from device
  static Future<bool> requestLedTimeout() async {
    try {
      final result = await _channel.invokeMethod<Map>('requestLedTimeout');
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to request LED timeout: ${e.message}');
      return false;
    }
  }

  /// Get LED timeout info
  static Future<int> getLedTimeout() async {
    try {
      final result = await _channel.invokeMethod<Map>('getLedTimeoutInfo');
      return result?['ledTimeout'] as int? ?? 300;
    } on PlatformException catch (e) {
      print('[iOS] Failed to get LED timeout: ${e.message}');
      return 300;
    }
  }

  // ============================================================================
  // MEASURE DATA & BATTERY METRICS
  // ============================================================================

  /// Get current measure data (voltage and current from Leo device)
  static Future<Map<String, String>> getMeasureData() async {
    try {
      final result = await _channel.invokeMethod<Map>('getMeasureData');
      if (result == null) {
        return {'voltage': '0.000', 'current': '0.000'};
      }

      return {
        'voltage': result['voltage'] as String? ?? '0.000',
        'current': result['current'] as String? ?? '0.000',
      };
    } on PlatformException catch (e) {
      print('[iOS] Failed to get measure data: ${e.message}');
      return {'voltage': '0.000', 'current': '0.000'};
    }
  }

  /// Stream of measure data (polls every 1 second when device is connected)
  static Stream<Map<String, String>> getMeasureDataStream() {
    _measureDataStreamController ??=
        StreamController<Map<String, String>>.broadcast();

    // Start polling if not already started
    if (_measureDataTimer == null) {
      _measureDataTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        try {
          final connected = await isConnected();
          if (connected) {
            final data = await getMeasureData();
            _measureDataStreamController?.add(data);
          }
        } catch (e) {
          print('[iOS] Error polling measure data: $e');
        }
      });
    }

    return _measureDataStreamController!.stream;
  }

  /// Get last received raw data (matching Android dataReceivedStream)
  static Future<String> getLastReceivedData() async {
    try {
      final result = await _channel.invokeMethod<String>('getLastReceivedData');
      return result ?? '';
    } on PlatformException catch (e) {
      print('[iOS] Failed to get last received data: ${e.message}');
      return '';
    }
  }

  /// Stream of raw received data (polls every 1 second when device is connected)
  /// Matches Android dataReceivedStream for parsing charging mode and other values
  static Stream<String> getDataReceivedStream() {
    _dataReceivedStreamController ??= StreamController<String>.broadcast();

    // Start polling if not already started
    if (_dataReceivedTimer == null) {
      String lastData = '';
      _dataReceivedTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        try {
          final connected = await isConnected();
          if (connected) {
            final data = await getLastReceivedData();
            // Emit if data changed OR if it contains important commands (mwh, swversion, chmode)
            // This ensures we parse responses even if they're the same value
            final shouldEmit =
                data.isNotEmpty &&
                (data != lastData ||
                    data.toLowerCase().contains('mwh') ||
                    data.toLowerCase().contains('swversion') ||
                    data.toLowerCase().contains('chmode'));

            if (shouldEmit) {
              // Only update lastData if it actually changed to avoid infinite loops
              if (data != lastData) {
                lastData = data;
              }
              _dataReceivedStreamController?.add(data);
            }
          }
        } catch (e) {
          print('[iOS] Error polling data received: $e');
        }
      });
    }

    return _dataReceivedStreamController!.stream;
  }

  /// Stream of advanced modes (polls every 2 seconds when device is connected)
  static Stream<Map<String, bool>> getAdvancedModesStream() {
    _advancedModesStreamController ??=
        StreamController<Map<String, bool>>.broadcast();

    // Start polling if not already started
    if (_advancedModesTimer == null) {
      _advancedModesTimer = Timer.periodic(const Duration(seconds: 2), (
        timer,
      ) async {
        try {
          final connected = await isConnected();
          if (connected) {
            final modes = await getAdvancedModes();
            _advancedModesStreamController?.add(modes);
          }
        } catch (e) {
          print('[iOS] Error polling advanced modes: $e');
        }
      });
    }

    return _advancedModesStreamController!.stream;
  }

  /// Stream of OTA progress updates (iOS uses EventChannel)
  static Stream<Map<String, dynamic>> getOtaProgressStream() {
    // iOS uses EventChannel for OTA progress (matching Android implementation)
    if (_otaProgressStreamController == null) {
      const EventChannel otaProgressChannel = EventChannel(
        'com.liion_app/ota_progress',
      );
      _otaProgressStreamController =
          StreamController<Map<String, dynamic>>.broadcast();

      otaProgressChannel.receiveBroadcastStream().listen(
        (event) {
          try {
            final Map<String, dynamic> progressData = Map<String, dynamic>.from(
              event as Map,
            );
            _otaProgressStreamController?.add(progressData);
          } catch (e) {
            print('[iOS] Error parsing OTA progress data: $e');
          }
        },
        onError: (error) {
          print('[iOS] OTA progress stream error: $error');
        },
      );
    }

    return _otaProgressStreamController!.stream;
  }

  // ============================================================================
  // OTA UPDATE METHODS
  // ============================================================================

  /// Start OTA update with firmware file path
  static Future<bool> startOtaUpdate(String filePath) async {
    try {
      final result = await _channel.invokeMethod<Map>('startOtaUpdate', {
        'filePath': filePath,
      });
      return result?['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to start OTA update: ${e.message}');
      return false;
    }
  }

  /// Cancel OTA update
  static Future<bool> cancelOtaUpdate() async {
    try {
      await _channel.invokeMethod('cancelOtaUpdate');
      return true;
    } on PlatformException catch (e) {
      print('[iOS] Failed to cancel OTA update: ${e.message}');
      return false;
    }
  }

  /// Get OTA progress
  static Future<int> getOtaProgress() async {
    try {
      final result = await _channel.invokeMethod<Map>('getOtaProgress');
      return result?['progress'] as int? ?? 0;
    } on PlatformException catch (e) {
      print('[iOS] Failed to get OTA progress: ${e.message}');
      return 0;
    }
  }

  /// Check if OTA is in progress
  static Future<bool> isOtaInProgress() async {
    try {
      final result = await _channel.invokeMethod<Map>('isOtaInProgress');
      return result?['isInProgress'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('[iOS] Failed to check OTA status: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================

  /// Dispose all streams and timers
  static void dispose() {
    _scanTimer?.cancel();
    _scanTimer = null;
    _measureDataTimer?.cancel();
    _measureDataTimer = null;
    _dataReceivedTimer?.cancel();
    _dataReceivedTimer = null;
    _advancedModesTimer?.cancel();
    _advancedModesTimer = null;
    _deviceStreamController?.close();
    _deviceStreamController = null;
    _connectionStreamController?.close();
    _connectionStreamController = null;
    _adapterStateStreamController?.close();
    _adapterStateStreamController = null;
    _measureDataStreamController?.close();
    _measureDataStreamController = null;
    _dataReceivedStreamController?.close();
    _dataReceivedStreamController = null;
    _advancedModesStreamController?.close();
    _advancedModesStreamController = null;
    _otaProgressStreamController?.close();
    _otaProgressStreamController = null;
  }
}
