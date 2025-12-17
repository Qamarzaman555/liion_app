import Flutter
import UIKit

/// Flutter Method Channel bridge for Background Service
class BackgroundServiceChannel {
    
    private static let channelName = "com.liion.app/background_service"
    private let backgroundService = BackgroundService.shared
    private let loggingService = BackendLoggingService.shared
    
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
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Method Handlers
    
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
}

