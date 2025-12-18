import Foundation
import UIKit
import SystemConfiguration

/// BackendLoggingService - Handles logging to backend with device and session management
class BackendLoggingService {
    
    static let shared = BackendLoggingService()
    
    // Backend API configuration
    private var backendBaseUrl: String = "http://13.62.9.177:3000"
    private let apiBasePath: String = "/api"
    
    private var deviceKey: String?
    private var sessionId: String?
    private var isInitialized = false
    private var appVersion: String?
    private var buildNumber: String?
    
    private let dateFormatter: DateFormatter
    private let serialQueue = DispatchQueue(label: "com.liion.backendlogging", qos: .utility)
    
    var initialized: Bool {
        return isInitialized
    }
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Karachi") // Pakistani time (UTC+5)
        dateFormatter.locale = Locale(identifier: "en_US")
    }
    
    /// Set the backend server URL
    func setBackendUrl(_ url: String) {
        backendBaseUrl = url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("[BackendLogging] Backend URL set to: \(backendBaseUrl)")
    }
    
    /// Initialize the logging service
    func initialize(appVersion: String, buildNumber: String) {
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("[BackendLogging] Initializing backend logging service")
            print("[BackendLogging] Backend URL: \(self.backendBaseUrl)")
            print("[BackendLogging] App Version: \(appVersion), Build: \(buildNumber)")
            
            // // Dev-mode: avoid creating cloud sessions while iterating locally
            // print("[BackendLogging] Skipping backend session creation in dev mode")
            // return
            
            // Check network connectivity
            guard self.hasNetworkConnection() else {
                print("[BackendLogging] No network connection available for backend logging")
                return
            }
            
            // Test backend connectivity first
            guard self.testBackendConnection() else {
                print("[BackendLogging] Cannot reach backend server at \(self.backendBaseUrl)")
                return
            }
            
            // Get device label
            self.deviceKey = self.getDeviceLabel()
            print("[BackendLogging] Device key: \(self.deviceKey ?? "nil")")
            
            // Ensure device exists
            print("[BackendLogging] Ensuring device exists. Device key: \(self.deviceKey ?? "nil")")
            var deviceExists = self.ensureDeviceExists()
            
            if !deviceExists {
                print("[BackendLogging] Failed to ensure device exists. Retrying...")
                Thread.sleep(forTimeInterval: 2.0)
                deviceExists = self.ensureDeviceExists()
                
                if !deviceExists {
                    print("[BackendLogging] Retry failed. Cannot proceed without device.")
                    return
                } else {
                    print("[BackendLogging] Device created successfully on retry")
                }
            } else {
                print("[BackendLogging] Device exists, proceeding with session ID retrieval")
            }
            
            // Get next session ID
            let nextSessionId = self.getNextSessionId()
            self.sessionId = nextSessionId
            print("[BackendLogging] Session ID: \(nextSessionId)")
            
            // Create session
            let sessionCreated = self.createSession(sessionId: nextSessionId, appVersion: appVersion, buildNumber: buildNumber)
            
            if sessionCreated {
                self.isInitialized = true
                print("[BackendLogging] Logging session initialized successfully")
                self.log("Logging session initialized", level: "INFO")
            } else {
                print("[BackendLogging] Failed to create session")
            }
        }
    }
    
    /// Start the logging service (legacy method for compatibility)
    func start() {
        // Get app version from bundle
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        initialize(appVersion: version, buildNumber: build)
    }
    
    /// Stop the logging service
    func stop() {
        log("BackendLoggingService stopped", level: "INFO")
        isInitialized = false
    }
    
    // MARK: - Device Management
    
    private func ensureDeviceExists() -> Bool {
        guard let deviceKey = deviceKey else {
            print("[BackendLogging] Device key is null, cannot check/create device")
            return false
        }
        
        // Check if device exists
        let checkUrl = "\(backendBaseUrl)\(apiBasePath)/devices"
        print("[BackendLogging] Checking if device exists at: \(checkUrl)")
        
        guard let url = URL(string: checkUrl) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var deviceExists = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[BackendLogging] Error checking devices: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 200, let data = data {
                do {
                    if let devices = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        for device in devices {
                            if let existingKey = device["deviceKey"] as? String, existingKey == deviceKey {
                                deviceExists = true
                                print("[BackendLogging] Device found in list: \(deviceKey)")
                                break
                            }
                        }
                    }
                } catch {
                    print("[BackendLogging] Error parsing devices JSON: \(error)")
                }
            }
        }
        task.resume()
        semaphore.wait()
        
        if deviceExists {
            print("[BackendLogging] Device already exists: \(deviceKey)")
            return true
        }
        
        // Create device if it doesn't exist
        print("[BackendLogging] Device not found, creating new device: \(deviceKey)")
        return createDevice(deviceKey: deviceKey)
    }
    
    private func createDevice(deviceKey: String) -> Bool {
        let createUrl = "\(backendBaseUrl)\(apiBasePath)/devices"
        print("[BackendLogging] Creating device at: \(createUrl)")
        
        guard let url = URL(string: createUrl) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let requestBody: [String: Any] = [
            "deviceKey": deviceKey,
            "platform": "ios"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("[BackendLogging] Failed to serialize request body")
            return false
        }
        
        request.httpBody = jsonData
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[BackendLogging] Error creating device: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            print("[BackendLogging] Device creation response code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("[BackendLogging] Device created successfully: \(deviceKey)")
                success = true
            } else {
                if let data = data, let errorStr = String(data: data, encoding: .utf8) {
                    print("[BackendLogging] Failed to create device. Error: \(errorStr)")
                }
            }
        }
        task.resume()
        semaphore.wait()
        
        return success
    }
    
    // MARK: - Session Management
    
    private func getNextSessionId() -> String {
        guard let deviceKey = deviceKey else { return "1" }
        
        let urlString = "\(backendBaseUrl)\(apiBasePath)/sessions/device/\(deviceKey)"
        guard let url = URL(string: urlString) else { return "1" }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var nextId = "1"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[BackendLogging] Error getting sessions: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 200, let data = data {
                do {
                    if let sessions = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        var maxSessionId = 0
                        for session in sessions {
                            if let sessionIdStr = session["sessionId"] as? String,
                               let parsed = Int(sessionIdStr.trimmingCharacters(in: .whitespaces)) {
                                maxSessionId = max(maxSessionId, parsed)
                            }
                        }
                        nextId = "\(maxSessionId + 1)"
                    }
                } catch {
                    print("[BackendLogging] Error parsing sessions JSON: \(error)")
                }
            } else if httpResponse.statusCode == 404 {
                nextId = "1"
            }
        }
        task.resume()
        semaphore.wait()
        
        return nextId
    }
    
    private func createSession(sessionId: String, appVersion: String, buildNumber: String) -> Bool {
        guard let deviceKey = deviceKey else { return false }
        
        print("[BackendLogging] Creating/updating session. Device key: \(deviceKey), Session ID: \(sessionId)")
        
        let urlString = "\(backendBaseUrl)\(apiBasePath)/sessions"
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let requestBody: [String: Any] = [
            "deviceKey": deviceKey,
            "sessionId": sessionId,
            "appVersion": appVersion,
            "buildNumber": buildNumber
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else { return false }
        request.httpBody = jsonData
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[BackendLogging] Error creating session: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("[BackendLogging] Session created successfully: \(sessionId)")
                success = true
            } else {
                if let data = data, let errorStr = String(data: data, encoding: .utf8) {
                    print("[BackendLogging] Failed to create session. Response code: \(httpResponse.statusCode), Error: \(errorStr)")
                }
            }
        }
        task.resume()
        semaphore.wait()
        
        return success
    }
    
    // MARK: - Logging
    
    func log(_ message: String, level: String) {
        if !isInitialized || sessionId == nil || deviceKey == nil {
            print("[BackendLogging] Logging skipped - not initialized. Level: \(level), Message: \(message)")
            return
        }
        
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.hasNetworkConnection() else {
                print("[BackendLogging] No network connection, skipping log")
                return
            }
            
            self.sendLog(level: level, message: message)
        }
    }
    
    private func sendLog(level: String, message: String) {
        guard let deviceKey = deviceKey,
              let sessionId = sessionId else { return }
        
        let urlString = "\(backendBaseUrl)\(apiBasePath)/logs"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5.0
        
        let timestamp = dateFormatter.string(from: Date())
        
        let requestBody: [String: Any] = [
            "deviceKey": deviceKey,
            "sessionId": sessionId,
            "level": level,
            "message": message,
            "timestamp": timestamp
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else { return }
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[BackendLogging] Error sending log: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else { return }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                print("[BackendLogging] Log sent successfully: \(level) - \(message)")
            } else {
                if let data = data, let errorStr = String(data: data, encoding: .utf8) {
                    print("[BackendLogging] Failed to send log: \(errorStr)")
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Network & Connectivity
    
    private func testBackendConnection() -> Bool {
        let urlString = "\(backendBaseUrl)/health"
        guard let url = URL(string: urlString) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[BackendLogging] Backend connection test failed: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                success = httpResponse.statusCode == 200
                if success {
                    print("[BackendLogging] Backend connection test successful")
                } else {
                    print("[BackendLogging] Backend connection test failed. Response code: \(httpResponse.statusCode)")
                }
            }
        }
        task.resume()
        semaphore.wait()
        
        return success
    }
    
    private func hasNetworkConnection() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return isReachable && !needsConnection
    }
    
    private func getDeviceLabel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        let model = modelCode ?? "Unknown"
        let device = UIDevice.current.name
        
        return "\(device) - \(model)"
    }
    
    func getSessionInfo() -> [String: String?] {
        return ["deviceKey": deviceKey, "sessionId": sessionId]
    }
    
    // MARK: - Convenience Methods
    
    func logInfo(_ message: String) {
        log(message, level: "INFO")
    }
    
    func logDebug(_ message: String) {
        log(message, level: "DEBUG")
    }
    
    func logWarning(_ message: String) {
        log(message, level: "WARNING")
    }
    
    func logError(_ message: String) {
        log(message, level: "ERROR")
    }
    
    // MARK: - App State Logging
    
    func logAppState(_ state: String) {
        log("App State: \(state)", level: "INFO")
    }
    
    func logBackgroundTask(_ taskName: String, status: String) {
        log("Background Task: \(taskName) - \(status)", level: "DEBUG")
    }
    
    // MARK: - BLE Operation Logging
    
    func logScan(_ message: String) {
        log(message, level: "SCAN")
    }
    
    func logConnect(address: String, name: String) {
        log("Connecting to \(name) (\(address))", level: "CONNECT")
    }
    
    func logConnected(address: String, name: String) {
        log("Connected to \(name) (\(address))", level: "CONNECTED")
    }
    
    func logAutoConnect(address: String) {
        log("Auto-connecting to \(address)", level: "AUTO_CONNECT")
    }
    
    func logDisconnect(reason: String) {
        log(reason, level: "DISCONNECT")
    }
    
    func logCommand(_ command: String) {
        log(command, level: "COMMAND_SENT")
    }
    
    func logCommandResponse(_ response: String) {
        log(response, level: "COMMAND_RESPONSE")
    }
    
    func logReconnect(attempt: Int, address: String) {
        log("Attempt \(attempt) to \(address)", level: "RECONNECT")
    }
    
    func logBleState(_ state: String) {
        log(state, level: "BLE_STATE")
    }
    
    func logServiceState(_ state: String) {
        log(state, level: "SERVICE")
    }
    
    func logChargeLimit(limit: Int, enabled: Bool) {
        log("Limit: \(limit)%, Enabled: \(enabled)", level: "CHARGE_LIMIT")
    }
    
    func logBattery(level: Int, charging: Bool) {
        log("Level: \(level)%, Charging: \(charging)", level: "BATTERY")
    }
}

