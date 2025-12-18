import Foundation
import CoreBluetooth

/// BLEService - Manages Bluetooth state and operations
class BLEService: NSObject {
    
    static let shared = BLEService()
    
    private var centralManager: CBCentralManager!
    private var bluetoothState: CBManagerState = .unknown
    private let logger = BackendLoggingService.shared
    
    // Scanning state
    private var isScanning = false
    private var discoveredDevices: [String: [String: Any]] = [:] // UUID -> Device info
    private let deviceNameFilter = "Leo Usb" // Filter for Leo Usb devices
    
    // Connection state (matching Android STATE_DISCONNECTED, STATE_CONNECTING, STATE_CONNECTED)
    private enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    private var connectionState: ConnectionState = .disconnected
    private var connectedPeripheral: CBPeripheral?
    private var pendingConnectDeviceId: String? // Track pending connection
    private var isUserInitiatedDisconnect = false // Track manual disconnects
    private var connectionTimer: Timer?
    private let connectionTimeout: TimeInterval = 10.0 // 10 seconds timeout
    private let operationDelay: TimeInterval = 0.5 // 500ms delay between operations
    
    // Auto-reconnection (simplified: scan + connect every 10 seconds until success)
    private var autoConnectEnabled = true
    private var reconnectAttempts = 0
    private let reconnectDelay: TimeInterval = 10.0 // Fixed 10-second delay between attempts
    private var isReconnecting = false // Track if reconnection is active
    private var pendingAutoConnectDeviceId: String? // Track device we're trying to auto-connect to
    private let lastDeviceIdKey = "LastConnectedDeviceId"
    private let lastDeviceNameKey = "LastConnectedDeviceName"
    private let autoConnectEnabledKey = "AutoConnectEnabled"
    
    // State change callbacks
    var onBluetoothStateChanged: ((CBManagerState) -> Void)?
    var onDeviceDiscovered: (([String: Any]) -> Void)?
    var onConnectionStateChanged: ((String, String) -> Void)? // (deviceId, state)
    
    private override init() {
        super.init()
        // Initialize with queue for background operations
        let queue = DispatchQueue(label: "com.liion.ble", qos: .userInitiated)
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }
    
    // MARK: - Public Methods
    
    /// Check if Bluetooth is enabled
    func isBluetoothEnabled() -> Bool {
        return bluetoothState == .poweredOn
    }
    
    /// Get current Bluetooth state
    func getBluetoothState() -> CBManagerState {
        return bluetoothState
    }
    
    /// Get Bluetooth state as string
    func getBluetoothStateString() -> String {
        return bluetoothStateToString(bluetoothState)
    }
    
    /// Get detailed Bluetooth status
    func getBluetoothStatus() -> [String: Any] {
        let stateString = bluetoothStateToString(bluetoothState)
        let isEnabled = bluetoothState == .poweredOn
        
        return [
            "state": stateString,
            "isEnabled": isEnabled,
            "canScan": isEnabled,
            "stateCode": bluetoothState.rawValue
        ]
    }
    
    /// Start the BLE service (just initializes, actual start happens automatically)
    func start() {
        logger.logInfo("BLE Service started")
        logger.logBleState("BLE Service initialized, state: \(bluetoothStateToString(bluetoothState))")
        
        // Load auto-connect preference
        loadAutoConnectPreference()
        
        // Try auto-connect if enabled and Bluetooth is on
        if autoConnectEnabled && bluetoothState == .poweredOn {
            attemptAutoConnect()
        }
    }
    
    /// Stop the BLE service
    func stop() {
        stopScan()
        cancelReconnect()
        if connectedPeripheral != nil {
            _ = disconnect()
        }
        logger.logInfo("BLE Service stopped")
    }
    
    // MARK: - Scanning Methods
    
    /// Start scanning for BLE devices
    /// Only discovers devices with "Leo Usb" in their name
    func startScan() -> [String: Any] {
        guard bluetoothState == .poweredOn else {
            let message = "Cannot start scan: Bluetooth is \(bluetoothStateToString(bluetoothState))"
            logger.logError(message)
            return [
                "success": false,
                "message": message,
                "state": bluetoothStateToString(bluetoothState)
            ]
        }
        
        if centralManager.isScanning {
            logger.logWarning("Scan already in progress")
            return [
                "success": false,
                "message": "Scan already in progress"
            ]
        }
        
        // Clear previous scan results
        discoveredDevices.removeAll()
        
        // Start scanning (no service UUID filter - scan all devices)
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        isScanning = true
        logger.logScan("Started BLE scan for devices containing '\(deviceNameFilter)'")
        
        return [
            "success": true,
            "message": "Scan started successfully"
        ]
    }
    
    /// Stop scanning for BLE devices
    func stopScan() -> [String: Any] {
        if !centralManager.isScanning {
            return [
                "success": false,
                "message": "Scan is not running"
            ]
        }
        
        centralManager.stopScan()
        isScanning = false
        logger.logScan("Stopped BLE scan")
        
        return [
            "success": true,
            "message": "Scan stopped successfully",
            "devicesFound": discoveredDevices.count
        ]
    }
    
    /// Check if currently scanning
    func isScanningDevices() -> Bool {
        return centralManager.isScanning
    }
    
    /// Get list of discovered devices (filtered)
    func getDiscoveredDevices() -> [[String: Any]] {
        let devicesList = Array(discoveredDevices.values)
        logger.logDebug("Returning \(devicesList.count) discovered Leo Usb devices")
        return devicesList
    }
    
    /// Clear discovered devices list
    func clearDiscoveredDevices() {
        let count = discoveredDevices.count
        discoveredDevices.removeAll()
        logger.logDebug("Cleared \(count) devices from scan list")
    }
    
    /// Check if device name matches filter
    private func shouldIncludeDevice(name: String?) -> Bool {
        guard let deviceName = name else {
            return false
        }
        
        // Case-insensitive search for "Leo Usb"
        return deviceName.lowercased().contains(deviceNameFilter.lowercased())
    }
    
    // MARK: - Connection Methods
    
    /// Connect to a BLE device by UUID
    func connect(deviceId: String, isFromReconnectScheduler: Bool = false) -> [String: Any] {
        guard bluetoothState == .poweredOn else {
            let message = "Cannot connect: Bluetooth is \(bluetoothStateToString(bluetoothState))"
            logger.logError(message)
            return [
                "success": false,
                "message": message
            ]
        }
        
        // If this is a manual connection (not from reconnect scheduler), handle special logic
        if !isFromReconnectScheduler {
            // Stop any ongoing reconnection
            if isReconnecting {
                logger.logInfo("Manual connection attempt, stopping reconnect scheduler")
                cancelReconnect()
                reconnectAttempts = 0
            }
            
            // Re-enable auto-connect when user manually connects (without triggering auto-connect)
            // This allows auto-reconnection for this new device
            if !autoConnectEnabled {
                logger.logInfo("Re-enabling auto-connect for manual connection")
                autoConnectEnabled = true
                UserDefaults.standard.set(true, forKey: autoConnectEnabledKey)
            }
        }
        
        // Check connection state (matching Android: if (connectionState != STATE_DISCONNECTED) return)
        if connectionState != .disconnected {
            let stateStr = connectionState == .connected ? "Already connected" : "Connection already in progress"
            logger.logWarning(stateStr)
            return [
                "success": false,
                "message": stateStr
            ]
        }
        
        // Find the peripheral
        guard let uuid = UUID(uuidString: deviceId) else {
            logger.logError("Invalid device UUID: \(deviceId)")
            return [
                "success": false,
                "message": "Invalid device ID"
            ]
        }
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals.first else {
            // Device not in cache - start scanning to find it (matching Android behavior)
            logger.logInfo("Device \(deviceId) not in cache, starting scan to find it...")
            
            // Set as pending auto-connect device so we connect when discovered
            pendingAutoConnectDeviceId = deviceId
            
            // Start scan
            let scanResult = startScan()
            if scanResult["success"] as? Bool == true {
                return [
                    "success": true,
                    "message": "Scanning for device..."
                ]
            } else {
                pendingAutoConnectDeviceId = nil
                return scanResult
            }
        }
        
        // Stop scanning before connecting (BLE best practice)
        if centralManager.isScanning {
            centralManager.stopScan()
            isScanning = false
            logger.logScan("Stopped scan before connection")
        }
        
        // Add delay before connecting (BLE stack stability)
        DispatchQueue.main.asyncAfter(deadline: .now() + operationDelay) { [weak self] in
            self?.performConnection(peripheral: peripheral)
        }
        
        return [
            "success": true,
            "message": "Connecting to device..."
        ]
    }
    
    /// Perform the actual connection
    private func performConnection(peripheral: CBPeripheral, isAutoConnect: Bool = false) {
        // Set connection state (matching Android: connectionState = STATE_CONNECTING)
        connectionState = .connecting
        pendingConnectDeviceId = peripheral.identifier.uuidString
        peripheral.delegate = self
        
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil (common when retrieving from cache)
        // This ensures we show the correct name during reconnection
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        if isAutoConnect {
            logger.logAutoConnect(address: deviceId)
        } else {
            logger.logConnect(address: deviceId, name: deviceName)
        }
        
        // Start connection timeout timer
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout(peripheral: peripheral)
        }
        
        // Connect to peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Handle connection timeout
    private func handleConnectionTimeout(peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        logger.logError("Connection timeout for device: \(deviceName)")
        
        // Set state back to disconnected
        connectionState = .disconnected
        pendingConnectDeviceId = nil
        isUserInitiatedDisconnect = false // Reset flag on timeout
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Cancel connection attempt
        centralManager.cancelPeripheralConnection(peripheral)
        
        // If reconnecting, schedule next attempt immediately
        if isReconnecting && autoConnectEnabled {
            logger.logInfo("Connection timeout during reconnect, scheduling next attempt...")
            scheduleReconnect(address: deviceId)
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "TIMEOUT")
    }
    
    /// Disconnect from current device
    func disconnect() -> [String: Any] {
        guard let peripheral = connectedPeripheral else {
            logger.logWarning("No device connected")
            return [
                "success": false,
                "message": "No device connected"
            ]
        }
        
        isUserInitiatedDisconnect = true // Mark as user-initiated
        cancelReconnect() // Stop reconnection scheduler
        reconnectAttempts = 0 // Reset attempt counter
        pendingAutoConnectDeviceId = nil // Clear pending auto-connect
        
        // IMPORTANT: Disable auto-connect when user manually disconnects
        // This prevents auto-reconnection on next app startup
        autoConnectEnabled = false
        UserDefaults.standard.set(false, forKey: autoConnectEnabledKey)
        logger.logInfo("Auto-connect disabled due to manual disconnect")
        
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        logger.logDisconnect(reason: "User requested disconnect from \(deviceName)")
        
        // Add delay before disconnecting (BLE stack stability)
        DispatchQueue.main.asyncAfter(deadline: .now() + operationDelay) { [weak self] in
            self?.centralManager.cancelPeripheralConnection(peripheral)
        }
        
        return [
            "success": true,
            "message": "Disconnecting from device..."
        ]
    }
    
    /// Check if currently connected
    func isConnected() -> Bool {
        guard let peripheral = connectedPeripheral else {
            return false
        }
        return peripheral.state == .connected
    }
    
    /// Get connected device info
    func getConnectedDevice() -> [String: Any]? {
        guard let peripheral = connectedPeripheral else {
            return nil
        }
        
        return [
            "id": peripheral.identifier.uuidString,
            "name": peripheral.name ?? "Unknown",
            "state": connectionStateToString(peripheral.state)
        ]
    }
    
    /// Get connection state as string
    private func connectionStateToString(_ state: CBPeripheralState) -> String {
        switch state {
        case .disconnected:
            return "DISCONNECTED"
        case .connecting:
            return "CONNECTING"
        case .connected:
            return "CONNECTED"
        case .disconnecting:
            return "DISCONNECTING"
        @unknown default:
            return "UNKNOWN"
        }
    }
    
    // MARK: - Auto-Connection Methods
    
    /// Enable or disable auto-connect
    func setAutoConnectEnabled(_ enabled: Bool) {
        autoConnectEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: autoConnectEnabledKey)
        logger.logInfo("Auto-connect \(enabled ? "enabled" : "disabled")")
        
        if !enabled {
            // Stop any ongoing reconnection attempts
            cancelReconnect()
            reconnectAttempts = 0
            logger.logInfo("Stopped all reconnection attempts")
        } else if enabled && connectedPeripheral == nil {
            // Re-enable auto-connect, try to connect if not connected
            if bluetoothState == .poweredOn {
                logger.logInfo("Auto-connect re-enabled, attempting connection")
                attemptAutoConnect()
            }
        }
    }
    
    /// Check if auto-connect is enabled
    func isAutoConnectEnabled() -> Bool {
        return autoConnectEnabled
    }
    
    /// Load auto-connect preference from UserDefaults
    private func loadAutoConnectPreference() {
        if UserDefaults.standard.object(forKey: autoConnectEnabledKey) != nil {
            autoConnectEnabled = UserDefaults.standard.bool(forKey: autoConnectEnabledKey)
        }
        logger.logDebug("Auto-connect preference loaded: \(autoConnectEnabled)")
    }
    
    /// Save last connected device
    private func saveLastConnectedDevice(deviceId: String, deviceName: String) {
        UserDefaults.standard.set(deviceId, forKey: lastDeviceIdKey)
        UserDefaults.standard.set(deviceName, forKey: lastDeviceNameKey)
        UserDefaults.standard.synchronize()
        logger.logInfo("Saved last connected device: \(deviceName)")
    }
    
    /// Get last connected device ID
    func getLastConnectedDeviceId() -> String? {
        return UserDefaults.standard.string(forKey: lastDeviceIdKey)
    }
    
    /// Get last connected device name
    func getLastConnectedDeviceName() -> String? {
        return UserDefaults.standard.string(forKey: lastDeviceNameKey)
    }
    
    /// Clear last connected device
    func clearLastConnectedDevice() {
        UserDefaults.standard.removeObject(forKey: lastDeviceIdKey)
        UserDefaults.standard.removeObject(forKey: lastDeviceNameKey)
        UserDefaults.standard.synchronize()
        logger.logInfo("Cleared last connected device")
    }
    
    /// Attempt auto-connect to last device
    /// Attempt auto-connect to last device (matching Android attemptAutoConnect)
    private func attemptAutoConnect() {
        // Matching Android: if (connectionState != STATE_DISCONNECTED) return
        if connectionState != .disconnected { return }
        if bluetoothState != .poweredOn { return }
        if !autoConnectEnabled { return }
        
        guard let savedAddress = getLastConnectedDeviceId() else { return }
        
        logger.logAutoConnect(address: savedAddress)
        
        // Try to connect (will auto-scan if device not in cache)
        _ = connect(deviceId: savedAddress)
    }
    
    /// Schedule reconnection (simplified: scan + connect every 10 seconds indefinitely)
    private func scheduleReconnect(address: String) {
        if !autoConnectEnabled { return }
        
        // Cancel any existing reconnect timer
        cancelReconnect()
        
        reconnectAttempts += 1
        isReconnecting = true
        let lastDeviceName = getLastConnectedDeviceName() ?? "Unknown"
        
        logger.logReconnect(attempt: reconnectAttempts, address: address)
        logger.logInfo("Reconnect attempt #\(reconnectAttempts) to \(lastDeviceName) (waiting \(Int(reconnectDelay))s)")
        
        // IMPORTANT: Use DispatchQueue.main.asyncAfter instead of Timer on background thread
        // Timers need a RunLoop which might not be running on background BLE queue
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self = self else { return }
            
            // Check if we should still try to reconnect
            guard self.autoConnectEnabled && self.connectionState == .disconnected && self.bluetoothState == .poweredOn else {
                self.logger.logInfo("Stopping reconnect: autoConnect=\(self.autoConnectEnabled), state=\(self.connectionState), BT=\(self.bluetoothStateToString(self.bluetoothState))")
                self.isReconnecting = false
                return
            }
            
            self.logger.logInfo("Executing reconnect attempt #\(self.reconnectAttempts): scanning and connecting...")
            
            // Start scan to find device (scan will stop automatically when we connect)
            _ = self.startScan()
            
            // Try to connect (mark as from reconnect scheduler so it doesn't cancel itself)
            // Note: Next attempt will be scheduled by timeout/failure/success handlers
            _ = self.connect(deviceId: address, isFromReconnectScheduler: true)
        }
    }
    
    /// Cancel reconnection
    private func cancelReconnect() {
        isReconnecting = false
        logger.logDebug("Cancelled reconnection scheduler")
    }
    
    /// Restart BLE scan (matching Android restartScan)
    private func restartScan() {
        stopScan()
        let _ = startScan()
    }
    
    /// Get current reconnect attempt count
    func getReconnectAttemptCount() -> Int {
        return reconnectAttempts
    }
    
    /// Check if currently attempting to reconnect
    func isCurrentlyReconnecting() -> Bool {
        return isReconnecting
    }
    
    // MARK: - Helper Methods
    
    private func bluetoothStateToString(_ state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "UNKNOWN"
        case .resetting:
            return "RESETTING"
        case .unsupported:
            return "UNSUPPORTED"
        case .unauthorized:
            return "UNAUTHORIZED"
        case .poweredOff:
            return "POWERED_OFF"
        case .poweredOn:
            return "POWERED_ON"
        @unknown default:
            return "UNKNOWN"
        }
    }
    
    private func logStateChange(_ state: CBManagerState) {
        let stateString = bluetoothStateToString(state)
        
        switch state {
        case .poweredOn:
            logger.logBleState("Bluetooth is ON")
        case .poweredOff:
            logger.logBleState("Bluetooth is OFF (turned off by user)")
        case .unauthorized:
            logger.logBleState("Bluetooth permission DENIED")
        case .unsupported:
            logger.logBleState("Bluetooth is UNSUPPORTED on this device")
        case .resetting:
            logger.logBleState("Bluetooth is RESETTING")
        case .unknown:
            logger.logBleState("Bluetooth state is UNKNOWN")
        @unknown default:
            logger.logBleState("Bluetooth state: \(stateString)")
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEService: CBCentralManagerDelegate {
    
    /// Called whenever the Bluetooth state changes
    /// This detects:
    /// - Bluetooth turned on/off from Settings
    /// - Bluetooth turned on/off from Control Center
    /// - Permission changes
    /// - System Bluetooth state changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        
        // Log the state change
        logStateChange(bluetoothState)
        
        // Notify listeners
        onBluetoothStateChanged?(bluetoothState)
        
        // Handle different states
        switch central.state {
        case .poweredOn:
            // Bluetooth is available and ready
            logger.logInfo("Bluetooth is ready for use")
            
            // Try auto-connect if enabled and not already connected
            if autoConnectEnabled && connectedPeripheral == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.attemptAutoConnect()
                }
            }
            
        case .poweredOff:
            // Bluetooth is turned off - inform user to enable it
            logger.logWarning("Bluetooth is turned off. Please enable Bluetooth to connect to devices.")
            
        case .unauthorized:
            // User denied Bluetooth permission
            logger.logError("Bluetooth permission denied. Please enable Bluetooth permission in Settings.")
            
        case .unsupported:
            // Device doesn't support Bluetooth (rare on modern iOS devices)
            logger.logError("This device does not support Bluetooth.")
            
        case .resetting:
            // Bluetooth is resetting, wait for next state update
            logger.logWarning("Bluetooth is resetting...")
            
        case .unknown:
            // Initial state, wait for actual state
            logger.logDebug("Bluetooth state is unknown, waiting for update...")
            
        @unknown default:
            logger.logWarning("Unknown Bluetooth state: \(central.state.rawValue)")
        }
    }
    
    /// Called when scanning discovers a peripheral
    func centralManager(_ central: CBCentralManager, 
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String : Any],
                       rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        
        // Only include devices matching our filter
        guard shouldIncludeDevice(name: peripheral.name) else {
            // Optionally log all discovered devices (for debugging)
            // logger.logDebug("Filtered out device: \(deviceName)")
            return
        }
        
        logger.logScan("Discovered Leo Usb device: \(deviceName), RSSI: \(RSSI) dB")
        
        // Create device info dictionary
        let deviceInfo: [String: Any] = [
            "id": deviceId,
            "name": deviceName,
            "rssi": RSSI.intValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add to discovered devices (or update if already exists)
        discoveredDevices[deviceId] = deviceInfo
        
        // Notify callback if set
        onDeviceDiscovered?(deviceInfo)
        
        // If this is a pending auto-connect device, connect to it (matching Android auto-connect behavior)
        if let pendingId = pendingAutoConnectDeviceId, pendingId == deviceId {
            logger.logInfo("Found pending auto-connect device: \(deviceName), connecting...")
            pendingAutoConnectDeviceId = nil // Clear pending
            
            // Connect after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.connectionState == .disconnected {
                    _ = self.connect(deviceId: deviceId)
                }
            }
        }
    }
    
    /// Called when a connection to a peripheral succeeds
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Clear connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Stop reconnection and reset attempts
        cancelReconnect()
        reconnectAttempts = 0
        
        // Set connection state
        connectionState = .connected
        connectedPeripheral = peripheral
        pendingConnectDeviceId = nil
        pendingAutoConnectDeviceId = nil // Clear pending auto-connect
        
        let deviceId = peripheral.identifier.uuidString
        
        // Get device name - prefer peripheral.name, fallback to saved name, then "Unknown"
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        // Save as last connected device (updates name if peripheral has it)
        saveLastConnectedDevice(deviceId: deviceId, deviceName: deviceName)
        
        logger.logConnected(address: deviceId, name: deviceName)
        
        // Stop scan if running
        if centralManager.isScanning {
            centralManager.stopScan()
            isScanning = false
            logger.logScan("Stopped scan after successful connection")
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "CONNECTED")
    }
    
    /// Called when a connection to a peripheral fails
    func centralManager(_ central: CBCentralManager, 
                       didFailToConnect peripheral: CBPeripheral, 
                       error: Error?) {
        // Clear connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Set state back to disconnected
        connectionState = .disconnected
        pendingConnectDeviceId = nil
        
        let deviceId = peripheral.identifier.uuidString
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        logger.logError("Failed to connect to \(deviceName): \(errorMsg)")
        
        // If reconnecting, schedule next attempt immediately
        if isReconnecting && autoConnectEnabled && !isUserInitiatedDisconnect {
            logger.logInfo("Connection failed during reconnect, scheduling next attempt...")
            scheduleReconnect(address: deviceId)
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "FAILED")
    }
    
    /// Called when a peripheral disconnects
    func centralManager(_ central: CBCentralManager, 
                       didDisconnectPeripheral peripheral: CBPeripheral, 
                       error: Error?) {
        // Only clear if this is our connected peripheral
        let wasOurDevice = connectedPeripheral?.identifier == peripheral.identifier
        if wasOurDevice {
            connectedPeripheral = nil
            connectionState = .disconnected
            pendingConnectDeviceId = nil
        }
        
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        // Check if this was a user-initiated disconnect
        if isUserInitiatedDisconnect {
            logger.logDisconnect(reason: "User-initiated disconnect from \(deviceName)")
            isUserInitiatedDisconnect = false // Reset flag
            cancelReconnect() // Stop any reconnection
            reconnectAttempts = 0 // Reset attempt counter
            // Don't attempt reconnect for user-initiated disconnects
        } else {
            // Unexpected disconnect - start reconnect scheduler (scan + connect every 10s indefinitely)
            let errorMsg = error?.localizedDescription ?? "Connection lost"
            logger.logDisconnect(reason: "Unexpected disconnect from \(deviceName): \(errorMsg)")
            
            if wasOurDevice && autoConnectEnabled {
                logger.logInfo("Unexpected disconnect, starting reconnect scheduler...")
                reconnectAttempts = 0 // Reset attempt counter for new reconnection sequence
                scheduleReconnect(address: deviceId)
            }
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "DISCONNECTED")
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    
    /// Called when peripheral services are discovered
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.logError("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            logger.logWarning("No services found")
            return
        }
        
        logger.logInfo("Discovered \(services.count) service(s)")
        
        // Will be used in next step for characteristic discovery
    }
    
    /// Called when peripheral characteristics are discovered
    func peripheral(_ peripheral: CBPeripheral, 
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        if let error = error {
            logger.logError("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            logger.logWarning("No characteristics found")
            return
        }
        
        logger.logInfo("Discovered \(characteristics.count) characteristic(s) for service: \(service.uuid)")
        
        // Will be used in next step for reading/writing data
    }
    
    /// Called when a characteristic value is updated
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.logError("Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        // Will be implemented in next step
        logger.logDebug("Characteristic updated: \(characteristic.uuid)")
    }
    
    /// Called when a characteristic value is written
    func peripheral(_ peripheral: CBPeripheral,
                   didWriteValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.logError("Error writing characteristic: \(error.localizedDescription)")
            return
        }
        
        // Will be implemented in next step
        logger.logDebug("Characteristic written: \(characteristic.uuid)")
    }
}


