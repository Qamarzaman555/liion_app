import Foundation
import UIKit

/// iOS equivalent of Android BackendLoggingService
/// Sends logs to custom backend API for cloud logging
final class BackendLoggingService {
    // MARK: - Singleton
    static let shared = BackendLoggingService()
    private init() {}
    
    // MARK: - Configuration
    // Backend API configuration
    // Default: "http://localhost:3000" (iOS Simulator)
    // For physical device: Use setBackendUrl() to set your computer's IP (e.g., "http://192.168.1.100:3000")
    private var backendBaseUrl: String = "http://13.62.9.177:3000"
    private let apiBasePath: String = "/api"
    
    /// Set the backend server URL
    /// - Parameter url: Full URL including protocol and port (e.g., "http://192.168.1.100:3000")
    func setBackendUrl(_ url: String) {
        backendBaseUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("🔵 [BackendLogging] Backend URL set to: \(backendBaseUrl)")
    }
    
    // MARK: - State
    private var deviceKey: String?
    private var sessionId: String?
    private var isInitialized = false
    private var appVersion: String?
    private var buildNumber: String?
    
    private let session = URLSession.shared
    private let queue = DispatchQueue(label: "nl.liionpower.app.backendlogging", qos: .utility)
    
    // Format timestamp in Pakistani time (UTC+5)
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Karachi")
        return formatter
    }()
    
    var initialized: Bool {
        return isInitialized
    }
    
    // MARK: - Initialization
    func initialize(appVersion: String, buildNumber: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        
        print("🔵 [BackendLogging] Initializing backend logging service")
        print("🔵 [BackendLogging] Backend URL: \(backendBaseUrl)")
        print("🔵 [BackendLogging] App Version: \(appVersion), Build: \(buildNumber)")
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check network connectivity
            guard self.hasNetworkConnection() else {
                print("⚠️ [BackendLogging] No network connection available - logs will only go to console")
                return
            }
            
            // Test backend connectivity first
            guard self.testBackendConnection() else {
                print("⚠️ [BackendLogging] Cannot reach backend server at \(self.backendBaseUrl)")
                print("⚠️ [BackendLogging] Logs will only go to console. To enable cloud logging:")
                print("⚠️ [BackendLogging]   - For iOS Simulator: Use http://localhost:3000")
                print("⚠️ [BackendLogging]   - For physical device: Call setBackendUrl() with your computer's IP")
                return
            }
            
            // Get device label
            self.deviceKey = self.getDeviceLabel()
            print("🔵 [BackendLogging] Device key: \(self.deviceKey ?? "unknown")")
            
            // Ensure device exists
            guard self.ensureDeviceExists() else {
                print("⚠️ [BackendLogging] Failed to ensure device exists - logs will only go to console")
                return
            }
            
            // Get next session ID by querying existing sessions
            guard let nextSessionId = self.getNextSessionId() else {
                print("⚠️ [BackendLogging] Failed to get next session ID - logs will only go to console")
                return
            }
            
            self.sessionId = nextSessionId
            print("🔵 [BackendLogging] Session ID: \(nextSessionId)")
            
            // Create session via API (this will update session if it already exists)
            if self.createSession(sessionId: nextSessionId) {
                self.isInitialized = true
                print("✅ [BackendLogging] Backend logging service initialized successfully - logs will be sent to cloud")
            } else {
                print("⚠️ [BackendLogging] Failed to create session - logs will only go to console")
            }
        }
    }
    
    // MARK: - Logging Methods
    func log(level: String, message: String) {
        // Always print to console for debugging
        print("📋 [BackendLogging] [\(level)] \(message)")
        
        // Send to backend if initialized
        guard isInitialized, let sessionId = sessionId, let deviceKey = deviceKey else {
            // Silently skip backend logging if not initialized (backend may be unavailable)
            return
        }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.hasNetworkConnection() else {
                // Network check - logs will be skipped but console log already printed
                return
            }
            
            self.sendLog(level: level, message: message, deviceKey: deviceKey, sessionId: sessionId)
        }
    }
    
    // MARK: - Helper Logging Methods (matching Android API)
    func logInfo(_ message: String) {
        log(level: "INFO", message: message)
    }
    
    func logDebug(_ message: String) {
        log(level: "DEBUG", message: message)
    }
    
    func logWarning(_ message: String) {
        log(level: "WARNING", message: message)
    }
    
    func logError(_ message: String) {
        log(level: "ERROR", message: message)
    }
    
    func logScan(_ message: String) {
        log(level: "SCAN", message: message)
    }
    
    func logConnect(address: String, name: String) {
        log(level: "CONNECT", message: "Connecting to \(name) (\(address))")
    }
    
    func logConnected(address: String, name: String) {
        log(level: "CONNECTED", message: "Connected to \(name) (\(address))")
    }
    
    func logAutoConnect(address: String) {
        log(level: "AUTO_CONNECT", message: "Auto-connecting to \(address)")
    }
    
    func logDisconnect(_ reason: String) {
        log(level: "DISCONNECT", message: reason)
    }
    
    func logCommand(_ command: String) {
        log(level: "COMMAND_SENT", message: command)
    }
    
    func logCommandResponse(_ response: String) {
        log(level: "COMMAND_RESPONSE", message: response)
    }
    
    func logReconnect(attempt: Int, address: String) {
        log(level: "RECONNECT", message: "Reconnect attempt #\(attempt) to \(address)")
    }
    
    func logBleState(_ state: String) {
        log(level: "BLE_STATE", message: state)
    }
    
    func logServiceState(_ state: String) {
        log(level: "SERVICE", message: state)
    }
    
    func logChargeLimit(limit: Int, enabled: Bool) {
        log(level: "CHARGE_LIMIT", message: "Limit: \(limit)%, Enabled: \(enabled)")
    }
    
    func logBattery(level: Int, charging: Bool) {
        log(level: "BATTERY", message: "Level: \(level)%, Charging: \(charging)")
    }
    
    // MARK: - Private Helpers
    private func getDeviceLabel() -> String {
        let device = UIDevice.current
        let model = device.model
        let systemVersion = device.systemVersion
        let identifier = device.identifierForVendor?.uuidString ?? "unknown"
        return "iOS-\(model)-\(systemVersion)-\(identifier.prefix(8))"
    }
    
    private func hasNetworkConnection() -> Bool {
        // Simple check - in production, use proper network reachability
        return true // iOS handles network availability automatically
    }
    
    private func testBackendConnection() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        guard let url = URL(string: "\(backendBaseUrl)/health") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                success = httpResponse.statusCode == 200
            }
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5.0)
        
        return success
    }
    
    private func ensureDeviceExists() -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        guard let deviceKey = deviceKey else {
            print("❌ [BackendLogging] Device key is null, cannot check/create device")
            return false
        }
        
        // First, check if device exists
        guard let checkUrl = URL(string: "\(backendBaseUrl)\(apiBasePath)/devices") else {
            return false
        }
        
        var checkRequest = URLRequest(url: checkUrl)
        checkRequest.httpMethod = "GET"
        checkRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        checkRequest.timeoutInterval = 5.0
        
        let checkTask = session.dataTask(with: checkRequest) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                // Check if device exists
                let deviceExists = json.contains { device in
                    (device["deviceKey"] as? String) == deviceKey
                }
                
                if deviceExists {
                    print("🔵 [BackendLogging] Device already exists: \(deviceKey)")
                    success = true
                    semaphore.signal()
                    return
                }
            }
            
            // Device doesn't exist, create it
            self.createDevice(deviceKey: deviceKey) { created in
                success = created
                semaphore.signal()
            }
        }
        
        checkTask.resume()
        _ = semaphore.wait(timeout: .now() + 15.0)
        
        return success
    }
    
    private func createDevice(deviceKey: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(backendBaseUrl)\(apiBasePath)/devices") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let body: [String: Any] = [
            "deviceKey": deviceKey,
            "platform": "ios"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                let success = httpResponse.statusCode == 200 || httpResponse.statusCode == 201
                if success {
                    print("✅ [BackendLogging] Device created successfully: \(deviceKey)")
                } else {
                    print("❌ [BackendLogging] Failed to create device. Response code: \(httpResponse.statusCode)")
                }
                completion(success)
            } else {
                completion(false)
            }
        }
        
        task.resume()
    }
    
    private func getNextSessionId() -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var nextSessionId: String? = nil
        
        guard let deviceKey = deviceKey else {
            return nil
        }
        
        guard let url = URL(string: "\(backendBaseUrl)\(apiBasePath)/sessions/device/\(deviceKey)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let data = data,
               let sessions = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                // Find max session ID and add 1
                var maxSessionId = 0
                for session in sessions {
                    if let sessionIdStr = session["sessionId"] as? String,
                       let sessionId = Int(sessionIdStr.trimmingCharacters(in: .whitespaces)) {
                        if sessionId > maxSessionId {
                            maxSessionId = sessionId
                        }
                    }
                }
                nextSessionId = String(maxSessionId + 1)
                print("🔵 [BackendLogging] Calculated next session ID: \(nextSessionId ?? "unknown")")
            } else if let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 404 {
                // No sessions exist yet, start with 1
                nextSessionId = "1"
                print("🔵 [BackendLogging] No existing sessions, starting with session ID: 1")
            } else {
                // On error, default to 1
                nextSessionId = "1"
                print("⚠️ [BackendLogging] Error getting sessions, defaulting to session ID: 1")
            }
            
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5.0)
        
        return nextSessionId
    }
    
    private func createSession(sessionId: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        guard let deviceKey = deviceKey else {
            return false
        }
        
        guard let url = URL(string: "\(backendBaseUrl)\(apiBasePath)/sessions") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let body: [String: Any] = [
            "deviceKey": deviceKey,
            "sessionId": sessionId,
            "appVersion": appVersion ?? "unknown",
            "buildNumber": buildNumber ?? "unknown"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                semaphore.signal()
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ [BackendLogging] Session created successfully: \(sessionId)")
                    success = true
                } else {
                    let errorData = data.flatMap { try? JSONSerialization.jsonObject(with: $0) }
                    let errorMsg = (errorData as? [String: Any])?["message"] as? String ?? "Unknown error"
                    print("❌ [BackendLogging] Failed to create session. Response code: \(httpResponse.statusCode), Error: \(errorMsg)")
                }
            } else if let error = error {
                print("❌ [BackendLogging] Error creating session: \(error.localizedDescription)")
            } else {
                print("❌ [BackendLogging] Failed to create session - unknown error")
            }
            
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 10.0)
        
        return success
    }
    
    private func sendLog(level: String, message: String, deviceKey: String, sessionId: String) {
        guard let url = URL(string: "\(backendBaseUrl)\(apiBasePath)/logs") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let timestamp = dateFormatter.string(from: Date())
        let body: [String: Any] = [
            "deviceKey": deviceKey,
            "sessionId": sessionId,
            "level": level,
            "message": message,
            "timestamp": timestamp
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let task = session.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    print("✅ [BackendLogging] Log sent successfully: \(level) - \(message)")
                } else {
                    print("❌ [BackendLogging] Failed to send log: HTTP \(httpResponse.statusCode)")
                }
            } else if let error = error {
                print("❌ [BackendLogging] Error sending log: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
}

