import Foundation
import CoreBluetooth
import UIKit
import FirebaseFirestore
import FirebaseCore

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
    
    // Data Transfer Service UUIDs (File Streaming) - matching Android
    private let dataTransferServiceUUID = CBUUID(string: "41E2B910-D0E0-4880-8988-5D4A761B9DC7")
    private let dataTransmitCharUUID = CBUUID(string: "94D2C6E0-89B3-4133-92A5-15CCED3EE729")
    
    // OTA Service UUIDs - matching Android
    private let otaServiceUUID = CBUUID(string: "D6F1D96D-594C-4C53-B1C6-144A1DFDE6D8")
    private let otaDataCharUUID = CBUUID(string: "23408888-1F40-4CD8-9B89-CA8D45F8A5B0")
    private let otaControlCharUUID = CBUUID(string: "7AD671AA-21C0-46A4-B722-270E3AE3D830")
    
    // UART characteristics
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?
    private var isUartReady = false
    
    // File streaming characteristics
    private var fileStreamingCharacteristic: CBCharacteristic?

    // OTA characteristics
    private var otaDataCharacteristic: CBCharacteristic?
    private var otaControlCharacteristic: CBCharacteristic?
    
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
    private let serialNumberKey = "deviceSerialNumber"
    private let mwhKey = "deviceMwh"
    private let swversionKey = "deviceSwversion"
    
    // File streaming state (matching Android)
    private var fileStreamingAccumulatedData = ""
    private var isFileStreamingActive = false
    private var fileStreamingRequested = false
    private var getFilesRangePending = false
    private var getFilesRetryDone = false
    private var serialRequested = false
    private var serialNumber: String = ""
    private var firmwareVersion: String = ""
    
    // File streaming file management (matching Android)
    private var leoFirstFile = 0
    private var leoLastFile = 0
    private var currentFile = 0
    private var fileCheck = 0

    // OTA state variables (matching Android)
    private var isOtaInProgress = false
    private var otaCancelRequested = false
    private var otaProgress = 0
    private var otaTotalPackets = 0
    private var otaCurrentPacket = 0
    private let otaReadLock = DispatchSemaphore(value: 1)
    private var lastReadValue: Data?
    private let otaWriteLock = DispatchSemaphore(value: 0)
    private var otaWriteCompleted = false
    private var streamFileResponseReceived = false
    private var waitingForStreamFileResponse = false
    private var lastStreamFileCommandTime: TimeInterval = 0
    private var streamFileTimeoutWorkItem: DispatchWorkItem?
    private let streamFileTimeoutSeconds: TimeInterval = 10.0 // 10 seconds timeout
    
    // File streaming recovery timer
    private var fileStreamingRecoveryWorkItem: DispatchWorkItem?
    private let fileStreamingRecoveryIntervalSeconds: TimeInterval = 10.0 // Check every 10 seconds
    private let fileStreamingDelaySeconds: TimeInterval = 7.0 // 7 seconds delay after ETX
    
    // File streaming data processing (matching Android ChargeData)
    private struct ChargeData {
        let timestamp: Double
        let session: Int?
        let current: Double?
        let volt: Double?
        let soc: Int?
        let wh: Int?
        let mode: Int?
        let chargePhase: Int?
        let chargeTime: Int?
        let temperature: Double?
        let faultFlags: Int?
        let flags: Int?
        let chargeLimit: Int?
        let startupCount: Int?
        let chargeProfile: Int?
    }
    
    private var chargeDataList: [ChargeData] = []
    private var previousChargeData: ChargeData?
    private var processedDataPoints: Set<String> = []
    private var hasUnwantedCharacters = false
    private var currentSession = 0
    private var currentMode = 0
    private var currentChargeLimit = 0
    
    // Firebase Firestore (matching Android) - lazy initialization to ensure Firebase is configured first
    private lazy var firestore: Firestore = {
        return Firestore.firestore()
    }()
    private let collectionName = "IOS Testing Build 1.5.0 (51)"
    
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
    var onOtaProgress: ((Int, Bool, String?) -> Void)? // (progress, inProgress, message) - matching Android
    
    private override init() {
        super.init()
        // Initialize with queue for background operations
        let queue = DispatchQueue(label: "nl.liionpower.app.ble", qos: .userInitiated)
        centralManager = CBCentralManager(delegate: self, queue: queue)
        
        // Load saved charge limit settings
        loadChargeLimitSettings()
        
        // Load saved advanced modes settings
        loadAdvancedModesSettings()
        
        // Load serial number
        serialNumber = UserDefaults.standard.string(forKey: serialNumberKey) ?? ""
        
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
        
        // Reset file streaming state on disconnect (matching Android)
        serialRequested = false
        fileStreamingRequested = false
        getFilesRangePending = false
        getFilesRetryDone = false
        stopFileStreaming()
        stopFileStreamingRecovery()
        
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
    
    /// Get cached mWh value (saved from last "OK mwh <value>" response)
    func getCachedMwh() -> String {
        // Prefer in-memory cached value, fallback to persisted UserDefaults if empty
        if !latestMwhValue.isEmpty {
            logger.logInfo("Returning cached mWh from memory: \(latestMwhValue)")
            return latestMwhValue
        }
        if let persisted = UserDefaults.standard.string(forKey: mwhKey) {
            logger.logInfo("Returning cached mWh from UserDefaults: \(persisted)")
            return persisted
        }
        logger.logInfo("No cached mWh available")
        return ""
    }

    /// Get cached software version (saved from last "OK swversion <value>" response)
    func getCachedSwversion() -> String {
        // Prefer in-memory cached value, fallback to persisted UserDefaults if empty
        if !firmwareVersion.isEmpty {
            logger.logInfo("Returning cached swversion from memory: \(firmwareVersion)")
            return firmwareVersion
        }
        if let persisted = UserDefaults.standard.string(forKey: swversionKey) {
            logger.logInfo("Returning cached swversion from UserDefaults: \(persisted)")
            return persisted
        }
        logger.logInfo("No cached swversion available")
        return ""
    }
    
    // MARK: - File Streaming Methods (matching Android)
    
    /// Start file streaming (matching Android startFileStreaming)
    func startFileStreaming() -> [String: Any] {
        guard connectionState == .connected && isUartReady else {
            logger.logWarning("[FileStream] Cannot start file streaming - not connected or UART not ready")
            return ["success": false, "message": "Device not connected or UART not ready"]
        }
        
        return requestGetFiles()
    }
    
    /// Request get_files command (matching Android requestGetFiles)
    private func requestGetFiles() -> [String: Any] {
        guard connectionState == .connected && isUartReady else {
            logger.logWarning("[FileStream] Cannot request get_files - not connected or UART not ready")
            return ["success": false, "message": "Device not connected or UART not ready"]
        }
        
        logger.logInfo("[FileStream] ========================================")
        logger.logInfo("[FileStream] Starting file streaming process")
        logger.logInfo("[FileStream] Sending get_files command")
        logger.logInfo("[FileStream] ========================================")
        
        getFilesRangePending = true
        getFilesRetryDone = false
        streamFileTimeoutWorkItem?.cancel()
        
        enqueueCommand("app_msg get_files")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            if self.isUartReady && self.connectionState == .connected {
                self.enqueueCommand("py_msg")
                self.logger.logInfo("[FileStream] py_msg sent 300ms after get_files")
            }
        }
        
        // One-shot timeout to nudge range if still pending
        streamFileTimeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.getFilesRangePending && self.isUartReady && self.connectionState == .connected {
                self.logger.logWarning("[FileStream] get_files range still pending; sending py_msg reminder")
                self.enqueueCommand("py_msg")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: streamFileTimeoutWorkItem!)
        
        return ["success": true, "message": "get_files command sent"]
    }
    
    /// Start streaming a specific file (matching Android startFileStreaming)
    private func startFileStreamingForFile() {
        guard connectionState == .connected && isUartReady else {
            logger.logWarning("[FileStream] Cannot start file streaming - not connected or UART not ready")
            return
        }
        
        isFileStreamingActive = true
        currentFile = leoFirstFile
        streamFileResponseReceived = false
        waitingForStreamFileResponse = true
        lastStreamFileCommandTime = Date().timeIntervalSince1970
        
        logger.logInfo("[FileStream] Requesting file \(currentFile)")
        enqueueCommand("app_msg stream_file \(currentFile)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            if self.isUartReady && self.connectionState == .connected {
                self.enqueueCommand("py_msg")
            }
        }
    }
    
    /// Request next file (matching Android requestNextFile)
    private func requestNextFile() {
        guard connectionState == .connected && isUartReady else {
            logger.logWarning("[FileStream] Cannot request next file - not connected")
            return
        }
        
        streamFileResponseReceived = false
        waitingForStreamFileResponse = true
        lastStreamFileCommandTime = Date().timeIntervalSince1970
        cancelStreamFileTimeout()
        
        logger.logInfo("[FileStream] Requesting file \(currentFile)")
        enqueueCommand("app_msg stream_file \(currentFile)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            if self.isUartReady && self.connectionState == .connected {
                self.enqueueCommand("py_msg")
                // Start timeout after py_msg is sent
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    if !self.streamFileResponseReceived && self.currentFile >= self.leoFirstFile && self.currentFile <= self.leoLastFile {
                        self.startStreamFileTimeout()
                    }
                }
            }
        }
    }
    
    /// Start stream file timeout (matching Android startStreamFileTimeout)
    private func startStreamFileTimeout() {
        cancelStreamFileTimeout()
        
        streamFileTimeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.logger.logWarning("[FileStream] ========================================")
            self.logger.logWarning("[FileStream] Stream file timeout - no response received for file \(self.currentFile)")
            self.logger.logWarning("[FileStream] ========================================")
            
            self.streamFileResponseReceived = false
            self.waitingForStreamFileResponse = false
            self.isFileStreamingActive = false
            
            // Move to next file if available
            if self.currentFile < self.leoLastFile && self.connectionState == .connected {
                self.currentFile += 1
                self.logger.logInfo("[FileStream] Moving to next file due to timeout: \(self.currentFile)")
                self.requestNextFile()
            } else if self.currentFile == self.leoLastFile {
                // Retry last file once more
                self.logger.logInfo("[FileStream] Retrying last file due to timeout: \(self.currentFile)")
                self.requestNextFile()
            } else {
                self.logger.logInfo("[FileStream] Timeout on file beyond last file. Stopping file streaming.")
                self.stopFileStreaming()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + streamFileTimeoutSeconds, execute: streamFileTimeoutWorkItem!)
    }
    
    /// Cancel stream file timeout (matching Android cancelStreamFileTimeout)
    private func cancelStreamFileTimeout() {
        streamFileTimeoutWorkItem?.cancel()
        streamFileTimeoutWorkItem = nil
    }
    
    /// Stop file streaming (matching Android stopFileStreaming)
    private func stopFileStreaming() {
        isFileStreamingActive = false
        streamFileResponseReceived = false
        waitingForStreamFileResponse = false
        cancelStreamFileTimeout()
        stopFileStreamingRecovery()
        logger.logInfo("[FileStream] File streaming stopped")
    }
    
    /// Start file streaming recovery timer (matching Android startFileStreamingRecovery)
    private func startFileStreamingRecovery() {
        stopFileStreamingRecovery()
        
        fileStreamingRecoveryWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Check if we should restart file streaming
            if self.connectionState == .connected &&
                self.isUartReady &&
                self.leoFirstFile > 0 &&
                self.leoLastFile > 0 &&
                self.currentFile >= self.leoFirstFile &&
                self.currentFile <= self.leoLastFile &&
                !self.isFileStreamingActive {
                
                self.logger.logInfo("[FileStream] ========================================")
                self.logger.logInfo("[FileStream] Recovery: File streaming stopped but should be active")
                self.logger.logInfo("[FileStream] Recovery: Current file: \(self.currentFile), Range: \(self.leoFirstFile)-\(self.leoLastFile)")
                self.logger.logInfo("[FileStream] Recovery: Restarting file \(self.currentFile)")
                self.logger.logInfo("[FileStream] ========================================")
                
                // Restart streaming the current file
                self.requestNextFile()
            }
            
            // Schedule next check (only if we still have files to process)
            if self.leoFirstFile > 0 && self.leoLastFile > 0 && self.currentFile <= self.leoLastFile {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.fileStreamingRecoveryIntervalSeconds, execute: self.fileStreamingRecoveryWorkItem!)
            } else {
                self.logger.logDebug("[FileStream] Recovery timer stopping - all files processed or no valid range")
                self.fileStreamingRecoveryWorkItem = nil
            }
        }
        
        // Start the recovery timer
        DispatchQueue.main.asyncAfter(deadline: .now() + fileStreamingRecoveryIntervalSeconds, execute: fileStreamingRecoveryWorkItem!)
        logger.logDebug("[FileStream] Recovery timer started (checking every \(fileStreamingRecoveryIntervalSeconds)s)")
    }
    
    /// Stop file streaming recovery timer (matching Android stopFileStreamingRecovery)
    private func stopFileStreamingRecovery() {
        fileStreamingRecoveryWorkItem?.cancel()
        fileStreamingRecoveryWorkItem = nil
        logger.logDebug("[FileStream] Recovery timer stopped")
    }
    
    /// Process file streaming data (matching Android processFileStreamingData)
    private func processFileStreamingData(_ data: Data) {
        guard let receivedString = String(data: data, encoding: .utf8) else {
            logger.logError("[FileStream] Failed to decode file streaming data")
            return
        }
        
        logger.logDebug("[FileStream] Received \(data.count) bytes")
        
        // Append incoming data to accumulatedData
        fileStreamingAccumulatedData.append(receivedString)
        logger.logDebug("[FileStream] Accumulated data length: \(fileStreamingAccumulatedData.count)")
        
        // Split the accumulated data by newline (\n) to identify potential complete data points
        let allDataPoints = fileStreamingAccumulatedData.components(separatedBy: "\n")
        
        var stxDetected = false
        var etxDetected = false
        
        // Process all complete data points except the last one
        for i in 0..<(allDataPoints.count - 1) {
            var dataPoint = allDataPoints[i]
            
            // Detect and remove STX/ETX control characters
            if dataPoint.contains("\u{02}") {
                stxDetected = true
                dataPoint = dataPoint.replacingOccurrences(of: "\u{02}", with: "")
                logger.logInfo("[FileStream] STX detected in data point")
            }
            if dataPoint.contains("\u{03}") {
                etxDetected = true
                dataPoint = dataPoint.replacingOccurrences(of: "\u{03}", with: "")
                logger.logInfo("[FileStream] ETX detected in data point")
            }
            
            dataPoint = dataPoint.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty data points
            if dataPoint.isEmpty { continue }
            
            // Split the data into columns
            let columns = dataPoint.components(separatedBy: ";")
            
            // Backward compatibility: Only require valid timestamp (column 0)
            if columns.isEmpty || columns[0].isEmpty || columns[0].trimmingCharacters(in: .whitespaces).isEmpty {
                logger.logDebug("[FileStream] Skipped data with empty timestamp: \(String(dataPoint.prefix(50)))")
                continue
            }
            
            // Skip header rows
            if columns[0].trimmingCharacters(in: .whitespaces).lowercased() == "timestamp" {
                logger.logDebug("[FileStream] Skipped header row")
                continue
            }
            
            // Check for unwanted characters
            if dataPoint.contains("/") || dataPoint.contains("M") || dataPoint.contains("m") {
                hasUnwantedCharacters = true
                logger.logWarning("[FileStream] Found unwanted characters in data point")
            }
            
            // Check if the data point is already processed
            if !processedDataPoints.contains(dataPoint) {
                processedDataPoints.insert(dataPoint)
                
                // Parse the data point to ChargeData
                do {
                    // Parse timestamp (required field)
                    guard let timestampValue = parseDouble(columns[0]) else {
                        logger.logDebug("[FileStream] Skipped data with invalid timestamp: \(String(dataPoint.prefix(50)))")
                        continue
                    }
                    
                    let timestamp = timestampValue
                    
                    // Parse all fields with carry-forward logic
                    let session = getValueOrPrevious(index: 1, columns: columns, parser: parseInt) ?? previousChargeData?.session
                    let current = getValueOrPrevious(index: 2, columns: columns, parser: parseDouble) ?? previousChargeData?.current
                    let volt = getValueOrPrevious(index: 3, columns: columns, parser: parseDouble) ?? previousChargeData?.volt
                    let soc = getValueOrPrevious(index: 4, columns: columns, parser: parseInt) ?? previousChargeData?.soc
                    let wh = getValueOrPrevious(index: 5, columns: columns, parser: parseInt) ?? previousChargeData?.wh
                    let mode = getValueOrPrevious(index: 6, columns: columns, parser: parseInt) ?? previousChargeData?.mode
                    let chargePhase = getValueOrPrevious(index: 7, columns: columns, parser: parseInt) ?? previousChargeData?.chargePhase
                    let chargeTime = getValueOrPrevious(index: 8, columns: columns, parser: parseInt) ?? previousChargeData?.chargeTime
                    let temperature = getValueOrPrevious(index: 9, columns: columns, parser: parseDouble) ?? previousChargeData?.temperature
                    let faultFlags = getValueOrPrevious(index: 10, columns: columns, parser: parseInt) ?? previousChargeData?.faultFlags
                    let flags = getValueOrPrevious(index: 11, columns: columns, parser: parseInt) ?? previousChargeData?.flags
                    let chargeLimit = getValueOrPrevious(index: 12, columns: columns, parser: parseInt) ?? previousChargeData?.chargeLimit
                    let startupCount = getValueOrPrevious(index: 13, columns: columns, parser: parseInt) ?? previousChargeData?.startupCount
                    let chargeProfile = getValueOrPrevious(index: 14, columns: columns, parser: parseInt) ?? previousChargeData?.chargeProfile
                    
                    let dataEntry = ChargeData(
                        timestamp: timestamp,
                        session: session,
                        current: current,
                        volt: volt,
                        soc: soc,
                        wh: wh,
                        mode: mode,
                        chargePhase: chargePhase,
                        chargeTime: chargeTime,
                        temperature: temperature,
                        faultFlags: faultFlags,
                        flags: flags,
                        chargeLimit: chargeLimit,
                        startupCount: startupCount,
                        chargeProfile: chargeProfile
                    )
                    
                    // Update instance variables for backward compatibility
                    if let sessionValue = dataEntry.session {
                        currentSession = sessionValue
                    }
                    if let modeValue = dataEntry.mode {
                        currentMode = modeValue
                    }
                    if let chargeLimitValue = dataEntry.chargeLimit {
                        currentChargeLimit = chargeLimitValue
                    }
                    
                    // Update previous entry for next iteration
                    previousChargeData = dataEntry
                    chargeDataList.append(dataEntry)
                    
                    logger.logDebug("[FileStream] Parsed ChargeData: session=\(dataEntry.session ?? -1), timestamp=\(dataEntry.timestamp), total entries=\(chargeDataList.count)")
                    
                } catch {
                    logger.logError("[FileStream] Error parsing data: \(error.localizedDescription)")
                    // Try to create minimal entry with just timestamp
                    if let timestampValue = parseDouble(columns[0]) {
                        let minimalEntry = ChargeData(
                            timestamp: timestampValue,
                            session: previousChargeData?.session,
                            current: previousChargeData?.current,
                            volt: previousChargeData?.volt,
                            soc: previousChargeData?.soc,
                            wh: previousChargeData?.wh,
                            mode: previousChargeData?.mode,
                            chargePhase: previousChargeData?.chargePhase,
                            chargeTime: previousChargeData?.chargeTime,
                            temperature: previousChargeData?.temperature,
                            faultFlags: previousChargeData?.faultFlags,
                            flags: previousChargeData?.flags,
                            chargeLimit: previousChargeData?.chargeLimit,
                            startupCount: previousChargeData?.startupCount,
                            chargeProfile: previousChargeData?.chargeProfile
                        )
                        previousChargeData = minimalEntry
                        chargeDataList.append(minimalEntry)
                        logger.logDebug("[FileStream] Created minimal entry from malformed data")
                    }
                }
            }
        }
        
        // Retain the last (possibly incomplete) data point
        if !allDataPoints.isEmpty {
            var lastDataPoint = allDataPoints.last!
            if lastDataPoint.contains("\u{02}") {
                stxDetected = true
                lastDataPoint = lastDataPoint.replacingOccurrences(of: "\u{02}", with: "")
            }
            if lastDataPoint.contains("\u{03}") {
                etxDetected = true
                lastDataPoint = lastDataPoint.replacingOccurrences(of: "\u{03}", with: "")
            }
            fileStreamingAccumulatedData = lastDataPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            fileStreamingAccumulatedData = ""
        }
        
        // Handle start (STX) and end (ETX) indicators
        if stxDetected || fileStreamingAccumulatedData.contains("\u{02}") {
            logger.logInfo("[FileStream] ========================================")
            logger.logInfo("[FileStream] STX detected - Stream start for file \(currentFile)")
            logger.logInfo("[FileStream] ========================================")
            isFileStreamingActive = true
            streamFileResponseReceived = true
            waitingForStreamFileResponse = false
            previousChargeData = nil // Reset previous data for new stream
            chargeDataList.removeAll()
            processedDataPoints.removeAll()
            hasUnwantedCharacters = false
            // Cancel timeout since we received STX
            cancelStreamFileTimeout()
        }
        
        if etxDetected || fileStreamingAccumulatedData.contains("\u{03}") {
            logger.logInfo("[FileStream] ========================================")
            logger.logInfo("[FileStream] ETX detected - Stream end for file \(currentFile)")
            logger.logInfo("[FileStream] Processed \(chargeDataList.count) data entries")
            logger.logInfo("[FileStream] Session: \(currentSession), Mode: \(currentMode), ChargeLimit: \(currentChargeLimit)")
            logger.logInfo("[FileStream] ========================================")
            
            isFileStreamingActive = false
            cancelStreamFileTimeout()
            
            // Store data to Firebase/local storage using snapshot of current list
            let dataSnapshot = chargeDataList
            let fileNumberToDelete = currentFile
            
            if !hasUnwantedCharacters {
                storeDataToFirebase(dataSnapshot: dataSnapshot, fileNumber: fileNumberToDelete)
            } else {
                logger.logWarning("[FileStream] Skipping Firebase upload due to unwanted characters in data")
            }
            
            // Reset for next file
            fileStreamingAccumulatedData = ""
            chargeDataList.removeAll()
            previousChargeData = nil
            processedDataPoints.removeAll()
            hasUnwantedCharacters = false
            streamFileResponseReceived = false
            waitingForStreamFileResponse = false
            
            // Schedule next file command after delay
            scheduleNextFileStreamCommand()
        }
    }
    
    // Helper functions for parsing (matching Android)
    private func parseDouble(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        return Double(trimmed)
    }
    
    private func parseInt(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        return Int(trimmed)
    }
    
    private func getValueOrPrevious<T>(index: Int, columns: [String], parser: (String) -> T?) -> T? {
        if index < columns.count {
            if let parsed = parser(columns[index]) {
                return parsed
            }
        }
        // If parsing failed or column doesn't exist, use previous value
        guard let previous = previousChargeData else { return nil }
        switch index {
        case 1: return previous.session as? T
        case 2: return previous.current as? T
        case 3: return previous.volt as? T
        case 4: return previous.soc as? T
        case 5: return previous.wh as? T
        case 6: return previous.mode as? T
        case 7: return previous.chargePhase as? T
        case 8: return previous.chargeTime as? T
        case 9: return previous.temperature as? T
        case 10: return previous.faultFlags as? T
        case 11: return previous.flags as? T
        case 12: return previous.chargeLimit as? T
        case 13: return previous.startupCount as? T
        case 14: return previous.chargeProfile as? T
        default: return nil
        }
    }
    
    /// Schedule next file stream command after delay (matching Android scheduleNextFileStreamCommand)
    private func scheduleNextFileStreamCommand() {
        let delaySeconds = fileStreamingDelaySeconds
        logger.logInfo("[FileStream] ========================================")
        logger.logInfo("[FileStream] ETX detected - File stream complete")
        logger.logInfo("[FileStream] Starting \(Int(delaySeconds))s cooldown delay for BLE stack")
        logger.logInfo("[FileStream] Next file command will be ready after delay")
        logger.logInfo("[FileStream] ========================================")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self = self else { return }
            self.logger.logInfo("[FileStream] ========================================")
            self.logger.logInfo("[FileStream] Cooldown delay completed (\(Int(delaySeconds))s)")
            self.logger.logInfo("[FileStream] BLE stack is ready for next file stream")
            
            // Move to next file if available
            if self.currentFile < self.leoLastFile && self.connectionState == .connected && self.isUartReady {
                self.currentFile += 1
                self.logger.logInfo("[FileStream] Streaming next file: \(self.currentFile)")
                self.requestNextFile()
            } else if self.currentFile == self.leoLastFile {
                self.logger.logInfo("[FileStream] Completed last file (\(self.currentFile)). All files processed.")
                self.stopFileStreaming()
            } else {
                self.logger.logInfo("[FileStream] All files processed. Current: \(self.currentFile), Last: \(self.leoLastFile)")
                self.stopFileStreaming()
            }
            
            self.logger.logInfo("[FileStream] ========================================")
        }
    }
    
    /// Schedule next file after delay when file doesn't exist (matching Android scheduleNextFileAfterDelay)
    private func scheduleNextFileAfterDelay() {
        // Increment file number before scheduling delay
        if currentFile < leoLastFile {
            currentFile += 1
            logger.logInfo("[FileStream] File doesn't exist, will request next file: \(currentFile) after delay")
        } else {
            logger.logInfo("[FileStream] Reached last file (\(leoLastFile)), no more files to stream")
            stopFileStreaming()
            return
        }
        
        let delaySeconds = fileStreamingDelaySeconds
        logger.logInfo("[FileStream] ========================================")
        logger.logInfo("[FileStream] File doesn't exist - scheduling next file")
        logger.logInfo("[FileStream] Starting \(Int(delaySeconds))s cooldown delay for BLE stack")
        logger.logInfo("[FileStream] ========================================")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self = self else { return }
            self.logger.logInfo("[FileStream] ========================================")
            self.logger.logInfo("[FileStream] Cooldown delay completed (\(Int(delaySeconds))s)")
            
            // Request the next file
            if self.connectionState == .connected && self.isUartReady {
                self.logger.logInfo("[FileStream] Requesting next file: \(self.currentFile)")
                self.requestNextFile()
            } else {
                self.logger.logWarning("[FileStream] Cannot request next file - not connected or UART not ready")
                self.stopFileStreaming()
            }
            
            self.logger.logInfo("[FileStream] ========================================")
        }
    }
    
    /// Store data to Firebase (matching Android storeDataToFirebase)
    private func storeDataToFirebase(dataSnapshot: [ChargeData], fileNumber: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                self.logger.logInfo("[FileStream] ========================================")
                self.logger.logInfo("[FileStream] Starting Firebase storage process")
                self.logger.logInfo("[FileStream] Session: \(self.currentSession), Entries: \(dataSnapshot.count)")
                
                if dataSnapshot.isEmpty {
                    self.logger.logWarning("[FileStream] No data to upload, skipping")
                    return
                }
                
                // Get the list of sent sessions from UserDefaults
                let sentSessionsKey = "sentSessions_\(self.connectedPeripheral?.identifier.uuidString.replacingOccurrences(of: ":", with: "") ?? "")"
                var sentSessions = Set(UserDefaults.standard.stringArray(forKey: sentSessionsKey) ?? [])
                
                // Check if this session has already been sent
                if sentSessions.contains("\(self.currentSession)") {
                    self.logger.logInfo("[FileStream] Session \(self.currentSession) already sent to Firebase, skipping...")
                    return
                }
                
                // Get device info from UserDefaults
                if self.serialNumber.isEmpty {
                    self.serialNumber = UserDefaults.standard.string(forKey: self.serialNumberKey) ?? ""
                }
                let binFileName = self.firmwareVersion
                let appVersion = UserDefaults.standard.string(forKey: "appVersion") ?? "1.5.0"
                let appBuildNumber = UserDefaults.standard.string(forKey: "appBuildNumber") ?? "51"
                
                // Get device information
                let osVersion = UIDevice.current.systemVersion
                let deviceModel = UIDevice.current.model
                
                if self.serialNumber.isEmpty {
                    self.logger.logWarning("[FileStream] Serial number not available, skipping upload")
                    return
                }
                
                // Prepare the data for Firebase
                let firebaseData = dataSnapshot.map { chargeData -> [String: Any] in
                    // Convert flags to binary and extract individual boolean values
                    let flagsValue = chargeData.flags ?? 0
                    let binaryFlags = String(flagsValue, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
                    let ghostMode = binaryFlags.count > 7 && binaryFlags[binaryFlags.index(binaryFlags.startIndex, offsetBy: 7)] == "1"
                    let higherChargeLimit = binaryFlags.count > 6 && binaryFlags[binaryFlags.index(binaryFlags.startIndex, offsetBy: 6)] == "1"
                    let silent = binaryFlags.count > 5 && binaryFlags[binaryFlags.index(binaryFlags.startIndex, offsetBy: 5)] == "1"
                    
                    return [
                        "ts": chargeData.timestamp,
                        "c": chargeData.current as Any,
                        "v": chargeData.volt as Any,
                        "soc": chargeData.soc as Any,
                        "mwh": chargeData.wh as Any,
                        "cp": chargeData.chargePhase as Any,
                        "ct": chargeData.chargeTime as Any,
                        "temp": chargeData.temperature as Any,
                        "ff": chargeData.faultFlags as Any,
                        "cl": chargeData.chargeLimit as Any,
                        "sc": chargeData.startupCount as Any,
                        "cprofile": chargeData.chargeProfile as Any
                    ]
                }
                
                // Parse app version
                let versionParts = appVersion.components(separatedBy: ".")
                let major = Int(versionParts.first ?? "1") ?? 1
                let minor = versionParts.count > 1 ? (Int(versionParts[1]) ?? 5) : 5
                let patch = versionParts.count > 2 ? (Int(versionParts[2]) ?? 0) : 0
                let build = Int(appBuildNumber) ?? 124
                
                // Get flags from first entry
                let firstFlags = dataSnapshot.first?.flags ?? 0
                let binaryFlags = String(firstFlags, radix: 2).padding(toLength: 8, withPad: "0", startingAt: 0)
                let ghostMode = binaryFlags.count > 7 && binaryFlags[binaryFlags.index(binaryFlags.startIndex, offsetBy: 7)] == "1"
                let higherChargeLimit = binaryFlags.count > 6 && binaryFlags[binaryFlags.index(binaryFlags.startIndex, offsetBy: 6)] == "1"
                let silent = binaryFlags.count > 5 && binaryFlags[binaryFlags.index(binaryFlags.startIndex, offsetBy: 5)] == "1"
                
                // Construct the complete object to store
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd-MM-yyyy HH:mm:ss"
                dateFormatter.timeZone = TimeZone(identifier: "UTC")
                
                let fileNameFormatter = DateFormatter()
                fileNameFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                fileNameFormatter.timeZone = TimeZone(identifier: "UTC")
                
                let firebaseObject: [String: Any] = [
                    "model": "Leo",
                    "serial_number": self.serialNumber.components(separatedBy: "\\").first?.trimmingCharacters(in: .whitespaces) ?? self.serialNumber,
                    "firmware": binFileName.trimmingCharacters(in: .whitespaces),
                    "sw": [
                        "type": "Release",
                        "major": major,
                        "minor": minor,
                        "patch": patch,
                        "build": build
                    ],
                    "device": [
                        "type": "mobile",
                        "os": "iOS",
                        "version": osVersion,
                        "brand": "Apple",
                        "model": deviceModel
                    ],
                    "session": self.currentSession,
                    "mode": self.currentMode,
                    "flags": [
                        "charge_limit": self.currentChargeLimit,
                        "ghost_mode_beta": ghostMode,
                        "higher_charge_limit": higherChargeLimit,
                        "silent": silent
                    ],
                    "timestamp": Int(Date().timeIntervalSince1970),
                    "DateTime": dateFormatter.string(from: Date()),
                    "data": firebaseData
                ]
                
                // Generate a file name for Firebase
                let fileName = "\(fileNameFormatter.string(from: Date()))_\(self.serialNumber.trimmingCharacters(in: .whitespaces))_\(self.currentSession).json"
                
                self.logger.logInfo("[FileStream] Prepared Firebase object")
                self.logger.logDebug("[FileStream] File name: \(fileName)")
                self.logger.logDebug("[FileStream] Serial: \(self.serialNumber), Session: \(self.currentSession)")
                self.logger.logDebug("[FileStream] Data entries: \(firebaseData.count)")
                
                // Check connectivity
                if self.hasNetworkConnection() {
                    self.logger.logInfo("[FileStream] Internet connection available. Uploading to Firebase...")
                    self.uploadToFirebase(fileName: fileName, firebaseObject: firebaseObject, sessionId: "\(self.currentSession)", serialNumber: self.serialNumber, fileNumber: fileNumber)
                } else {
                    self.logger.logWarning("[FileStream] No internet connection. Saving data locally for later sync.")
                    self.saveToLocalStorage(serialNumber: self.serialNumber, sessionId: "\(self.currentSession)", fileName: fileName, firebaseObject: firebaseObject, fileNumber: fileNumber)
                }
                
            } catch {
                self.logger.logError("[FileStream] Error storing data to Firebase: \(error.localizedDescription)")
            }
        }
    }
    
    /// Upload to Firebase (matching Android uploadToFirebase)
    private func uploadToFirebase(fileName: String, firebaseObject: [String: Any], sessionId: String, serialNumber: String, fileNumber: Int) {
        let docId = fileName.replacingOccurrences(of: ".json", with: "")
        
        firestore.collection(collectionName).document(docId).setData(firebaseObject, merge: true) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.logError("[FileStream] Firebase upload failed: \(error.localizedDescription)")
                self.logger.logError("[FileStream] Saving data locally for later sync")
                self.saveToLocalStorage(serialNumber: serialNumber, sessionId: sessionId, fileName: fileName, firebaseObject: firebaseObject, fileNumber: fileNumber)
            } else {
                self.logger.logInfo("[FileStream] ========================================")
                self.logger.logInfo("[FileStream] Data successfully stored to Firebase!")
                self.logger.logInfo("[FileStream] Document ID: \(docId)")
                self.logger.logInfo("[FileStream] Session: \(sessionId)")
                self.logger.logInfo("[FileStream] ========================================")
                
                // Add this session to the list of sent sessions
                let sentSessionsKey = "sentSessions_\(self.connectedPeripheral?.identifier.uuidString.replacingOccurrences(of: ":", with: "") ?? "")"
                var sentSessions = Set(UserDefaults.standard.stringArray(forKey: sentSessionsKey) ?? [])
                sentSessions.insert(sessionId)
                UserDefaults.standard.set(Array(sentSessions), forKey: sentSessionsKey)
                
                // Remove from pending uploads if it was a retry
                let pendingKey = "pending_upload_\(serialNumber)_\(sessionId)"
                UserDefaults.standard.removeObject(forKey: pendingKey)
                UserDefaults.standard.removeObject(forKey: "\(pendingKey)_data")
                
                // Delete file from device after successful upload
                if fileNumber >= 0 && self.connectionState == .connected && self.isUartReady {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.enqueueCommand("app_msg rm_file \(fileNumber)")
                        self.logger.logInfo("[FileStream] Sent rm_file command for file \(fileNumber) after successful upload")
                    }
                } else if fileNumber < 0 {
                    self.logger.logWarning("[FileStream] Cannot delete file - invalid file number: \(fileNumber)")
                } else {
                    self.logger.logWarning("[FileStream] Cannot delete file \(fileNumber) - not connected or UART not ready")
                }
            }
        }
    }
    
    /// Save to local storage for later sync (matching Android saveToLocalStorage)
    private func saveToLocalStorage(serialNumber: String, sessionId: String, fileName: String, firebaseObject: [String: Any], fileNumber: Int) {
        let pendingKey = "pending_upload_\(serialNumber)_\(sessionId)"
        let pendingData: [String: Any] = [
            "sessionId": sessionId,
            "fileName": fileName,
            "serialNumber": serialNumber,
            "fileNumber": fileNumber,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: pendingData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            UserDefaults.standard.set(jsonString, forKey: pendingKey)
        }
        
        // Also save the firebase object
        if let firebaseJsonData = try? JSONSerialization.data(withJSONObject: firebaseObject),
           let firebaseJsonString = String(data: firebaseJsonData, encoding: .utf8) {
            UserDefaults.standard.set(firebaseJsonString, forKey: "\(pendingKey)_data")
        }
        
        logger.logInfo("[FileStream] Data saved locally for session \(sessionId). Will sync when online.")
    }
    
    /// Check network connection (matching Android connectivity check)
    private func hasNetworkConnection() -> Bool {
        // Simple check - in production, use proper network reachability
        // For now, assume connected if we can reach Firebase
        return true // Simplified - Firebase SDK handles retries
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
        
        // Discover all services (matching Android: gatt.discoverServices() discovers all services)
        // This will discover both UART service and file streaming service
        // Note: CoreBluetooth will call didDiscoverServices callback when complete
        // This operation should complete within a few seconds, but CoreBluetooth handles timing
        peripheral.discoverServices(nil) // nil = discover all services
        
        logger.logDebug("Service discovery request sent for all services")
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
                logger.logInfo("MWh value received and cached: \(mwhValue)")
                // Persist cached mWh to UserDefaults for persistence across restarts
                UserDefaults.standard.set(mwhValue, forKey: mwhKey)
                logger.logDebug("MWh value saved to UserDefaults under key '\(mwhKey)'")
            }
        }
        
        // Handle swversion response
        if parts.count >= 3 && parts[1].lowercased() == "swversion" {
            let versionValue = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !versionValue.isEmpty {
                firmwareVersion = versionValue
                logger.logInfo("Firmware version received and cached: \(versionValue)")
                // Persist firmware version to UserDefaults for persistence across restarts
                UserDefaults.standard.set(versionValue, forKey: swversionKey)
                logger.logDebug("Firmware version saved to UserDefaults under key '\(swversionKey)'")
            }
        }
        
        // Handle serial response (command: "serial" without py_msg) - matching Android
        if parts.count >= 3 && parts[1].lowercased() == "serial" {
            let serialValue = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
            if !serialValue.isEmpty {
                serialNumber = serialValue
                UserDefaults.standard.set(serialNumber, forKey: serialNumberKey)
                logger.logInfo("[FileStream] Serial received and saved: \(serialNumber)")
            }
        }
        
        // Handle get_files response: "OK py_msg get_files <startFile> <endFile>" - matching Android
        if parts.count >= 5 && parts[2] == "get_files" {
            logger.logInfo("[FileStream] get_files response raw parts: \(parts)")
            if let startFile = Int(parts[3]),
               let endFile = Int(parts[4]) {
                getFilesRangePending = false
                leoFirstFile = startFile
                leoLastFile = endFile
                currentFile = leoFirstFile
                
                logger.logInfo("[FileStream] ========================================")
                logger.logInfo("[FileStream] get_files response received")
                logger.logInfo("[FileStream] File range: \(startFile) to \(endFile)")
                logger.logInfo("[FileStream] Starting file streaming from file \(currentFile)")
                logger.logInfo("[FileStream] ========================================")
                
                // Start streaming from first file
                startFileStreamingForFile()
                // Start recovery timer to check if file streaming stops unexpectedly
                startFileStreamingRecovery()
                getFilesRangePending = false
                streamFileTimeoutWorkItem?.cancel()
            } else if getFilesRangePending {
                // One controlled retry of get_files + py_msg if range missing and not retried yet
                if !getFilesRetryDone {
                    getFilesRetryDone = true
                    logger.logWarning("[FileStream] get_files response missing range; scheduling one retry")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                        guard let self = self else { return }
                        if self.isUartReady && self.connectionState == .connected {
                            self.enqueueCommand("app_msg get_files")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                if self.isUartReady && self.connectionState == .connected {
                                    self.enqueueCommand("py_msg")
                                    self.logger.logInfo("[FileStream] py_msg sent after retry get_files")
                                }
                            }
                        }
                    }
                } else {
                    logger.logWarning("[FileStream] get_files response missing range after retry, aborting file stream start")
                    getFilesRangePending = false
                    streamFileTimeoutWorkItem?.cancel()
                }
            }
        }
        
        // Handle ERROR response when expecting stream_file (command was intercepted) - matching Android
        if parts.count >= 2 && parts[0] == "ERROR" && parts[1] == "py_msg" {
            let currentTime = Date().timeIntervalSince1970
            let timeSinceStreamFileCommand = currentTime - lastStreamFileCommandTime
            
            // Only treat as file streaming error if:
            // 1. We're waiting for stream_file response
            // 2. Current file is in valid range
            // 3. ERROR came within 3 seconds of sending stream_file command
            if waitingForStreamFileResponse &&
                currentFile >= leoFirstFile &&
                currentFile <= leoLastFile &&
                timeSinceStreamFileCommand > 0 &&
                timeSinceStreamFileCommand < 3.0 {
                
                logger.logWarning("[FileStream] ========================================")
                logger.logWarning("[FileStream] ERROR response received - stream_file command intercepted for file \(currentFile)")
                logger.logWarning("[FileStream] Time since stream_file command: \(Int(timeSinceStreamFileCommand * 1000))ms")
                logger.logWarning("[FileStream] Recovery timer will restart file streaming")
                logger.logWarning("[FileStream] ========================================")
                
                // Mark that we got a response (even though it's an error) and reset state
                streamFileResponseReceived = true
                waitingForStreamFileResponse = false
                cancelStreamFileTimeout()
                isFileStreamingActive = false
                // Recovery timer will detect this and restart
            } else if waitingForStreamFileResponse {
                logger.logDebug("[FileStream] ERROR py_msg received but not for file streaming (time since command: \(Int(timeSinceStreamFileCommand * 1000))ms, window: 0-3000ms)")
            }
        }
        
        // Handle stream_file response: "OK py_msg stream_file <fileCheck>" - matching Android
        // fileCheck: 1 = file exists and streaming started, -1 = file doesn't exist
        if parts.count >= 4 && parts[2] == "stream_file" {
            if let fileCheckValue = Int(parts[3]) {
                fileCheck = fileCheckValue
                streamFileResponseReceived = true
                waitingForStreamFileResponse = false
                cancelStreamFileTimeout()
                logger.logInfo("[FileStream] stream_file response: fileCheck=\(fileCheck) for file \(currentFile)")
                
                switch fileCheck {
                case 1:
                    // File exists and is being streamed, wait for ETX
                    logger.logInfo("[FileStream] File \(currentFile) exists and streaming started")
                    isFileStreamingActive = true
                    // Start timeout timer
                    startStreamFileTimeout()
                case -1:
                    // File doesn't exist, move to next file after delay
                    logger.logWarning("[FileStream] File \(currentFile) doesn't exist")
                    // Schedule next file request after delay
                    scheduleNextFileAfterDelay()
                default:
                    logger.logWarning("[FileStream] Unknown fileCheck value: \(fileCheck)")
                }
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

            // Reset OTA state on disconnection (matching Android)
            otaDataCharacteristic = nil
            otaControlCharacteristic = nil
            isOtaInProgress = false
            otaCancelRequested = false
            
            // Reset file streaming state on disconnection (matching Android)
            stopFileStreaming()
            stopFileStreamingRecovery()
            
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
        
        // Log all discovered services for debugging
        for service in services {
            logger.logDebug("Discovered service: \(service.uuid.uuidString)")
        }
        
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
            
            // Setup file streaming service (matching Android setupFileStreamingService)
            if service.uuid == dataTransferServiceUUID {
                logger.logInfo("[FileStream] Found file streaming service, discovering characteristics...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self = self else { return }
                    if self.connectionState == .connected && peripheral.state == .connected {
                        peripheral.discoverCharacteristics([self.dataTransmitCharUUID], for: service)
                    } else {
                        self.logger.logWarning("[FileStream] Connection lost before file streaming characteristic discovery")
                    }
                }
            }

            // Setup OTA service (matching Android setupOtaService)
            if service.uuid == otaServiceUUID {
                logger.logInfo("[OTA] Found OTA service, discovering characteristics...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self = self else { return }
                    if self.connectionState == .connected && peripheral.state == .connected {
                        peripheral.discoverCharacteristics([self.otaDataCharUUID, self.otaControlCharUUID], for: service)
                    } else {
                        self.logger.logWarning("[OTA] Connection lost before OTA characteristic discovery")
                    }
                }
            }
        }
        
        // Log if file streaming service was not found
        let foundFileStreamingService = services.contains { $0.uuid == dataTransferServiceUUID }
        if !foundFileStreamingService {
            logger.logWarning("[FileStream] File streaming service not found. Expected UUID: \(dataTransferServiceUUID.uuidString)")
            logger.logWarning("[FileStream] Available services: \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
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
        
        // Setup file streaming characteristics (matching Android setupFileStreamingService)
        if service.uuid == dataTransferServiceUUID {
            for characteristic in characteristics {
                if characteristic.uuid == dataTransmitCharUUID {
                    fileStreamingCharacteristic = characteristic
                    logger.logInfo("Found file streaming characteristic")
                    
                    // Enable notifications for file streaming
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        if self.connectionState == .connected && peripheral.state == .connected {
                            peripheral.setNotifyValue(true, for: characteristic)
                            self.logger.logInfo("[FileStream] File streaming notifications enabled")
                            
                            // Kick off get_files once notifications are active (matching Android)
                            if !self.fileStreamingRequested {
                                _ = self.requestGetFiles()
                                self.logger.logInfo("[FileStream] get_files requested automatically after enable")
                            }
                        }
                    }
                }
            }
        }

        // Setup OTA characteristics (matching Android setupOtaService)
        if service.uuid == otaServiceUUID {
            for characteristic in characteristics {
                if characteristic.uuid == otaDataCharUUID {
                    otaDataCharacteristic = characteristic
                    logger.logInfo("[OTA] Found OTA data characteristic")
                } else if characteristic.uuid == otaControlCharUUID {
                    otaControlCharacteristic = characteristic
                    logger.logInfo("[OTA] Found OTA control characteristic")

                    // Enable notifications for OTA control characteristic
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        if self.connectionState == .connected && peripheral.state == .connected {
                            peripheral.setNotifyValue(true, for: characteristic)
                            self.logger.logInfo("[OTA] OTA control notifications enabled")
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
            
            // 4. Request serial (one-shot, no py_msg needed) - matching Android 1700ms delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) { [weak self] in
                guard let self = self else { return }
                if !self.serialRequested &&
                    self.connectionState == .connected &&
                    self.isUartReady {
                    self.enqueueCommand("serial")
                    self.serialRequested = true
                    self.logger.logInfo("[FileStream] serial requested (no py_msg)")
                }
            }
            
            // 5. Start file listing once UART is ready and all initial commands are queued (send last) - matching Android 3000ms delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if !self.fileStreamingRequested &&
                    self.connectionState == .connected &&
                    self.fileStreamingCharacteristic != nil {
                    self.getFilesRangePending = false
                    self.getFilesRetryDone = false
                    self.fileStreamingRequested = (self.requestGetFiles()["success"] as? Bool) ?? false
                    self.logger.logInfo("[FileStream] get_files requested after UART ready (sent last): \(self.fileStreamingRequested)")
                }
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
        
        // Handle file streaming data (matching Android onCharacteristicChanged DATA_TRANSMIT_CHAR_UUID)
        if characteristic.uuid == dataTransmitCharUUID {
            if let data = characteristic.value {
                processFileStreamingData(data)
            }
        }

        // Handle OTA control characteristic response (matching Android onCharacteristicChanged OTA_CONTROL_CHAR_UUID)
        if characteristic.uuid == otaControlCharUUID {
            if let data = characteristic.value {
                logger.logDebug("[OTA] Received control response: \(data.map { String(format: "%02x", $0) }.joined())")
                otaReadLock.wait()
                lastReadValue = data
                otaReadLock.signal()
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
        
       

        // Handle OTA write completion (matching Android onCharacteristicWrite for OTA characteristics)
        if characteristic.uuid == otaDataCharUUID || characteristic.uuid == otaControlCharUUID {
            otaWriteCompleted = true
            otaWriteLock.signal()
        }
    }

    // MARK: - OTA Update Methods

    /// Start OTA update with firmware file path
    func startOtaUpdate(filePath: String) -> Bool {
        guard connectionState == .connected, let _ = connectedPeripheral else {
            logger.logError("[OTA] Cannot start OTA - device not connected")
            sendOtaProgress(0, inProgress: false, message: "Device not connected")
            return false
        }

        guard otaDataCharacteristic != nil && otaControlCharacteristic != nil else {
            logger.logError("[OTA] Cannot start OTA - OTA characteristics not found")
            sendOtaProgress(0, inProgress: false, message: "OTA characteristics not found. Device may not support OTA.")
            return false
        }

        if isOtaInProgress {
            logger.logWarning("[OTA] OTA already in progress")
            return false
        }

        return performStartOtaUpdate(filePath: filePath)
    }

    /// Perform the actual OTA update start (matching Android startOtaUpdate)
    private func performStartOtaUpdate(filePath: String) -> Bool {
        logger.logInfo("[OTA] Starting OTA update with file: \(filePath)")

        isOtaInProgress = true
        otaCancelRequested = false
        otaProgress = 0
        otaCurrentPacket = 0

        // Stop regular UART commands during OTA to avoid interference (matching Android)
        stopMeasureTimer()
        stopChargeLimitTimer()
        logger.logDebug("[OTA] Stopped regular UART timers for OTA")

        // Send initial progress
        sendOtaProgress(0, inProgress: true, message: "Reading firmware file...")

        // Read firmware file
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else {
            logger.logError("[OTA] Firmware file does not exist: \(filePath)")
            sendOtaProgress(0, inProgress: false, message: "Firmware file does not exist: \(filePath)")
            isOtaInProgress = false
            return false
        }

        do {
            let firmwareData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            logger.logInfo("[OTA] Firmware file read: \(firmwareData.count) bytes")

            if firmwareData.isEmpty {
                logger.logError("[OTA] Firmware file is empty")
                sendOtaProgress(0, inProgress: false, message: "Firmware file is empty")
                isOtaInProgress = false
                return false
            }

            // Optimized chunk size for fast iOS OTA - target 5-6 minute completion
            // iOS can handle larger packets reliably for much faster transfers
            let chunkSize = 512 // Larger chunks for speed while staying safe for iOS BLE
            otaTotalPackets = (firmwareData.count + chunkSize - 1) / chunkSize
            let actualChunkSize = chunkSize // Same as chunkSize for simplicity
            logger.logInfo("[OTA] Using chunk size: \(actualChunkSize), Total packets: \(otaTotalPackets)")

            // Check if device is still connected
            guard connectionState == .connected, let _ = connectedPeripheral else {
                logger.logError("[OTA] Device not connected")
                sendOtaProgress(0, inProgress: false, message: "Device not connected")
                isOtaInProgress = false
                return false
            }

            // Start OTA update in background thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.performOtaUpdate(firmwareData: firmwareData, chunkSize: chunkSize)
            }

            logger.logInfo("[OTA] OTA update thread started")
            return true

        } catch {
            logger.logError("[OTA] Exception reading firmware file: \(error.localizedDescription)")
            sendOtaProgress(0, inProgress: false, message: "Error reading firmware file: \(error.localizedDescription)")
            isOtaInProgress = false
            return false
        }
    }

    /// Cancel OTA update
    func cancelOtaUpdate() {
        logger.logInfo("[OTA] OTA update cancelled by user")
        otaCancelRequested = true
        sendOtaProgress(0, inProgress: false, message: "OTA cancelled")
    }

    /// Get OTA progress
    func getOtaProgress() -> Int {
        return otaProgress
    }

    /// Check if OTA is in progress
    func isOtaUpdateInProgress() -> Bool {
        return isOtaInProgress
    }

    /// Perform the actual OTA update (matching Android performOtaUpdate)
    private func performOtaUpdate(firmwareData: Data, chunkSize: Int) {
        guard let peripheral = connectedPeripheral else {
            logger.logError("[OTA] GATT is null in performOtaUpdate")
            sendOtaProgress(0, inProgress: false, message: "Bluetooth connection lost")
            isOtaInProgress = false
            return
        }

        guard let dataChar = otaDataCharacteristic else {
            logger.logError("[OTA] OTA data characteristic not found")
            sendOtaProgress(0, inProgress: false, message: "OTA data characteristic not found. Device may not support OTA.")
            isOtaInProgress = false
            return
        }

        guard let controlChar = otaControlCharacteristic else {
            logger.logError("[OTA] OTA control characteristic not found")
            sendOtaProgress(0, inProgress: false, message: "OTA control characteristic not found. Device may not support OTA.")
            isOtaInProgress = false
            return
        }

        logger.logInfo("[OTA] OTA characteristics found, proceeding with update")

        do {
            logger.logInfo("[OTA] Starting OTA update: \(firmwareData.count) bytes, \(otaTotalPackets) packets")

            // Basic firmware validation
            if firmwareData.isEmpty {
                logger.logError("[OTA] Firmware file is empty")
                sendOtaProgress(0, inProgress: false, message: "Firmware file is empty")
                isOtaInProgress = false
                return
            }

            // Check if firmware starts with reasonable data (not all zeros)
            let firstBytes = firmwareData.subdata(in: 0..<min(64, firmwareData.count))
            let allZeros = firstBytes.allSatisfy { $0 == 0 }
            if allZeros {
                logger.logError("[OTA] Firmware file appears to be all zeros - corrupted!")
                sendOtaProgress(0, inProgress: false, message: "Firmware file appears corrupted")
                isOtaInProgress = false
                return
            }

            // Log firmware header for debugging
            let headerLength = min(32, firmwareData.count)
            let headerBytes = firmwareData.subdata(in: 0..<headerLength)
            logger.logInfo("[OTA] Firmware header: \(headerBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")

            // Calculate simple checksum
            var checksum: UInt8 = 0
            for i in 0..<min(16, firmwareData.count) {
                checksum = (checksum &+ firmwareData[i]) & 0xFF
            }
            logger.logInfo("[OTA] Firmware header checksum: \(checksum)")

            // Get MTU size (use default MTU for iOS - CoreBluetooth handles MTU negotiation)
            let mtuSize = 250 // iOS typically uses larger MTU
            let actualChunkSize = min(chunkSize, mtuSize - 3)
            // Recalculate total packets with the actual chunk size
            otaTotalPackets = (firmwareData.count + actualChunkSize - 1) / actualChunkSize
            logger.logInfo("[OTA] MTU: \(mtuSize), Chunk size: \(actualChunkSize), Total packets: \(otaTotalPackets)")

            // Write chunk size to data characteristic (iOS adaptation - send actual chunk size)
            let mtuBytes = Data([UInt8(actualChunkSize & 0xFF), UInt8((actualChunkSize >> 8) & 0xFF)])
            logger.logInfo("[OTA] Writing chunk size \(actualChunkSize) to data characteristic")
            if !writeOtaCharacteristic(peripheral: peripheral, characteristic: dataChar, data: mtuBytes, waitForCompletion: true) {
                logger.logError("[OTA] Failed to write MTU size")
                sendOtaProgress(0, inProgress: false, message: "Failed to write MTU size")
                isOtaInProgress = false
                return
            }

            // Write 0x01 to control characteristic to start OTA
            logger.logInfo("[OTA] Writing 0x01 to control characteristic to start OTA")
            if !writeOtaCharacteristic(peripheral: peripheral, characteristic: controlChar, data: Data([0x01]), waitForCompletion: true) {
                logger.logError("[OTA] Failed to start OTA")
                sendOtaProgress(0, inProgress: false, message: "Failed to start OTA")
                isOtaInProgress = false
                return
            }

            // Wait for device response
            Thread.sleep(forTimeInterval: 0.2)

            // Read response from control characteristic
            logger.logInfo("[OTA] Reading response from control characteristic")
            guard let response = readOtaCharacteristicSync(peripheral: peripheral, characteristic: controlChar, timeoutMs: 2000) else {
                logger.logError("[OTA] No response from device")
                sendOtaProgress(0, inProgress: false, message: "No response from device")
                isOtaInProgress = false
                return
            }

            if response.isEmpty || response[0] != 2 {
                let responseStr = response.isEmpty ? "no response" : String(response[0])
                logger.logError("[OTA] Device not ready for OTA. Response: \(responseStr)")
                sendOtaProgress(0, inProgress: false, message: "Device not ready for OTA (response: \(responseStr))")
                isOtaInProgress = false
                return
            }

            logger.logInfo("[OTA] Device ready for OTA. Starting firmware transfer...")

            // Send firmware chunks with retry logic and proper flow control
            var packetNumber = 0
            var consecutiveFailures = 0
            let maxConsecutiveFailures = 5
            let retryDelayMs: TimeInterval = 0.05 // 50ms

            let firmwareBytes = [UInt8](firmwareData)

            for i in stride(from: 0, to: firmwareBytes.count, by: actualChunkSize) {
                if otaCancelRequested {
                    logger.logInfo("[OTA] OTA cancelled by user")
                    _ = writeOtaCharacteristic(peripheral: peripheral, characteristic: controlChar, data: Data([0x04]), waitForCompletion: false)
                    sendOtaProgress(0, inProgress: false, message: "OTA cancelled")
                    isOtaInProgress = false
                    return
                }

                let end = min(i + actualChunkSize, firmwareBytes.count)
                let chunk = Array(firmwareBytes[i..<end])

                if packetNumber % 100 == 0 || packetNumber < 10 {
                    logger.logInfo("[OTA] Writing packet \(packetNumber)/\(otaTotalPackets) (\(chunk.count) bytes)")
                }

                // Retry logic for packet writes
                var writeSuccess = false
                var retryCount = 0
                let maxRetries = 3

                while !writeSuccess && retryCount < maxRetries && !otaCancelRequested {
                    // Wait for completion to prevent overlapping writes
                    writeSuccess = writeOtaCharacteristic(peripheral: peripheral, characteristic: dataChar, data: Data(chunk), waitForCompletion: true)

                    if !writeSuccess {
                        retryCount += 1
                        consecutiveFailures += 1
                        logger.logWarning("[OTA] Failed to write packet \(packetNumber) (attempt \(retryCount)/\(maxRetries))")

                        if consecutiveFailures >= maxConsecutiveFailures {
                            logger.logError("[OTA] Too many consecutive failures (\(consecutiveFailures)). Aborting OTA.")
                            sendOtaProgress(0, inProgress: false, message: "Failed to write packet \(packetNumber) after \(consecutiveFailures) consecutive failures")
                            isOtaInProgress = false
                            return
                        }

                        // Exponential backoff: 50ms, 100ms, 200ms
                        let backoffDelay = retryDelayMs * pow(2.0, Double(retryCount - 1))
                        logger.logDebug("[OTA] Retrying packet \(packetNumber) after \(backoffDelay)s delay")
                        Thread.sleep(forTimeInterval: backoffDelay)
                    } else {
                        consecutiveFailures = 0 // Reset on success
                    }
                }

                if !writeSuccess {
                    logger.logError("[OTA] Failed to write packet \(packetNumber) after \(maxRetries) attempts")
                    sendOtaProgress(0, inProgress: false, message: "Failed to write packet \(packetNumber) after \(maxRetries) attempts")
                    isOtaInProgress = false
                    return
                }

                // Small delay after successful write to ensure BLE stack is ready for next packet
                Thread.sleep(forTimeInterval: 0.005) // 5ms delay (larger packets need less time between)

                packetNumber += 1

                // Update progress
                let progress = otaTotalPackets > 0 ? Int((Double(packetNumber) / Double(otaTotalPackets)) * 100) : 0
                otaProgress = progress
                otaCurrentPacket = packetNumber

                // Send progress update frequently for smooth UI updates
                let updateFrequency = packetNumber < 10 ? 1 : (packetNumber < 100 ? 5 : 10)

                if packetNumber % updateFrequency == 0 || packetNumber == otaTotalPackets {
                    sendOtaProgress(progress, inProgress: true, message: "Sending packet \(packetNumber)/\(otaTotalPackets)")
                }
            }

            // Ensure 100% progress is sent after all packets
            sendOtaProgress(100, inProgress: true, message: "All packets sent")

            logger.logInfo("[OTA] All packets sent. Waiting before sending completion signal...")
            // Add a small delay after sending all packets to ensure device is ready
            Thread.sleep(forTimeInterval: 0.5)

            logger.logInfo("[OTA] Sending completion signal...")

            // Write 0x04 to control characteristic to finish
            logger.logInfo("[OTA] Writing 0x04 to control characteristic to finish OTA")
            // For the final 0x04 command, don't wait for write completion as device might reboot immediately
            _ = writeOtaCharacteristic(peripheral: peripheral, characteristic: controlChar, data: Data([0x04]), waitForCompletion: false)

            logger.logInfo("[OTA] Completion signal (0x04) sent. Proceeding to wait for acknowledgment/disconnection.")
            logger.logInfo("[OTA] Completion signal (0x04) sent successfully")

            // Wait for device to process - increased from 500ms to 1000ms for reliability
            logger.logInfo("[OTA] Waiting for device to process completion signal...")
            Thread.sleep(forTimeInterval: 1.0)

            // Try to read final acknowledgment, but don't fail if device disconnects (it's rebooting)
            logger.logInfo("[OTA] Waiting for final acknowledgment (0x05)")
            let finalResponse = readOtaCharacteristicSync(peripheral: peripheral, characteristic: controlChar, timeoutMs: 2000)

            // Check if we got a response or if device disconnected (which is normal - device reboots)
            let deviceDisconnected = connectionState != .connected || connectedPeripheral == nil

            if let response = finalResponse, !response.isEmpty {
                logger.logInfo("[OTA] Received final response: \(response.map { String(format: "%02x", $0) }.joined())")
                if response[0] == 5 {
                    logger.logInfo("[OTA] OTA update successful! Received acknowledgment (0x05)")
                    sendOtaProgress(100, inProgress: false, message: "OTA update successful")
                } else if response[0] == 6 {
                    logger.logError("[OTA] OTA failed! Device reported error (0x06)")
                    sendOtaProgress(0, inProgress: false, message: "OTA failed - device reported error")
                    isOtaInProgress = false
                    return
                } else {
                    logger.logWarning("[OTA] Received unexpected response: \(response[0]) (expected 0x05)")
                    sendOtaProgress(100, inProgress: false, message: "OTA completed with unexpected response")
                }
            } else if deviceDisconnected {
                // Device disconnected after sending all packets - this is normal, device is rebooting to install firmware
                logger.logInfo("[OTA] OTA update completed. Device disconnected (rebooting to install firmware)")
                sendOtaProgress(100, inProgress: false, message: "OTA update completed. Device is rebooting to install firmware.")
            } else {
                let responseStr = finalResponse?.isEmpty ?? true ? "no response" : "empty response"
                logger.logWarning("[OTA] OTA update may have succeeded but no acknowledgment received. Response: \(responseStr)")
                // Still mark as success since all packets were sent
                sendOtaProgress(100, inProgress: false, message: "OTA update completed. All packets sent successfully.")
            }

        } catch {
            logger.logError("[OTA] OTA update failed: \(error.localizedDescription)")
            sendOtaProgress(0, inProgress: false, message: "OTA update failed: \(error.localizedDescription)")
        }

        isOtaInProgress = false

        // Restart regular UART timers after OTA completes (if still connected)
        if connectionState == .connected && isUartReady {
            startMeasureTimer()
            startChargeLimitTimer()
            logger.logDebug("[OTA] Restarted regular UART timers after OTA")
        }
    }

    /// Read OTA characteristic synchronously (matching Android readOtaCharacteristicSync)
    private func readOtaCharacteristicSync(peripheral: CBPeripheral, characteristic: CBCharacteristic, timeoutMs: Int) -> Data? {
        otaReadLock.wait()
        lastReadValue = nil
        otaReadLock.signal()

        do {
            peripheral.readValue(for: characteristic)
            // Wait for callback with timeout
            let timeoutDate = Date(timeIntervalSinceNow: TimeInterval(timeoutMs) / 1000.0)
            while lastReadValue == nil && Date() < timeoutDate && isOtaInProgress {
                Thread.sleep(forTimeInterval: 0.01) // 10ms sleep
            }
            return lastReadValue
        } catch {
            logger.logError("[OTA] Exception in readOtaCharacteristicSync: \(error.localizedDescription)")
            return nil
        }
    }

    /// Write OTA characteristic (matching Android writeOtaCharacteristic)
    private func writeOtaCharacteristic(peripheral: CBPeripheral, characteristic: CBCharacteristic, data: Data, waitForCompletion: Bool = true) -> Bool {
        otaWriteCompleted = false

        // Write the characteristic
        peripheral.writeValue(data, for: characteristic, type: .withResponse)

        if waitForCompletion {
            // Wait for write completion with timeout
            let timeoutResult = otaWriteLock.wait(timeout: .now() + .milliseconds(3000)) // 3 second timeout
            if timeoutResult == .timedOut {
                logger.logWarning("[OTA] Write completion timeout for characteristic: \(characteristic.uuid)")
                return false
            }
            if !otaWriteCompleted {
                logger.logWarning("[OTA] Write completed but otaWriteCompleted is false for characteristic: \(characteristic.uuid)")
                return false
            }
        }
        return true
    }

    /// Send OTA progress to Flutter (matching Android sendOtaProgress)
    private func sendOtaProgress(_ progress: Int, inProgress: Bool, message: String?) {
        DispatchQueue.main.async {
            self.onOtaProgress?(progress, inProgress, message ?? "")
        }
    }
}


