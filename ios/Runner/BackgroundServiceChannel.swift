import Flutter
import UIKit
import CoreBluetooth

/// Flutter Method Channel bridge for Background Service and BLE
class BackgroundServiceChannel {
    
    private static let channelName = "com.liion.app/background_service"
    private let backgroundService = BackgroundService.shared
    private let loggingService = BackendLoggingService.shared
    private let bleService = BLEService.shared
    
    /// Setup method channel with Flutter
    func setupChannel(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: BackgroundServiceChannel.channelName,
            binaryMessenger: messenger
        )
        
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }
    }
    
    /// Handle method calls from Flutter
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startBackgroundService":
            startBackgroundService(result: result)
            
        case "stopBackgroundService":
            stopBackgroundService(result: result)
            
        case "isServiceRunning":
            isServiceRunning(result: result)
            
        case "getServiceStatus":
            getServiceStatus(result: result)
            
        case "log":
            logMessage(call: call, result: result)
            
        case "isBluetoothEnabled":
            isBluetoothEnabled(result: result)
            
        case "getBluetoothState":
            getBluetoothState(result: result)
            
        case "getBluetoothStatus":
            getBluetoothStatus(result: result)
            
        case "startBLEScan", "startScan":
            startBLEScan(result: result)
            
        case "stopBLEScan", "stopScan":
            stopBLEScan(result: result)
            
        case "isScanning":
            isScanning(result: result)
            
        case "getDiscoveredDevices":
            getDiscoveredDevices(result: result)
            
        case "clearDiscoveredDevices":
            clearDiscoveredDevices(result: result)
            
        case "connectToDevice":
            connectToDevice(call: call, result: result)
            
        case "disconnectFromDevice":
            disconnectFromDevice(result: result)
            
        case "isConnected":
            isConnectedToDevice(result: result)
            
        case "getConnectedDevice":
            getConnectedDevice(result: result)
            
        case "setAutoConnectEnabled":
            setAutoConnectEnabled(call: call, result: result)
            
        case "isAutoConnectEnabled":
            isAutoConnectEnabledMethod(result: result)
            
        case "getLastConnectedDevice":
            getLastConnectedDeviceMethod(result: result)
            
        case "clearLastConnectedDevice":
            clearLastConnectedDeviceMethod(result: result)
            
        case "getReconnectAttemptCount":
            getReconnectAttemptCount(result: result)
            
        case "isReconnecting":
            isReconnectingMethod(result: result)
            
        case "startService":
            startService(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Method Handlers
    
    /// Start service (iOS services auto-start in AppDelegate, this is a no-op for API consistency)
    private func startService(result: @escaping FlutterResult) {
        // iOS services (BLEService, BackgroundService) are already started in AppDelegate
        // This method is here for API consistency with Android
        result(true)
    }
    
    private func startBackgroundService(result: @escaping FlutterResult) {
        backgroundService.start()
        result(["success": true, "message": "Background service started"])
    }
    
    private func stopBackgroundService(result: @escaping FlutterResult) {
        backgroundService.stop()
        result(["success": true, "message": "Background service stopped"])
    }
    
    private func isServiceRunning(result: @escaping FlutterResult) {
        let isRunning = backgroundService.isServiceRunning()
        result(["isRunning": isRunning])
    }
    
    private func getServiceStatus(result: @escaping FlutterResult) {
        let status = backgroundService.getServiceStatus()
        result(status)
    }
    
    private func logMessage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let message = args["message"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Message is required",
                details: nil
            ))
            return
        }
        
        let levelString = args["level"] as? String ?? "info"
        let level = levelString.uppercased()
        
        loggingService.log(message, level: level)
        result(["success": true])
    }
    
    // MARK: - BLE Method Handlers
    
    private func isBluetoothEnabled(result: @escaping FlutterResult) {
        let isEnabled = bleService.isBluetoothEnabled()
        result(["isEnabled": isEnabled])
    }
    
    private func getBluetoothState(result: @escaping FlutterResult) {
        let state = bleService.getBluetoothStateString()
        result(["state": state])
    }
    
    private func getBluetoothStatus(result: @escaping FlutterResult) {
        let status = bleService.getBluetoothStatus()
        result(status)
    }
    
    // MARK: - BLE Scanning Method Handlers
    
    private func startBLEScan(result: @escaping FlutterResult) {
        let scanResult = bleService.startScan()
        result(scanResult)
    }
    
    private func stopBLEScan(result: @escaping FlutterResult) {
        let scanResult = bleService.stopScan()
        result(scanResult)
    }
    
    private func isScanning(result: @escaping FlutterResult) {
        let scanning = bleService.isScanningDevices()
        result(["isScanning": scanning])
    }
    
    private func getDiscoveredDevices(result: @escaping FlutterResult) {
        let devices = bleService.getDiscoveredDevices()
        result(["devices": devices])
    }
    
    private func clearDiscoveredDevices(result: @escaping FlutterResult) {
        bleService.clearDiscoveredDevices()
        result(["success": true])
    }
    
    // MARK: - BLE Connection Method Handlers
    
    private func connectToDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceId = args["deviceId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Device ID is required",
                details: nil
            ))
            return
        }
        
        let connectionResult = bleService.connect(deviceId: deviceId)
        result(connectionResult)
    }
    
    private func disconnectFromDevice(result: @escaping FlutterResult) {
        let disconnectionResult = bleService.disconnect()
        result(disconnectionResult)
    }
    
    private func isConnectedToDevice(result: @escaping FlutterResult) {
        let connected = bleService.isConnected()
        result(["isConnected": connected])
    }
    
    private func getConnectedDevice(result: @escaping FlutterResult) {
        if let device = bleService.getConnectedDevice() {
            result(["device": device])
        } else {
            result(["device": NSNull()])
        }
    }
    
    // MARK: - Auto-Connection Method Handlers
    
    private func setAutoConnectEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "enabled parameter is required",
                details: nil
            ))
            return
        }
        
        bleService.setAutoConnectEnabled(enabled)
        result(["success": true, "enabled": enabled])
    }
    
    private func isAutoConnectEnabledMethod(result: @escaping FlutterResult) {
        let enabled = bleService.isAutoConnectEnabled()
        result(["enabled": enabled])
    }
    
    private func getLastConnectedDeviceMethod(result: @escaping FlutterResult) {
        if let deviceId = bleService.getLastConnectedDeviceId(),
           let deviceName = bleService.getLastConnectedDeviceName() {
            result([
                "device": [
                    "id": deviceId,
                    "name": deviceName
                ]
            ])
        } else {
            result(["device": NSNull()])
        }
    }
    
    private func clearLastConnectedDeviceMethod(result: @escaping FlutterResult) {
        bleService.clearLastConnectedDevice()
        result(["success": true])
    }
    
    private func getReconnectAttemptCount(result: @escaping FlutterResult) {
        let count = bleService.getReconnectAttemptCount()
        result(["count": count])
    }
    
    private func isReconnectingMethod(result: @escaping FlutterResult) {
        let reconnecting = bleService.isCurrentlyReconnecting()
        result(["isReconnecting": reconnecting])
    }
}

