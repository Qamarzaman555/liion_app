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
    
    // Connection state
    private var connectedPeripheral: CBPeripheral?
    private var isConnecting = false
    private var isDisconnecting = false
    private var isUserInitiatedDisconnect = false // Track manual disconnects
    private var connectionTimer: Timer?
    private let connectionTimeout: TimeInterval = 10.0 // 10 seconds timeout
    private let operationDelay: TimeInterval = 0.5 // 500ms delay between operations
    
    // Auto-reconnection
    private var autoConnectEnabled = true
    private var reconnectAttempts = 0
    private let reconnectDelay: TimeInterval = 10.0 // Fixed 10 seconds between attempts
    private var reconnectTimer: Timer?
    private var isReconnecting = false
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
        cancelReconnectTimer()
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
    func connect(deviceId: String) -> [String: Any] {
        guard bluetoothState == .poweredOn else {
            let message = "Cannot connect: Bluetooth is \(bluetoothStateToString(bluetoothState))"
            logger.logError(message)
            return [
                "success": false,
                "message": message
            ]
        }
        
        // Check if already connected
        if let connected = connectedPeripheral, connected.identifier.uuidString == deviceId {
            logger.logWarning("Already connected to device: \(deviceId)")
            return [
                "success": false,
                "message": "Already connected to this device"
            ]
        }
        
        // Check if already connecting
        if isConnecting {
            logger.logWarning("Connection already in progress")
            return [
                "success": false,
                "message": "Connection already in progress"
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
            logger.logError("Device not found: \(deviceId)")
            return [
                "success": false,
                "message": "Device not found. Please scan first."
            ]
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
        isConnecting = true
        peripheral.delegate = self
        
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        
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
        guard isConnecting else { return }
        
        let deviceName = peripheral.name ?? "Unknown"
        logger.logError("Connection timeout for device: \(deviceName)")
        
        isConnecting = false
        isUserInitiatedDisconnect = false // Reset flag on timeout
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Cancel connection attempt
        centralManager.cancelPeripheralConnection(peripheral)
        
        // Notify callback
        onConnectionStateChanged?(peripheral.identifier.uuidString, "TIMEOUT")
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
        
        // Check if already disconnecting
        if isDisconnecting {
            logger.logWarning("Disconnection already in progress")
            return [
                "success": false,
                "message": "Disconnection already in progress"
            ]
        }
        
        isDisconnecting = true
        isUserInitiatedDisconnect = true // Mark as user-initiated
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        
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
            cancelReconnectTimer()
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
    private func attemptAutoConnect() {
        guard autoConnectEnabled else { return }
        
        guard let lastDeviceId = getLastConnectedDeviceId() else {
            logger.logDebug("No last connected device found")
            return
        }
        
        let lastDeviceName = getLastConnectedDeviceName() ?? "Unknown"
        logger.logInfo("Attempting auto-connect to last device: \(lastDeviceName)")
        
        // Try to connect
        let result = connect(deviceId: lastDeviceId)
        
        if result["success"] as? Bool != true {
            logger.logWarning("Auto-connect failed: \(result["message"] ?? "Unknown error")")
        }
    }
    
    /// Attempt reconnection after disconnect (unlimited attempts with 10s delay)
    private func attemptReconnect() {
        guard autoConnectEnabled else {
            logger.logDebug("Auto-connect disabled, stopping reconnection")
            isReconnecting = false
            return
        }
        
        guard let lastDeviceId = getLastConnectedDeviceId() else {
            logger.logDebug("No device to reconnect to")
            isReconnecting = false
            return
        }
        
        // Check if already trying to reconnect
        if isReconnecting && reconnectTimer != nil {
            logger.logDebug("Reconnection already in progress")
            return
        }
        
        isReconnecting = true
        reconnectAttempts += 1
        let lastDeviceName = getLastConnectedDeviceName() ?? "Unknown"
        
        logger.logReconnect(attempt: reconnectAttempts, address: lastDeviceId)
        logger.logInfo("Reconnect attempt #\(reconnectAttempts) to \(lastDeviceName) (waiting \(Int(reconnectDelay))s)")
        
        // Schedule reconnection with fixed 10-second delay
        cancelReconnectTimer()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if auto-connect is still enabled
            guard self.autoConnectEnabled else {
                self.logger.logInfo("Auto-connect disabled during reconnect, stopping")
                self.isReconnecting = false
                return
            }
            
            // Check Bluetooth state
            guard self.bluetoothState == .poweredOn else {
                self.logger.logWarning("Cannot reconnect: Bluetooth is \(self.bluetoothStateToString(self.bluetoothState))")
                self.isReconnecting = false
                // Will retry when Bluetooth turns back on
                return
            }
            
            // Check if already connected (shouldn't happen, but safety check)
            if self.connectedPeripheral != nil {
                self.logger.logInfo("Already connected, stopping reconnection")
                self.isReconnecting = false
                self.reconnectAttempts = 0
                return
            }
            
            // Attempt connection
            let result = self.connect(deviceId: lastDeviceId)
            
            if result["success"] as? Bool != true {
                self.logger.logWarning("Reconnect attempt #\(self.reconnectAttempts) failed: \(result["message"] ?? "Unknown")")
                
                // Keep trying indefinitely with fixed 10s delay
                self.attemptReconnect()
            }
            // If successful, connection delegate will handle success
        }
    }
    
    /// Cancel reconnect timer
    private func cancelReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        isReconnecting = false
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
    }
    
    /// Called when a connection to a peripheral succeeds
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Clear connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Clear reconnect timer and reset attempts
        cancelReconnectTimer()
        reconnectAttempts = 0
        
        isConnecting = false
        connectedPeripheral = peripheral
        
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        
        // Save as last connected device
        saveLastConnectedDevice(deviceId: deviceId, deviceName: deviceName)
        
        logger.logConnected(address: deviceId, name: deviceName)
        
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
        
        isConnecting = false
        
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        
        logger.logError("Failed to connect to \(deviceName): \(errorMsg)")
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "FAILED")
    }
    
    /// Called when a peripheral disconnects
    func centralManager(_ central: CBCentralManager, 
                       didDisconnectPeripheral peripheral: CBPeripheral, 
                       error: Error?) {
        isDisconnecting = false
        
        // Only clear if this is our connected peripheral
        let wasOurDevice = connectedPeripheral?.identifier == peripheral.identifier
        if wasOurDevice {
            connectedPeripheral = nil
        }
        
        let deviceName = peripheral.name ?? "Unknown"
        let deviceId = peripheral.identifier.uuidString
        
        // Check if this was a user-initiated disconnect
        if isUserInitiatedDisconnect {
            logger.logDisconnect(reason: "User-initiated disconnect from \(deviceName)")
            isUserInitiatedDisconnect = false // Reset flag
            // Don't attempt reconnect for user-initiated disconnects
        } else {
            // Unexpected disconnect - attempt reconnect if enabled
            let errorMsg = error?.localizedDescription ?? "Connection lost"
            logger.logDisconnect(reason: "Unexpected disconnect from \(deviceName): \(errorMsg)")
            
            if wasOurDevice && autoConnectEnabled {
                logger.logInfo("Unexpected disconnect, attempting reconnect...")
                attemptReconnect()
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
}

