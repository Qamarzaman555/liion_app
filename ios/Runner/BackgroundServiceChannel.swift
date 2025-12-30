import Flutter
import UIKit
import CoreBluetooth

/// Flutter Method Channel bridge for Background Service and BLE
class BackgroundServiceChannel: NSObject, FlutterStreamHandler {
    
    private static let channelName = "nl.liionpower.app/background_service"
    private static let otaProgressChannelName = "com.liion_app/ota_progress"
    private let backgroundService = BackgroundService.shared
    private let loggingService = BackendLoggingService.shared
    private let bleService = BLEService.shared

    private var otaProgressEventSink: FlutterEventSink?
    
    /// Setup method channel with Flutter
    func setupChannel(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: BackgroundServiceChannel.channelName,
            binaryMessenger: messenger
        )
        
        channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleMethodCall(call: call, result: result)
        }

        // Setup OTA progress EventChannel
        let otaProgressChannel = FlutterEventChannel(
            name: BackgroundServiceChannel.otaProgressChannelName,
            binaryMessenger: messenger
        )

        otaProgressChannel.setStreamHandler(self)
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
            
        case "getConnectionState":
            getConnectionState(result: result)
            
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

        case "startOtaUpdate":
            startOtaUpdate(call: call, result: result)

        case "cancelOtaUpdate":
            cancelOtaUpdate(result: result)

        case "getOtaProgress":
            getOtaProgress(result: result)

        case "isOtaInProgress":
            isOtaInProgressMethod(result: result)

        case "startService":
            startService(result: result)
            
        case "setChargeLimit":
            setChargeLimit(call: call, result: result)
            
        case "setChargeLimitEnabled":
            setChargeLimitEnabled(call: call, result: result)
            
        case "getChargeLimitInfo":
            getChargeLimitInfo(result: result)
            
        case "sendCommand":
            sendCommand(call: call, result: result)
            
        case "getPhoneBattery":
            getPhoneBattery(result: result)
            
        case "getAdvancedModes":
            getAdvancedModes(result: result)
            
        case "setGhostMode":
            setGhostMode(call: call, result: result)
            
        case "setSilentMode":
            setSilentMode(call: call, result: result)
            
        case "setHigherChargeLimit":
            setHigherChargeLimit(call: call, result: result)
            
        case "requestAdvancedModes":
            requestAdvancedModes(result: result)
            
        case "setLedTimeout":
            setLedTimeout(call: call, result: result)
            
        case "requestLedTimeout":
            requestLedTimeout(result: result)
            
        case "getLedTimeoutInfo":
            getLedTimeoutInfo(result: result)
            
        case "getMeasureData":
            getMeasureData(result: result)
            
        case "getLastReceivedData":
            getLastReceivedData(result: result)
            
        case "sendUIReadyCommands":
            sendUIReadyCommands(result: result)
            
        case "startFileStreaming":
            startFileStreaming(result: result)
            
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
    
    private func getConnectionState(result: @escaping FlutterResult) {
        let state = bleService.getConnectionState()
        result(["state": state])
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

    // MARK: - OTA Method Handlers

    private func startOtaUpdate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let filePath = args["filePath"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "filePath (String) parameter is required",
                details: nil
            ))
            return
        }

        let success = bleService.startOtaUpdate(filePath: filePath)
        result(["success": success])
    }

    private func cancelOtaUpdate(result: @escaping FlutterResult) {
        bleService.cancelOtaUpdate()
        result(["success": true])
    }

    private func getOtaProgress(result: @escaping FlutterResult) {
        let progress = bleService.getOtaProgress()
        result(["progress": progress])
    }

    private func isOtaInProgressMethod(result: @escaping FlutterResult) {
        let inProgress = bleService.isOtaUpdateInProgress()
        result(["isInProgress": inProgress])
    }

    // MARK: - Charge Limit Method Handlers
    
    private func setChargeLimit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let limit = args["limit"] as? Int,
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "limit (Int) and enabled (Bool) parameters are required",
                details: nil
            ))
            return
        }
        
        let chargeLimitResult = bleService.setChargeLimit(limit: limit, enabled: enabled)
        result(chargeLimitResult)
    }
    
    private func setChargeLimitEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "enabled (Bool) parameter is required",
                details: nil
            ))
            return
        }
        
        let chargeLimitResult = bleService.setChargeLimitEnabled(enabled: enabled)
        result(chargeLimitResult)
    }
    
    private func getChargeLimitInfo(result: @escaping FlutterResult) {
        let info = bleService.getChargeLimitInfo()
        result(info)
    }
    
    private func sendCommand(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let command = args["command"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "command (String) parameter is required",
                details: nil
            ))
            return
        }
        
        let commandResult = bleService.sendCommand(command)
        result(commandResult)
    }
    
    // MARK: - Battery Method Handlers
    
    private func getPhoneBattery(result: @escaping FlutterResult) {
        let info = bleService.getPhoneBatteryInfo()
        result(info)
    }
    
    // MARK: - Advanced Modes Method Handlers
    
    private func getAdvancedModes(result: @escaping FlutterResult) {
        let modes = bleService.getAdvancedModes()
        result(modes)
    }
    
    private func setGhostMode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "enabled (Bool) parameter is required",
                details: nil
            ))
            return
        }
        
        let modeResult = bleService.setGhostMode(enabled: enabled)
        result(modeResult)
    }
    
    private func setSilentMode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "enabled (Bool) parameter is required",
                details: nil
            ))
            return
        }
        
        let modeResult = bleService.setSilentMode(enabled: enabled)
        result(modeResult)
    }
    
    private func setHigherChargeLimit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "enabled (Bool) parameter is required",
                details: nil
            ))
            return
        }
        
        let modeResult = bleService.setHigherChargeLimit(enabled: enabled)
        result(modeResult)
    }
    
    private func requestAdvancedModes(result: @escaping FlutterResult) {
        let requestResult = bleService.requestAdvancedModes()
        result(requestResult)
    }
    
    // MARK: - LED Timeout Method Handlers
    
    private func setLedTimeout(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let seconds = args["seconds"] as? Int else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "seconds (Int) parameter is required",
                details: nil
            ))
            return
        }
        
        let timeoutResult = bleService.setLedTimeout(seconds: seconds)
        result(timeoutResult)
    }
    
    private func requestLedTimeout(result: @escaping FlutterResult) {
        let requestResult = bleService.requestLedTimeout()
        result(requestResult)
    }
    
    private func getLedTimeoutInfo(result: @escaping FlutterResult) {
        let info = bleService.getLedTimeoutInfo()
        result(info)
    }
    
    // MARK: - Measure Data Handler
    
    private func getMeasureData(result: @escaping FlutterResult) {
        let data = bleService.getMeasureData()
        result(data)
    }
    
    private func getLastReceivedData(result: @escaping FlutterResult) {
        let data = bleService.getLastReceivedData()
        result(data)
    }
    
    private func sendUIReadyCommands(result: @escaping FlutterResult) {
        let commandResult = bleService.sendUIReadyCommands()
        result(commandResult)
    }
    
    // MARK: - File Streaming Method Handler
    
    private func startFileStreaming(result: @escaping FlutterResult) {
        let streamingResult = bleService.startFileStreaming()
        result(streamingResult)
    }

    // MARK: - FlutterStreamHandler Methods (OTA Progress)

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        otaProgressEventSink = events

        // Setup OTA progress callback
        bleService.onOtaProgress = { [weak self] (progress, inProgress, message) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.otaProgressEventSink?([
                    "progress": progress,
                    "inProgress": inProgress,
                    "message": message ?? ""
                ])
            }
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        otaProgressEventSink = nil
        bleService.onOtaProgress = nil
        return nil
    }
}

