import Foundation
import CoreBluetooth
import UIKit

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
    
    // UART UUIDs (matching Android)
    private let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    private let txCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // Write (app -> device)
    private let rxCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // Notify (device -> app)
    
    // UART characteristics
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var isUartReady = false
    
    // Track if initial setup commands have been sent (prevents duplicates)
    private var initialSetupDone = false
    private var uiReadyCommandsSent = false
    
    // Command queue (matching Android)
    private var commandQueue: [String] = []
    private var isProcessingCommand = false
    private let commandGapMs: TimeInterval = 0.25 // 250ms between commands
    
    // Charge limit state (matching Android)
    private var chargeLimit: Int = 88
    private var chargeLimitEnabled: Bool = false
    private var chargeLimitConfirmed: Bool = false
    private var chargingTimeSeconds: Int64 = 0
    private var dischargingTimeSeconds: Int64 = 0
    
    // Battery state
    private var phoneBatteryLevel: Int = -1
    private var isPhoneCharging: Bool = false
    
    // Charge limit timer (using DispatchSourceTimer for background queue compatibility)
    private var chargeLimitTimer: DispatchSourceTimer?
    private let chargeLimitIntervalSeconds: TimeInterval = 30.0 // 30 seconds (matching Android)
    
    // Time tracking timer (using DispatchSourceTimer for background queue compatibility)
    private var timeTrackingTimer: DispatchSourceTimer?
    private var lastChargingState: Bool?
    
    // Measure command timer (matching Android - every 30 seconds)
    private var measureTimer: DispatchSourceTimer?
    private let measureIntervalSeconds: TimeInterval = 30.0 // 30 seconds
    private let measureInitialDelaySeconds: TimeInterval = 25.0 // 25 seconds initial delay
    
    // Note: Battery metrics (current, voltage, temperature) are not implemented for iOS
    // iOS only provides battery level and charging state via UIDevice
    // For detailed battery metrics, see Android implementation
    
    // Measure data state (latest values from device)
    private var latestMeasureVoltage: Double = 0.0
    private var latestMeasureCurrent: Double = 0.0
    private var latestMwhValue: String = ""
    private var lastReceivedData: String = "" // Latest raw data received from device
    
    // Advanced modes state (matching Android)
    private var ledTimeoutSeconds: Int = 300
    private var ghostModeEnabled: Bool = false
    private var silentModeEnabled: Bool = false
    private var higherChargeLimitEnabled: Bool = false
    
    // UserDefaults keys (matching Android KEY_* constants)
    private let chargeLimitKey = "charge_limit"
    private let chargeLimitEnabledKey = "charge_limit_enabled"
    private let ledTimeoutKey = "led_timeout_seconds"
    private let ghostModeKey = "ghost_mode_enabled"
    private let silentModeKey = "silent_mode_enabled"
    private let higherChargeLimitKey = "higher_charge_limit_enabled"
    
    // Connection state (matching Android STATE_DISCONNECTED, STATE_CONNECTING, STATE_CONNECTED)
    private enum ConnectionState {
        case disconnected
        case connecting
        case connected
    }
    
    private var connectionState: ConnectionState = .disconnected
    private var connectedPeripheral: CBPeripheral?
    private var pendingConnectDeviceId: String? // Track pending connection
    private var connectionTimer: Timer?
    private let connectionTimeout: TimeInterval = 10.0 // 10 seconds timeout
    private let operationDelay: TimeInterval = 0.5 // 500ms delay between operations
    
    // Auto-reconnection (matching Android reconnect logic)
    private var autoConnectEnabled = true
    private var reconnectAttempts = 0
    private let reconnectDelayMs: TimeInterval = 2.0 // 2 seconds (matching Android RECONNECT_DELAY_MS)
    private let reconnectBackoffMs: TimeInterval = 1.0 // 1 second (matching Android RECONNECT_BACKOFF_MS)
    private let maxReconnectAttempts = 10 // Matching Android MAX_RECONNECT_ATTEMPTS
    private let reconnectCooldownMs: TimeInterval = 30.0 // 30 seconds cooldown after max attempts
    private var reconnectTimer: DispatchWorkItem? // Track scheduled reconnect
    private var pendingConnectAddress: String? // Track device address for reconnection
    private let lastDeviceIdKey = "LastConnectedDeviceId"
    private let lastDeviceNameKey = "LastConnectedDeviceName"
    private let autoConnectEnabledKey = "AutoConnectEnabled"
    
    // State change callbacks
    var onBluetoothStateChanged: ((CBManagerState) -> Void)?
    var onDeviceDiscovered: (([String: Any]) -> Void)?
    var onConnectionStateChanged: ((String, String) -> Void)? // (deviceId, state)
    
    // Data callbacks
    var onMeasureDataReceived: ((Double, Double) -> Void)? // (voltage, current)
    var onDataReceived: ((String) -> Void)? // (rawData) - matches Android dataReceivedStream
    var onAdvancedModesUpdate: ((Bool, Bool, Bool) -> Void)? // (ghostMode, silentMode, higherChargeLimit)
    var onLedTimeoutUpdate: ((Int) -> Void)? // (timeoutSeconds)
    
    private override init() {
        super.init()
        // Initialize with queue for background operations
        let queue = DispatchQueue(label: "nl.liionpower.app.ble", qos: .userInitiated)
        centralManager = CBCentralManager(delegate: self, queue: queue)
        
        // Load saved charge limit settings
        loadChargeLimitSettings()
        
        // Load saved advanced modes settings
        loadAdvancedModesSettings()
        
        // Setup battery monitoring
        setupBatteryMonitoring()
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
    
    /// Start the BLE service (matching Android: starts scanning immediately)
    func start() {
        logger.logInfo("BLE Service started")
        logger.logBleState("BLE Service initialized, state: \(bluetoothStateToString(bluetoothState))")
        
        // Load auto-connect preference
        loadAutoConnectPreference()
        
        // Start scanning immediately if Bluetooth is on (matching Android onStartCommand)
        if bluetoothState == .poweredOn {
            _ = startScan()
            
            // Try auto-connect if enabled
            if autoConnectEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.attemptAutoConnect()
                }
            }
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
    
    /// Start scanning for BLE devices (matching Android: cancel current scan and start new)
    /// Only discovers devices with "Leo Usb" in their name
    /// Scanning runs continuously without timeout (matching Android behavior)
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
        
        // Cancel current scan if running (matching Android restartScan behavior)
        if centralManager.isScanning {
            centralManager.stopScan()
            isScanning = false
            logger.logScan("Stopped current scan before starting new scan")
        }
        
        // Clear previous scan results
        discoveredDevices.removeAll()
        
        // Start scanning (no service UUID filter - scan all devices)
        // No timeout - scan runs continuously (matching Android)
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
//        logger.logDebug("Returning \(devicesList.count) discovered Leo Usb devices")
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
    
    /// Connect to a BLE device by UUID (matching Android connectToDevice)
    func connect(deviceId: String, userInitiated: Bool = true) -> [String: Any] {
        guard bluetoothState == .poweredOn else {
            let message = "Cannot connect: Bluetooth is \(bluetoothStateToString(bluetoothState))"
            logger.logError(message)
            return [
                "success": false,
                "message": message
            ]
        }
        
        // If user-initiated connection, handle special logic (matching Android)
        if userInitiated {
            // Cancel any ongoing reconnection
            cancelReconnect()
            reconnectAttempts = 0
            
            // Enable auto-reconnect when user manually connects (matching Android)
            autoConnectEnabled = true
            UserDefaults.standard.set(true, forKey: autoConnectEnabledKey)
            logger.logInfo("Auto-reconnect enabled for user-initiated connection")
        }
        
        // Find the peripheral
        guard let uuid = UUID(uuidString: deviceId) else {
            logger.logError("Invalid device UUID: \(deviceId)")
            return [
                "success": false,
                "message": "Invalid device ID"
            ]
        }
        
        // Properly close existing connection before connecting (matching Android: closeGatt)
        // This prevents status 133 errors
        if let existingPeripheral = connectedPeripheral {
            logger.logInfo("Closing existing connection before new connection")
            centralManager.cancelPeripheralConnection(existingPeripheral)
            connectedPeripheral = nil
            connectionState = .disconnected
            isUartReady = false
            txCharacteristic = nil
            rxCharacteristic = nil
        }
        
        // Small delay to let Bluetooth stack reset after closing (matching Android: Thread.sleep(100))
        Thread.sleep(forTimeInterval: 0.1)
        
        let peripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = peripherals.first else {
            // Device not in cache - start scanning to find it (matching Android behavior)
            logger.logInfo("Device \(deviceId) not in cache, starting scan to find it...")
            
            // Set as pending connect address so we connect when discovered
            pendingConnectAddress = deviceId
            
            // Start scan
            let scanResult = startScan()
            if scanResult["success"] as? Bool == true {
                return [
                    "success": true,
                    "message": "Scanning for device..."
                ]
            } else {
                pendingConnectAddress = nil
                return scanResult
            }
        }
        
        // Stop scanning before connecting (BLE best practice - matching Android)
        if centralManager.isScanning {
            centralManager.stopScan()
            isScanning = false
            logger.logScan("Stopped scan before connection")
        }
        
        // Set connection state (matching Android: connectionState = STATE_CONNECTING)
        connectionState = .connecting
        pendingConnectDeviceId = deviceId
        
        // Notify UI immediately that we're connecting (matching Android)
        onConnectionStateChanged?(deviceId, "CONNECTING")
        
        // Perform connection (matching Android: direct connect after delay)
        performConnection(peripheral: peripheral, userInitiated: userInitiated)
        
        return [
            "success": true,
            "message": "Connecting to device..."
        ]
    }
    
    /// Perform the actual connection (matching Android: proper delays and state management)
    private func performConnection(peripheral: CBPeripheral, userInitiated: Bool = true) {
        let deviceId = peripheral.identifier.uuidString
        peripheral.delegate = self
        
        // Use saved device name if peripheral.name is nil (common when retrieving from cache)
        // This ensures we show the correct name during reconnection
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Leo Usb"
        }
        
        if userInitiated {
            logger.logConnect(address: deviceId, name: deviceName)
        } else {
            logger.logAutoConnect(address: deviceId)
        }
        
        // Start connection timeout timer
        connectionTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout(peripheral: peripheral)
        }
        
        // Connect to peripheral (matching Android: direct connect)
        centralManager.connect(peripheral, options: nil)
    }
    
    /// Handle connection timeout (matching Android)
    private func handleConnectionTimeout(peripheral: CBPeripheral) {
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Leo Usb"
        }
        
        logger.logError("Connection timeout for device: \(deviceName)")
        
        // Set state back to disconnected
        connectionState = .disconnected
        pendingConnectDeviceId = nil
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Cancel connection attempt
        centralManager.cancelPeripheralConnection(peripheral)
        
        // Schedule reconnect if auto-reconnect is enabled (matching Android)
        if autoConnectEnabled && bluetoothState == .poweredOn {
            scheduleReconnect(address: deviceId)
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "TIMEOUT")
    }
    
    /// Disconnect from current device (matching Android disconnectDevice)
    func disconnect(userInitiated: Bool = true) -> [String: Any] {
        guard let peripheral = connectedPeripheral else {
            logger.logWarning("No device connected")
            return [
                "success": false,
                "message": "No device connected"
            ]
        }
        
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Leo Usb"
        }
        
        if userInitiated {
            logger.logDisconnect(reason: "User requested disconnect from \(deviceName)")
        } else {
            logger.logDisconnect(reason: "Disconnecting from \(deviceName)")
        }
        
        // Cancel reconnection (matching Android: cancelReconnect)
        cancelReconnect()
        
        // If user-initiated disconnect, disable auto-reconnect and clear saved device (matching Android)
        if userInitiated {
            autoConnectEnabled = false
            UserDefaults.standard.set(false, forKey: autoConnectEnabledKey)
            reconnectAttempts = 0
            clearLastConnectedDevice()
            logger.logInfo("Auto-reconnect disabled and saved device cleared due to user disconnect")
        }
        
        // Clear pending connect address
        pendingConnectAddress = nil
        pendingConnectDeviceId = nil
        
        // Clean up UART state (matching Android)
        isUartReady = false
        initialSetupDone = false
        uiReadyCommandsSent = false
        txCharacteristic = nil
        rxCharacteristic = nil
        chargeLimitConfirmed = false
        
        // Stop timers (matching Android)
        stopChargeLimitTimer()
        stopTimeTracking()
        stopMeasureTimer()
        
        // Disconnect peripheral
        centralManager.cancelPeripheralConnection(peripheral)
        
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
    
    /// Get connection state as int (matching Android: 0=disconnected, 1=connecting, 2=connected)
    func getConnectionState() -> Int {
        switch connectionState {
        case .disconnected:
            return 0
        case .connecting:
            return 1
        case .connected:
            return 2
        }
    }
    
    /// Get connected device info
    func getConnectedDevice() -> [String: Any]? {
        guard let peripheral = connectedPeripheral else {
            return nil
        }
        
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil (especially during auto-connect)
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Unknown"
        }
        
        return [
            "id": deviceId,
            "name": deviceName,
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
    
    /// Attempt auto-connect to last device (matching Android attemptAutoConnect)
    private func attemptAutoConnect() {
        // Matching Android: if (connectionState != STATE_DISCONNECTED) return
        if connectionState != .disconnected {
            logger.logDebug("Auto-connect skipped: connection state is \(connectionState), not disconnected")
            return
        }
        if bluetoothState != .poweredOn {
            logger.logDebug("Auto-connect skipped: Bluetooth is not powered on")
            return
        }
        if !autoConnectEnabled {
            logger.logDebug("Auto-connect skipped: auto-connect is disabled")
            return
        }
        
        guard let savedAddress = getLastConnectedDeviceId() else {
            logger.logDebug("Auto-connect skipped: no saved device ID found")
            return
        }
        
        logger.logAutoConnect(address: savedAddress)
        
        // Try to connect (matching Android: connectToDevice(savedAddress, userInitiated = false))
        // Note: This will scan if device not in cache, matching Android behavior
        _ = connect(deviceId: savedAddress, userInitiated: false)
    }
    
    /// Schedule reconnection (matching Android scheduleReconnect)
    private func scheduleReconnect(address: String) {
        if !autoConnectEnabled { return }
        
        // Cancel any existing reconnect timer (matching Android: cancelReconnect)
        cancelReconnect()
        
        // Calculate delay with backoff (matching Android logic)
        let delay: TimeInterval
        if reconnectAttempts >= maxReconnectAttempts {
            // After MAX_RECONNECT_ATTEMPTS, add longer cooldown and restart scan (matching Android)
            reconnectAttempts = 0
            logger.logInfo("Max reconnect attempts reached, waiting \(Int(reconnectCooldownMs))s before retry")
            restartScan() // Restart BLE scan to refresh device cache (matching Android)
            delay = reconnectCooldownMs
        } else {
            // Normal reconnect delay with backoff (matching Android: RECONNECT_DELAY_MS + (reconnectAttempts * RECONNECT_BACKOFF_MS))
            delay = reconnectDelayMs + (Double(reconnectAttempts) * reconnectBackoffMs)
        }
        
        reconnectAttempts += 1
        pendingConnectAddress = address
        
        logger.logReconnect(attempt: reconnectAttempts, address: address)
        
        // Schedule reconnect with calculated delay (matching Android: handler.postDelayed)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Check if we should still try to reconnect (matching Android conditions)
            guard self.autoConnectEnabled && 
                  self.connectionState == .disconnected && 
                  self.bluetoothState == .poweredOn else {
                self.logger.logInfo("Stopping reconnect: autoConnect=\(self.autoConnectEnabled), state=\(self.connectionState), BT=\(self.bluetoothStateToString(self.bluetoothState))")
                return
            }
            
            // Try to connect (matching Android: connectToDevice(address, userInitiated = false))
            _ = self.connect(deviceId: address, userInitiated: false)
        }
        
        reconnectTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    /// Cancel reconnection (matching Android cancelReconnect)
    private func cancelReconnect() {
        reconnectTimer?.cancel()
        reconnectTimer = nil
        logger.logDebug("Cancelled reconnection scheduler")
    }
    
    /// Restart BLE scan (matching Android restartScan: stop then start)
    func restartScan() {
        stopScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            _ = self?.startScan()
        }
    }
    
    /// Get current reconnect attempt count
    func getReconnectAttemptCount() -> Int {
        return reconnectAttempts
    }
    
    /// Check if currently attempting to reconnect
    func isCurrentlyReconnecting() -> Bool {
        return reconnectTimer != nil
    }
    
    // MARK: - Charge Limit Methods
    
    /// Set charge limit
    func setChargeLimit(limit: Int, enabled: Bool) -> [String: Any] {
        guard limit >= 0 && limit <= 100 else {
            return [
                "success": false,
                "message": "Charge limit must be between 0 and 100"
            ]
        }
        
        // Round to valid iOS battery percentage (iPhones use 5% increments)
        let roundedLimit = roundToValidIOSBatteryPercentage(limit)
        
        chargeLimit = roundedLimit
        chargeLimitEnabled = enabled
        
        // Save to UserDefaults
        UserDefaults.standard.set(roundedLimit, forKey: chargeLimitKey)
        UserDefaults.standard.set(enabled, forKey: chargeLimitEnabledKey)
        UserDefaults.standard.synchronize()
        
        logger.logChargeLimit(limit: roundedLimit, enabled: enabled)
        
        // Send command if connected
        if isUartReady && connectionState == .connected {
            sendChargeLimitCommand()
        }
        
        return [
            "success": true,
            "limit": roundedLimit, // Return rounded value so UI updates
            "enabled": enabled
        ]
    }
    
    /// Set charge limit enabled state
    func setChargeLimitEnabled(enabled: Bool) -> [String: Any] {
        chargeLimitEnabled = enabled
        
        // Save to UserDefaults
        UserDefaults.standard.set(enabled, forKey: chargeLimitEnabledKey)
        UserDefaults.standard.synchronize()
        
        // Send command if connected
        if isUartReady && connectionState == .connected {
            sendChargeLimitCommand()
        }
        
        return [
            "success": true,
            "enabled": enabled
        ]
    }
    
    /// Get charge limit info
    func getChargeLimitInfo() -> [String: Any] {
        return [
            "limit": chargeLimit,
            "enabled": chargeLimitEnabled,
            "confirmed": chargeLimitConfirmed,
            "chargingTime": chargingTimeSeconds,
            "dischargingTime": dischargingTimeSeconds
        ]
    }
    
    /// Get phone battery info
    func getPhoneBatteryInfo() -> [String: Any] {
        return [
            "level": phoneBatteryLevel, // Actual battery level from UIDevice
            "isCharging": isPhoneCharging,
            "currentMicroAmps": 0, // iOS doesn't provide this directly
            "roundedLevel": roundToValidIOSBatteryPercentage(phoneBatteryLevel) // Rounded to valid iOS value
        ]
    }
    
    /// Send a command to the device
    func sendCommand(_ command: String) -> [String: Any] {
        guard isUartReady && connectionState == .connected else {
            return [
                "success": false,
                "message": "Device not connected or UART not ready"
            ]
        }
        
        enqueueCommand(command)
        
        return [
            "success": true,
            "message": "Command queued"
        ]
    }
    
    /// Send UI-ready commands (mwh, swversion, chmode) - called once from Flutter when UI is ready
    /// This prevents Flutter from sending these commands repeatedly
    func sendUIReadyCommands() -> [String: Any] {
        guard isUartReady && connectionState == .connected else {
            return [
                "success": false,
                "message": "Device not connected or UART not ready"
            ]
        }
        
        // Prevent duplicate UI-ready commands
        guard !uiReadyCommandsSent else {
            logger.logDebug("UI-ready commands already sent, skipping duplicate")
            return [
                "success": false,
                "message": "UI-ready commands already sent"
            ]
        }
        
        uiReadyCommandsSent = true
        
        // Send UI-ready commands with delays (matching Android _scheduleInitialRequests timing)
        // 1. Request mwh value
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
            self.enqueueCommand("mwh")
        }
        
        // 2. Request firmware version (measure + swversion)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
            self.enqueueCommand("measure")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
                self.enqueueCommand("swversion")
            }
        }
        
        // 3. Request charging mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
            self.enqueueCommand("chmode")
        }
        
        logger.logInfo("UI-ready commands scheduled: mwh, measure+swversion, chmode")
        
        return [
            "success": true,
            "message": "UI-ready commands queued"
        ]
    }
    
    // MARK: - Advanced Modes Methods (matching Android)
    
    /// Get advanced modes state
    func getAdvancedModes() -> [String: Any] {
        return [
            "ghostMode": ghostModeEnabled,
            "silentMode": silentModeEnabled,
            "higherChargeLimit": higherChargeLimitEnabled
        ]
    }
    
    /// Set ghost mode
    func setGhostMode(enabled: Bool) -> [String: Any] {
        ghostModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: ghostModeKey)
        UserDefaults.standard.synchronize()
        
        if isUartReady && connectionState == .connected {
            let value = enabled ? 1 : 0
            enqueueCommand("app_msg ghost_mode \(value)")
            // Schedule refresh request after 200ms (matching Android)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                if self.isUartReady && self.connectionState == .connected {
                    self.enqueueCommand("app_msg ghost_mode")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if self.isUartReady && self.connectionState == .connected {
                            self.enqueueCommand("py_msg")
                        }
                    }
                }
            }
        }
        
        return ["success": true, "ghostMode": enabled]
    }
    
    /// Set silent mode (quiet_mode on device)
    func setSilentMode(enabled: Bool) -> [String: Any] {
        silentModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: silentModeKey)
        UserDefaults.standard.synchronize()
        
        if isUartReady && connectionState == .connected {
            let value = enabled ? 1 : 0
            enqueueCommand("app_msg quiet_mode \(value)")
            // Schedule refresh request after 200ms (matching Android)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                if self.isUartReady && self.connectionState == .connected {
                    self.enqueueCommand("app_msg quiet_mode")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if self.isUartReady && self.connectionState == .connected {
                            self.enqueueCommand("py_msg")
                        }
                    }
                }
            }
        }
        
        return ["success": true, "silentMode": enabled]
    }
    
    /// Set higher charge limit
    func setHigherChargeLimit(enabled: Bool) -> [String: Any] {
        higherChargeLimitEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: higherChargeLimitKey)
        UserDefaults.standard.synchronize()
        
        if isUartReady && connectionState == .connected {
            let value = enabled ? 1 : 0
            enqueueCommand("app_msg charge_limit \(value)")
            // Schedule refresh request after 200ms (matching Android)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                if self.isUartReady && self.connectionState == .connected {
                    self.enqueueCommand("app_msg charge_limit")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if self.isUartReady && self.connectionState == .connected {
                            self.enqueueCommand("py_msg")
                        }
                    }
                }
            }
        }
        
        return ["success": true, "higherChargeLimit": enabled]
    }
    
    /// Request advanced modes from device (matching Android requestAdvancedModesFromDevice)
    func requestAdvancedModes() -> [String: Any] {
        guard isUartReady && connectionState == .connected else {
            return ["success": false, "message": "Device not connected or UART not ready"]
        }
        
        // Request each mode with py_msg after each (matching Android)
        let modes = ["ghost_mode", "quiet_mode", "charge_limit"]
        var delayMs: TimeInterval = 0.0
        
        for (index, mode) in modes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayMs) { [weak self] in
                guard let self = self else { return }
                if self.isUartReady && self.connectionState == .connected {
                    self.enqueueCommand("app_msg \(mode)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.isUartReady && self.connectionState == .connected {
                            self.enqueueCommand("py_msg")
                        }
                    }
                }
            }
            delayMs += 0.45 // 450ms between each mode (matching Android)
        }
        
        return ["success": true, "message": "Advanced modes request queued"]
    }
    
    /// Set LED timeout
    func setLedTimeout(seconds: Int) -> [String: Any] {
        guard seconds >= 0 && seconds <= 99999 else {
            return ["success": false, "message": "Invalid timeout value"]
        }
        
        ledTimeoutSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: ledTimeoutKey)
        UserDefaults.standard.synchronize()
        
        if isUartReady && connectionState == .connected {
            enqueueCommand("app_msg led_time_before_dim \(seconds)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self else { return }
                if self.isUartReady && self.connectionState == .connected {
                    self.enqueueCommand("py_msg")
                }
            }
        }
        
        return ["success": true, "ledTimeout": seconds]
    }
    
    /// Request LED timeout from device
    func requestLedTimeout() -> [String: Any] {
        guard isUartReady && connectionState == .connected else {
            return ["success": false, "message": "Device not connected or UART not ready"]
        }
        
        enqueueCommand("app_msg led_time_before_dim")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            if self.isUartReady && self.connectionState == .connected {
                self.enqueueCommand("py_msg")
            }
        }
        
        return ["success": true, "message": "LED timeout request queued"]
    }
    
    /// Get LED timeout info
    func getLedTimeoutInfo() -> [String: Any] {
        return ["ledTimeout": ledTimeoutSeconds]
    }
    
    /// Get latest measure data
    func getMeasureData() -> [String: Any] {
        return [
            "voltage": String(format: "%.3f", latestMeasureVoltage),
            "current": String(format: "%.3f", latestMeasureCurrent)
        ]
    }
    
    /// Get last received raw data (matching Android dataReceivedStream)
    func getLastReceivedData() -> String {
        return lastReceivedData
    }
    
    // MARK: - Private Charge Limit Methods
    
    /// Load charge limit settings from UserDefaults
    private func loadChargeLimitSettings() {
        chargeLimit = UserDefaults.standard.integer(forKey: chargeLimitKey)
        if chargeLimit == 0 {
            chargeLimit = 88 // Default value
        }
        
        chargeLimitEnabled = UserDefaults.standard.bool(forKey: chargeLimitEnabledKey)
        
        logger.logInfo("Loaded charge limit settings: \(chargeLimit)%, enabled: \(chargeLimitEnabled)")
    }
    
    /// Load advanced modes settings from UserDefaults (matching Android)
    private func loadAdvancedModesSettings() {
        ledTimeoutSeconds = UserDefaults.standard.integer(forKey: ledTimeoutKey)
        if ledTimeoutSeconds == 0 {
            ledTimeoutSeconds = 300 // Default 300 seconds
        }
        
        ghostModeEnabled = UserDefaults.standard.bool(forKey: ghostModeKey)
        silentModeEnabled = UserDefaults.standard.bool(forKey: silentModeKey)
        higherChargeLimitEnabled = UserDefaults.standard.bool(forKey: higherChargeLimitKey)
        
        logger.logInfo("Loaded advanced modes: LED timeout: \(ledTimeoutSeconds)s, Ghost: \(ghostModeEnabled), Silent: \(silentModeEnabled), Higher charge: \(higherChargeLimitEnabled)")
    }
    
    /// Setup battery monitoring
    private func setupBatteryMonitoring() {
        // Enable battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // Get initial battery state
        updateBatteryState()
        
        // Observe battery level changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        // Observe battery state changes (charging/unplugged)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    /// Update battery state from UIDevice
    private func updateBatteryState() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        
        // batteryLevel returns -1.0 if monitoring is not enabled or if the device doesn't have a battery
        if level >= 0 {
            phoneBatteryLevel = Int(level * 100)
        } else {
            phoneBatteryLevel = -1
        }
        
        isPhoneCharging = (state == .charging || state == .full)
    }
    
    /// Handle battery level change notification
    @objc private func batteryLevelDidChange() {
        let oldLevel = phoneBatteryLevel
        updateBatteryState()
        
        let levelChanged = oldLevel != phoneBatteryLevel
        
        if levelChanged {
            logger.logDebug("Battery level changed: \(phoneBatteryLevel)%")
            
            // Send charge limit command on battery level change (matching Android)
            if isUartReady && connectionState == .connected {
                sendChargeLimitCommand()
            }
        }
    }
    
    /// Handle battery state change notification (charging/unplugged)
    @objc private func batteryStateDidChange() {
        let oldCharging = isPhoneCharging
        updateBatteryState()
        
        let chargingStateChanged = oldCharging != isPhoneCharging
        
        if chargingStateChanged {
            logger.logInfo("Battery charging state changed: \(isPhoneCharging ? "charging" : "not charging")")
            
            // Reset time counters when charging state changes (matching Android)
            if isPhoneCharging {
                chargingTimeSeconds = 0
            } else {
                dischargingTimeSeconds = 0
            }
            
            lastChargingState = isPhoneCharging
            
            // Send charge limit command on charging state change
            if isUartReady && connectionState == .connected {
                sendChargeLimitCommand()
            }
        }
    }
    
    /// Send charge limit command (matching Android sendChargeLimitCommand)
    /// Command format: "app_msg limit <limitValue> <batteryLevel> <chargingFlag> <timeValue>"
    private func sendChargeLimitCommand() {
        guard isUartReady && connectionState == .connected else { return }
        
        let limitValue = chargeLimitEnabled ? chargeLimit : 0
        let chargingFlag = isPhoneCharging ? 1 : 0
        let timeValue = isPhoneCharging ? chargingTimeSeconds : dischargingTimeSeconds
        
        // Round battery level to nearest valid iOS value (iPhones report in 5% increments after iPhone 8)
        let roundedBatteryLevel = roundToValidIOSBatteryPercentage(phoneBatteryLevel)
        
        // Log both actual and rounded values for debugging
        if phoneBatteryLevel != roundedBatteryLevel {
            logger.logDebug("Battery: actual \(phoneBatteryLevel)% → rounded \(roundedBatteryLevel)% (iOS valid values)")
        }
        
        let command = "app_msg limit \(limitValue) \(roundedBatteryLevel) \(chargingFlag) \(timeValue)"
        enqueueCommand(command)
    }
    
    /// Round battery percentage to nearest valid iOS value
    /// iPhones (after iPhone 8) report battery in increments of 5%
    /// Valid values: [0, 3, 8, 13, 18, 23, 28, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83, 88, 93, 98, 100]
    private func roundToValidIOSBatteryPercentage(_ value: Int) -> Int {
        // Generate valid percentages: [0, 3, 8] + [8, 13, 18, ..., 93] + [100]
        var validPercentages: [Int] = [0, 3, 8]
        
        // Add values from 8 to 93 in increments of 5 (18 values: 8, 13, 18, ..., 93)
        for index in 0..<18 {
            validPercentages.append(8 + (index * 5))
        }
        
        validPercentages.append(100)
        
        // Remove duplicates and sort (in case of duplicate 8)
        validPercentages = Array(Set(validPercentages)).sorted()
        
        // Find closest valid percentage
        let closest = validPercentages.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
        
        return closest
    }
    
    /// Start charge limit timer (matching Android startChargeLimitTimer)
    private func startChargeLimitTimer() {
        stopChargeLimitTimer()
        
        // Use DispatchSourceTimer for proper background queue operation
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + chargeLimitIntervalSeconds, repeating: chargeLimitIntervalSeconds)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isUartReady && self.connectionState == .connected {
                self.sendChargeLimitCommand()
            }
        }
        timer.resume()
        chargeLimitTimer = timer
    }
    
    /// Stop charge limit timer
    private func stopChargeLimitTimer() {
        chargeLimitTimer?.cancel()
        chargeLimitTimer = nil
    }
    
    /// Start time tracking (matching Android startTimeTracking)
    private func startTimeTracking() {
        stopTimeTracking()
        
        // Use DispatchSourceTimer for proper background queue operation
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: 1.0) // Fire every 1 second
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isPhoneCharging {
                self.chargingTimeSeconds += 1
            } else {
                self.dischargingTimeSeconds += 1
            }
        }
        timer.resume()
        timeTrackingTimer = timer
    }
    
    /// Stop time tracking
    private func stopTimeTracking() {
        timeTrackingTimer?.cancel()
        timeTrackingTimer = nil
    }
    
    /// Start measure command timer (matching Android startMeasureTimer)
    /// Sends "measure" command every 30 seconds with 25-second initial delay
    private func startMeasureTimer() {
        stopMeasureTimer()
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + measureInitialDelaySeconds, repeating: measureIntervalSeconds)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.isUartReady && self.connectionState == .connected {
                self.enqueueCommand("measure")
            }
        }
        timer.resume()
        measureTimer = timer
        logger.logInfo("Measure timer started (initial delay: \(measureInitialDelaySeconds)s, interval: \(measureIntervalSeconds)s)")
    }
    
    /// Stop measure command timer
    private func stopMeasureTimer() {
        measureTimer?.cancel()
        measureTimer = nil
    }
    
    // MARK: - UART Communication Methods
    
    /// Enqueue a command for sending (matching Android enqueueCommand)
    private func enqueueCommand(_ command: String) {
        guard isUartReady && connectionState == .connected else { return }
        
        commandQueue.append(command)
        
        if !isProcessingCommand {
            processCommandQueue()
        }
    }
    
    /// Process command queue (matching Android processCommandQueue)
    private func processCommandQueue() {
        guard !commandQueue.isEmpty else {
            isProcessingCommand = false
            return
        }
        
        isProcessingCommand = true
        let command = commandQueue.removeFirst()
        
        writeCommandImmediate(command)
        
        // Schedule next command after delay (matching Android COMMAND_GAP_MS)
        DispatchQueue.main.asyncAfter(deadline: .now() + commandGapMs) { [weak self] in
            self?.processCommandQueue()
        }
    }
    
    /// Write command immediately to TX characteristic (matching Android writeCommandImmediate)
    private func writeCommandImmediate(_ command: String) {
        guard isUartReady && connectionState == .connected else { return }
        guard let txChar = txCharacteristic else { return }
        guard let peripheral = connectedPeripheral else { return }
        
        logger.logCommand(command)
        
        // Add line feed to command (matching Android)
        let commandWithLF = command + "\n"
        guard let data = commandWithLF.data(using: .utf8) else { return }
        
        // Write without response for speed (matching Android WRITE_TYPE_DEFAULT)
        peripheral.writeValue(data, for: txChar, type: .withResponse)
    }
    
    /// Setup UART service after connection (matching Android setupUartService with delays)
    private func setupUartService() {
        guard let peripheral = connectedPeripheral else {
            logger.logWarning("Cannot setup UART service: no connected peripheral")
            return
        }
        
        // Double-check connection is still active
        guard connectionState == .connected && peripheral.state == .connected else {
            logger.logWarning("Cannot setup UART service: connection not active (state: \(connectionState), peripheral.state: \(peripheral.state))")
            return
        }
        
        logger.logInfo("Discovering services...")
        
        // Ensure peripheral delegate is set (critical for receiving callbacks)
        peripheral.delegate = self
        
        // Discover UART service (matching Android: gatt.discoverServices())
        // Note: CoreBluetooth will call didDiscoverServices callback when complete
        // This operation should complete within a few seconds, but CoreBluetooth handles timing
        peripheral.discoverServices([uartServiceUUID])
        
        logger.logDebug("Service discovery request sent for UART service")
    }
    
    /// Handle received data from RX characteristic (matching Android handleReceivedData)
    private func handleReceivedData(_ data: Data) {
        guard let receivedString = String(data: data, encoding: .utf8) else { return }
        let trimmedData = receivedString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        logger.logCommandResponse(trimmedData)
        
        // Store last received data for polling
        lastReceivedData = trimmedData
        
        // Send raw data to Flutter (matching Android dataReceivedStream)
        onDataReceived?(trimmedData)
        
        // Parse response
        let parts = trimmedData.components(separatedBy: " ")
        
        // Handle charge_limit response: "OK py_msg charge_limit <value>"
        if parts.count >= 4 && parts[2] == "charge_limit" {
            if let numeric = Int(parts[3].filter { $0.isNumber }) {
                chargeLimitConfirmed = (numeric == 1)
                logger.logInfo("Charge limit confirmed: \(chargeLimitConfirmed)")
            }
        }
        
        // Handle ghost_mode response
        if parts.count >= 4 && parts[2] == "ghost_mode" {
            if let numeric = Int(parts[3].filter { $0.isNumber }) {
                ghostModeEnabled = (numeric == 1)
                UserDefaults.standard.set(ghostModeEnabled, forKey: ghostModeKey)
                logger.logInfo("Ghost mode: \(ghostModeEnabled)")
                onAdvancedModesUpdate?(ghostModeEnabled, silentModeEnabled, higherChargeLimitEnabled)
            }
        }
        
        // Handle quiet_mode response (silent mode)
        if parts.count >= 4 && parts[2] == "quiet_mode" {
            if let numeric = Int(parts[3].filter { $0.isNumber }) {
                silentModeEnabled = (numeric == 1)
                UserDefaults.standard.set(silentModeEnabled, forKey: silentModeKey)
                logger.logInfo("Silent mode: \(silentModeEnabled)")
                onAdvancedModesUpdate?(ghostModeEnabled, silentModeEnabled, higherChargeLimitEnabled)
            }
        }
        
        // Handle LED timeout response: "OK py_msg led_time_before_dim <seconds>"
        if parts.count >= 4 && parts[2] == "led_time_before_dim" {
            let rawValue = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let numericOnly = rawValue.filter { $0.isNumber }
            if let parsed = Int(numericOnly) {
                ledTimeoutSeconds = parsed
                UserDefaults.standard.set(ledTimeoutSeconds, forKey: ledTimeoutKey)
                logger.logInfo("LED timeout: \(parsed)s")
                onLedTimeoutUpdate?(ledTimeoutSeconds)
            }
        }
        
        // Handle measure response: "OK measure voltage1 voltage2 current ... ... ... ... temp mode flags"
        // Full format matching Android:
        // parts[0] = "OK"
        // parts[1] = "measure"
        // parts[2] = voltage1
        // parts[3] = voltage2
        // parts[4] = current
        // parts[5-8] = other values
        // parts[9] = temperature
        // parts[10] = mode (0=smart, 1=ghost, 2=safe)
        // parts[11] = flags
        if parts.count >= 4 && parts[1] == "measure" {
            // Check if we have the full response (12 parts) or simplified (4 parts)
            if parts.count >= 12 {
                // Full response - extract all values
                if let voltage1 = Double(parts[2]),
                   let voltage2 = Double(parts[3]),
                   let current = Double(parts[4]) {
                    
                    // Use the higher voltage like Android does
                    let voltage = max(voltage1, voltage2)
                    latestMeasureVoltage = voltage
                    latestMeasureCurrent = abs(current)
                    
                    let voltageStr = String(format: "%.3f", voltage)
                    let currentStr = String(format: "%.3f", abs(current))
                    logger.logInfo("Measure: \(voltageStr)V, \(currentStr)A")
                    
                    // Send measure data to Flutter via callback
                    onMeasureDataReceived?(voltage, abs(current))
                    
                    // Extract and log charging mode if available
                    if let modeValue = Int(parts[10]) {
                        let modeStr = modeValue == 0 ? "smart" : (modeValue == 1 ? "ghost" : "safe")
                        logger.logInfo("Charging mode: \(modeStr)")
                    }
                }
            } else if let voltage = Double(parts[2]), let current = Double(parts[3]) {
                // Simplified response - just voltage and current
                latestMeasureVoltage = voltage
                latestMeasureCurrent = abs(current)
                
                let voltageStr = String(format: "%.3f", voltage)
                let currentStr = String(format: "%.3f", abs(current))
                logger.logInfo("Measure: \(voltageStr)V, \(currentStr)A")
                
                // Send measure data to Flutter via callback
                onMeasureDataReceived?(voltage, abs(current))
            }
        }
        
        // Handle mwh response: "OK mwh <value>"
        if parts.count >= 3 && parts[1].lowercased() == "mwh" {
            let mwhValue = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !mwhValue.isEmpty {
                // Store mwh value for polling
                latestMwhValue = mwhValue
                logger.logInfo("MWh value: \(mwhValue)")
            }
        }
        
        // Handle swversion response
        if parts.count >= 3 && parts[1].lowercased() == "swversion" {
            let versionValue = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !versionValue.isEmpty {
                logger.logInfo("Firmware version: \(versionValue)")
            }
        }
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
            
            // Ensure auto-connect preference is loaded (in case centralManagerDidUpdateState is called before start())
            loadAutoConnectPreference()
            
            // Start scanning immediately (matching Android: startBleScan() in onStartCommand)
            _ = startScan()
            
            // Try auto-connect if enabled and not already connected
            if autoConnectEnabled && connectedPeripheral == nil && connectionState == .disconnected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.attemptAutoConnect()
                }
            }
            
        case .poweredOff:
            // Bluetooth is turned off - clean up (matching Android)
            logger.logWarning("Bluetooth is turned off. Please enable Bluetooth to connect to devices.")
            stopScan()
            cancelReconnect()
            stopChargeLimitTimer()
            stopTimeTracking()
            stopMeasureTimer()
            if let peripheral = connectedPeripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            connectionState = .disconnected
            connectedPeripheral = nil
            pendingConnectDeviceId = nil
            pendingConnectAddress = nil
            isUartReady = false
            txCharacteristic = nil
            rxCharacteristic = nil
            discoveredDevices.removeAll()
            onConnectionStateChanged?("", "DISCONNECTED")
            
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
        
        // If this is a pending connect device, connect to it (matching Android auto-connect behavior)
        if let pendingId = pendingConnectAddress, pendingId == deviceId {
            logger.logInfo("Found pending connect device: \(deviceName), connecting...")
            pendingConnectAddress = nil // Clear pending
            
            // Stop scanning before connecting
            if centralManager.isScanning {
                centralManager.stopScan()
                isScanning = false
                logger.logScan("Stopped scan before connect")
            }
            
            // Connect directly to the discovered peripheral (more reliable than retrieving from cache)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.connectionState == .disconnected {
                    // Notify UI immediately that we're connecting
                    self.onConnectionStateChanged?(deviceId, "CONNECTING")
                    // Connect directly to the discovered peripheral
                    self.performConnection(peripheral: peripheral, userInitiated: false)
                }
            }
        }
    }
    
    /// Called when a connection to a peripheral succeeds (matching Android: proper delays)
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Clear connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Set connection state (matching Android: connectionState = STATE_CONNECTED)
        connectionState = .connected
        connectedPeripheral = peripheral
        
        // Stop reconnection and reset attempts (matching Android)
        cancelReconnect()
        reconnectAttempts = 0
        pendingConnectAddress = nil
        pendingConnectDeviceId = nil
        
        // CRITICAL: Set peripheral delegate BEFORE any operations (must be set for callbacks)
        peripheral.delegate = self
        
        let deviceId = peripheral.identifier.uuidString
        
        // Get device name - prefer peripheral.name, fallback to saved name, then "Leo Usb"
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Leo Usb"
        }
        
        // Save as last connected device and enable auto-reconnect (matching Android)
        saveLastConnectedDevice(deviceId: deviceId, deviceName: deviceName)
        autoConnectEnabled = true
        UserDefaults.standard.set(true, forKey: autoConnectEnabledKey)
        
        logger.logConnected(address: deviceId, name: deviceName)
        
        // Stop scan if running
        if centralManager.isScanning {
            centralManager.stopScan()
            isScanning = false
            logger.logScan("Stopped scan after successful connection")
        }
        
        // Notify UI immediately that we're connected
        onConnectionStateChanged?(deviceId, "CONNECTED")
        
        // Setup UART service with delay (matching Android: wait for connection to stabilize)
        // Android waits for MTU negotiation (which can take 1-2 seconds), iOS needs similar delay
        // Increased delay to ensure connection is fully stable before service discovery
        // Some devices need more time to be ready for service discovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            // Double-check connection is still active before discovering services
            if self.connectionState == .connected && peripheral.state == .connected {
                self.setupUartService()
            } else {
                self.logger.logWarning("Connection lost before service discovery, skipping setup")
            }
        }
    }
    
    /// Called when a connection to a peripheral fails (matching Android)
    func centralManager(_ central: CBCentralManager, 
                       didFailToConnect peripheral: CBPeripheral, 
                       error: Error?) {
        // Clear connection timeout timer
        connectionTimer?.invalidate()
        connectionTimer = nil
        
        // Set state back to disconnected (matching Android)
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
            deviceName = "Leo Usb"
        }
        
        logger.logError("Failed to connect to \(deviceName): \(errorMsg)")
        
        // Schedule reconnect if auto-reconnect is enabled (matching Android)
        // Android checks: shouldAutoReconnect && bluetoothAdapter?.isEnabled == true && previousAddress != null
        if autoConnectEnabled && bluetoothState == .poweredOn && deviceId == (pendingConnectAddress ?? getLastConnectedDeviceId()) {
            scheduleReconnect(address: deviceId)
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "FAILED")
    }
    
    /// Called when a peripheral disconnects (matching Android onConnectionStateChange STATE_DISCONNECTED)
    func centralManager(_ central: CBCentralManager, 
                       didDisconnectPeripheral peripheral: CBPeripheral, 
                       error: Error?) {
        // Only clear if this is our connected peripheral
        let wasConnected = connectedPeripheral?.identifier == peripheral.identifier
        let previousAddress = connectedPeripheral?.identifier.uuidString ?? pendingConnectAddress
        
        if wasConnected {
            // Clean up UART state (matching Android)
            connectionState = .disconnected
            connectedPeripheral = nil
            pendingConnectDeviceId = nil
            isUartReady = false
            initialSetupDone = false // Reset so initial setup runs again on next connection
            uiReadyCommandsSent = false // Reset so UI-ready commands can be sent again on next connection
            txCharacteristic = nil
            rxCharacteristic = nil
            chargeLimitConfirmed = false
            
            // Stop all timers (matching Android)
            stopChargeLimitTimer()
            stopTimeTracking()
            stopMeasureTimer()
        }
        
        let deviceId = peripheral.identifier.uuidString
        
        // Use saved device name if peripheral.name is nil
        let deviceName: String
        if let peripheralName = peripheral.name, !peripheralName.isEmpty {
            deviceName = peripheralName
        } else if let savedName = getLastConnectedDeviceName(), deviceId == getLastConnectedDeviceId() {
            deviceName = savedName
        } else {
            deviceName = "Leo Usb"
        }
        
        let errorMsg = error?.localizedDescription ?? "Connection lost"
        logger.logDisconnect(reason: "Disconnected from \(deviceName) (status: \(errorMsg), wasConnected: \(wasConnected))")
        
        // Schedule reconnect if auto-reconnect is enabled (matching Android logic)
        // Android checks: shouldAutoReconnect && bluetoothAdapter?.isEnabled == true && previousAddress != null
        // Android also checks: status != BluetoothGatt.GATT_SUCCESS || wasConnected
        if autoConnectEnabled && bluetoothState == .poweredOn && previousAddress != nil {
            if wasConnected || error != nil {
                scheduleReconnect(address: previousAddress!)
            }
        }
        
        // Notify callback
        onConnectionStateChanged?(deviceId, "DISCONNECTED")
    }
}

// MARK: - CBPeripheralDelegate

extension BLEService: CBPeripheralDelegate {
    
    /// Called when peripheral services are discovered (matching Android: proper delays)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Check connection is still active
        guard connectionState == .connected && peripheral.state == .connected else {
            logger.logWarning("Services discovered but connection lost (state: \(connectionState), peripheral.state: \(peripheral.state))")
            return
        }
        
        if let error = error {
            logger.logError("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            logger.logWarning("No services found")
            return
        }
        
        logger.logInfo("Discovered \(services.count) service(s)")
        
        // Find UART service and discover its characteristics with delay (matching Android)
        for service in services {
            if service.uuid == uartServiceUUID {
                logger.logInfo("Found UART service, discovering characteristics...")
                // Delay before discovering characteristics (matching Android delays)
                // Increased delay to ensure service discovery is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self = self else { return }
                    // Double-check connection is still active
                    if self.connectionState == .connected && peripheral.state == .connected {
                        peripheral.discoverCharacteristics([self.txCharacteristicUUID, self.rxCharacteristicUUID], for: service)
                    } else {
                        self.logger.logWarning("Connection lost before characteristic discovery")
                    }
                }
            }
        }
    }
    
    /// Called when peripheral characteristics are discovered (matching Android: proper delays)
    func peripheral(_ peripheral: CBPeripheral, 
                   didDiscoverCharacteristicsFor service: CBService,
                   error: Error?) {
        // Check connection is still active
        guard connectionState == .connected && peripheral.state == .connected else {
            logger.logWarning("Characteristics discovered but connection lost (state: \(connectionState), peripheral.state: \(peripheral.state))")
            return
        }
        
        if let error = error {
            logger.logError("Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            logger.logWarning("No characteristics found")
            return
        }
        
        logger.logInfo("Discovered \(characteristics.count) characteristic(s) for service: \(service.uuid)")
        
        // Setup UART characteristics with delay (matching Android delays)
        if service.uuid == uartServiceUUID {
            for characteristic in characteristics {
                if characteristic.uuid == txCharacteristicUUID {
                    txCharacteristic = characteristic
                    logger.logInfo("Found TX characteristic (write)")
                } else if characteristic.uuid == rxCharacteristicUUID {
                    rxCharacteristic = characteristic
                    logger.logInfo("Found RX characteristic (notify)")
                    
                    // Enable notifications for RX characteristic with delay (matching Android)
                    // Android waits for descriptor write, iOS uses setNotifyValue
                    // Increased delay to ensure characteristic discovery is complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        // Double-check connection is still active
                        if self.connectionState == .connected && peripheral.state == .connected {
                            peripheral.setNotifyValue(true, for: characteristic)
                        } else {
                            self.logger.logWarning("Connection lost before enabling notifications")
                        }
                    }
                }
            }
        }
    }
    
    /// Called when a characteristic notification state is updated
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateNotificationStateFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.logError("Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        // Check if RX notifications are enabled (matching Android onDescriptorWrite)
        if characteristic.uuid == rxCharacteristicUUID && characteristic.isNotifying {
            // Prevent duplicate initial setup (matching Android behavior - only once per connection)
            guard !isUartReady else {
                logger.logDebug("UART already ready, skipping duplicate initial setup")
                return
            }
            
            isUartReady = true
            logger.logInfo("UART ready - RX notifications enabled")
            
            // Start timers
            startChargeLimitTimer()
            startTimeTracking()
            startMeasureTimer()
            
            // Send initial commands ONCE when UART is ready (matching Android behavior)
            // These commands are sent from native code, not Flutter, to prevent duplicates
            
            // 1. Send initial charge limit command (matching Android 500ms delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
                self.sendChargeLimitCommand()
            }
            
            // 2. Fetch LED timeout value (matching Android 700ms delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
                _ = self.requestLedTimeout()
            }
            
            // 3. Fetch advanced modes state (matching Android 1100ms delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
                guard let self = self, self.isUartReady && self.connectionState == .connected else { return }
                _ = self.requestAdvancedModes()
            }
            
            // Mark initial setup as done
            initialSetupDone = true
        }
    }
    
    /// Called when a characteristic value is updated
    func peripheral(_ peripheral: CBPeripheral,
                   didUpdateValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.logError("Error reading characteristic: \(error.localizedDescription)")
            return
        }
        
        // Handle RX characteristic data (device -> app)
        if characteristic.uuid == rxCharacteristicUUID {
            if let data = characteristic.value {
                handleReceivedData(data)
            }
        }
    }
    
    /// Called when a characteristic value is written
    func peripheral(_ peripheral: CBPeripheral,
                   didWriteValueFor characteristic: CBCharacteristic,
                   error: Error?) {
        if let error = error {
            logger.logError("Error writing characteristic: \(error.localizedDescription)")
            return
        }
        
        // Write successful (matching Android onCharacteristicWrite)
        logger.logDebug("Characteristic written: \(characteristic.uuid)")
    }
}


