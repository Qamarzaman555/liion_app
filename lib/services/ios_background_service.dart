import 'dart:io';
import 'package:flutter/services.dart';

/// iOS Background Service Bridge
/// Communicates with native iOS background services via method channel
class IOSBackgroundService {
  static const MethodChannel _channel =
      MethodChannel('nl.liionpower.app/background_service');

  /// Start the native iOS background service
  /// This will keep the app alive in background using location services
  static Future<Map<String, dynamic>> startBackgroundService() async {
    if (!Platform.isIOS) {
      return {'success': false, 'message': 'Not running on iOS'};
    }

    try {
      final result =
          await _channel.invokeMethod('startBackgroundService') as Map;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Failed to start service: ${e.message}'
      };
    }
  }

  /// Stop the native iOS background service
  static Future<Map<String, dynamic>> stopBackgroundService() async {
    if (!Platform.isIOS) {
      return {'success': false, 'message': 'Not running on iOS'};
    }

    try {
      final result = await _channel.invokeMethod('stopBackgroundService') as Map;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      return {
        'success': false,
        'message': 'Failed to stop service: ${e.message}'
      };
    }
  }

  /// Check if the background service is currently running
  static Future<bool> isServiceRunning() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _channel.invokeMethod('isServiceRunning') as Map;
      return result['isRunning'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error checking service status: ${e.message}');
      return false;
    }
  }

  /// Get detailed status of the background service
  /// Returns information about location services, authorization, etc.
  static Future<Map<String, dynamic>> getServiceStatus() async {
    if (!Platform.isIOS) {
      return {'error': 'Not running on iOS'};
    }

    try {
      final result = await _channel.invokeMethod('getServiceStatus') as Map;
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      return {'error': 'Failed to get status: ${e.message}'};
    }
  }

  /// Send a log message to the native iOS backend logging service
  /// 
  /// [message] - The log message to send
  /// [level] - Log level: 'debug', 'info', 'warning', 'error' (default: 'info')
  static Future<bool> log(
    String message, {
    String level = 'info',
  }) async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _channel.invokeMethod('log', {
        'message': message,
        'level': level,
      }) as Map;
      return result['success'] as bool? ?? false;
    } on PlatformException catch (e) {
      print('Error sending log: ${e.message}');
      return false;
    }
  }

  /// Log with DEBUG level
  static Future<bool> logDebug(String message) =>
      log(message, level: 'debug');

  /// Log with INFO level
  static Future<bool> logInfo(String message) => log(message, level: 'info');

  /// Log with WARNING level
  static Future<bool> logWarning(String message) =>
      log(message, level: 'warning');

  /// Log with ERROR level
  static Future<bool> logError(String message) => log(message, level: 'error');
}

