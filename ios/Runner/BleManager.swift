import Foundation
import CoreBluetooth
import UIKit

/// iOS counterpart of the Android BLE foreground service.
/// - Keeps scanning/connecting in background (using Bluetooth background mode).
/// - Exposes callbacks the Flutter channels can forward to Dart.
/// - Battery metrics/health/history are intentionally omitted per requirements.
final class BleManager: NSObject {
  // MARK: - Singleton
  static let shared = BleManager()
  private override init() {
    super.init()
    central = CBCentralManager(delegate: self, queue: queue, options: [
      CBCentralManagerOptionShowPowerAlertKey: true
    ])
  }

  // MARK: - Logging
  private lazy var logger = BackendLoggingService.shared

  // MARK: - Constants
  private let deviceFilter = "Leo Usb"
  private let commandGapMs: UInt64 = 250
  private let chargeLimitInterval: TimeInterval = 30

  // UUIDs
  private let serviceUUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
  private let txCharUUID = CBUUID(string: "6e400002-b5a3-f393-e0a9-e50e24dcca9e")
  private let rxCharUUID = CBUUID(string: "6e400003-b5a3-f393-e0a9-e50e24dcca9e")
  private let cccdUUID = CBUUID(string: "00002902-0000-1000-8000-00805f9b34fb")

  private let otaServiceUUID = CBUUID(string: "d6f1d96d-594c-4c53-b1c6-144a1dfde6d8")
  private let otaDataCharUUID = CBUUID(string: "23408888-1f40-4cd8-9b89-ca8d45f8a5b0")
  private let otaControlCharUUID = CBUUID(string: "7ad671aa-21c0-46a4-b722-270e3ae3d830")

  private let dataTransferServiceUUID = CBUUID(string: "41e2b910-d0e0-4880-8988-5d4a761b9dc7")
  private let dataTransmitCharUUID = CBUUID(string: "94d2c6e0-89b3-4133-92a5-15cced3ee729")

  // MARK: - State
  private let queue = DispatchQueue(label: "nl.liionpower.app.ble", qos: .userInitiated)
  // MARK: - Core Bluetooth
  private var central: CBCentralManager!
  private var peripheral: CBPeripheral?
  private var txChar: CBCharacteristic?
  private var rxChar: CBCharacteristic?
  private var otaDataChar: CBCharacteristic?
  private var otaControlChar: CBCharacteristic?
  private var fileStreamingChar: CBCharacteristic?

  // MARK: - Device / connection tracking
  private var scannedDevices: [String: String] = [:] // address -> name (matching Android)
  private var deviceLastSeen: [String: Date] = [:] // Track when devices were last seen
  private var connectionState: Int = 0 // 0=disc,1=connecting,2=connected
  private var isScanning = false
  private var shouldScan = false // Track if we want to scan (service started)
  private var isUartReady = false
  private var pendingConnectAddress: String? = nil // Track connection attempts (matching Android)
  private var deviceTimeoutTimer: Timer? // Timer to clean up stale devices

  // MARK: - Charge limit / battery tracking
  private var phoneBatteryLevel: Int = -1
  private var isPhoneChargingFlag: Bool = false
  private var chargingTimeSeconds: Int = 0
  private var dischargingTimeSeconds: Int = 0
  private var timeTrackingTimer: Timer?

  private var commandQueue: [String] = []
  private var commandProcessing = false

  private var chargeLimit: Int {
    get { UserDefaults.standard.integer(forKey: "charge_limit") }
    set { UserDefaults.standard.set(newValue, forKey: "charge_limit") }
  }
  private var chargeLimitEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "charge_limit_enabled") }
    set { UserDefaults.standard.set(newValue, forKey: "charge_limit_enabled") }
  }
  private var ledTimeoutSeconds: Int {
    get {
      let value = UserDefaults.standard.integer(forKey: "led_timeout_seconds")
      return value == 0 ? 300 : value
    }
    set { UserDefaults.standard.set(newValue, forKey: "led_timeout_seconds") }
  }
  private var ghostModeEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "ghost_mode_enabled") }
    set { UserDefaults.standard.set(newValue, forKey: "ghost_mode_enabled") }
  }
  private var silentModeEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "silent_mode_enabled") }
    set { UserDefaults.standard.set(newValue, forKey: "silent_mode_enabled") }
  }
  private var higherChargeLimitEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "higher_charge_limit_enabled") }
    set { UserDefaults.standard.set(newValue, forKey: "higher_charge_limit_enabled") }
  }

  private var chargeLimitTimer: Timer?
  
  // Auto-reconnect state
  private var shouldAutoReconnect: Bool {
    get { UserDefaults.standard.bool(forKey: "auto_reconnect") }
    set { UserDefaults.standard.set(newValue, forKey: "auto_reconnect") }
  }
  private var lastDeviceAddress: String? {
    get { UserDefaults.standard.string(forKey: "last_device_address") }
    set { UserDefaults.standard.set(newValue, forKey: "last_device_address") }
  }
  private var lastDeviceName: String? {
    get { UserDefaults.standard.string(forKey: "last_device_name") }
    set { UserDefaults.standard.set(newValue, forKey: "last_device_name") }
  }
  private var reconnectTimer: Timer?
  private var reconnectAttempts = 0
  private let maxReconnectAttempts = 10
  private let reconnectDelay: TimeInterval = 2.0
  private let reconnectBackoff: TimeInterval = 1.0
  private let deviceTimeoutInterval: TimeInterval = 10.0 // Remove devices not seen for 10 seconds
  private let scanCooldownAfterDisconnect: TimeInterval = 0.5 // Cooldown before restarting scan after disconnect

  // MARK: - Event callbacks (wired to Flutter EventChannels in AppDelegate)
  var onDeviceDiscovered: ((String, String) -> Void)?
  var onDeviceRemoved: ((String) -> Void)? // Callback for device removal
  var onConnectionChange: ((Int, String?) -> Void)?
  var onAdapterState: ((Int) -> Void)?
  var onDataReceived: ((String) -> Void)?
  var onBattery: ((Int, Bool) -> Void)?
  var onChargeLimit: ((Int, Bool, Bool) -> Void)?
  var onLedTimeout: ((Int) -> Void)?
  var onAdvancedModes: ((Bool, Bool, Bool) -> Void)?
  var onMeasureData: ((String, String) -> Void)?
  var onOtaProgress: ((Int, Bool, String?) -> Void)?

  // MARK: - Public API
  func startService() {
    print("🔵 [BleManager] ========== Starting BLE Service ==========")
    logger.logServiceState("Starting BLE Service")
    queue.async { [weak self] in
      guard let self else { return }
      shouldScan = true
      print("🔵 [BleManager] Service started. Auto-reconnect: \(shouldAutoReconnect)")
      logger.logServiceState("Service started. Auto-reconnect: \(shouldAutoReconnect)")
      if let savedAddr = lastDeviceAddress, let savedName = lastDeviceName {
        print("🔵 [BleManager] Saved device: \(savedName) (\(savedAddr))")
      } else {
        print("🔵 [BleManager] No saved device")
      }
      startChargeLimitTimer()
      startDeviceTimeoutTimer()
      UIDevice.current.isBatteryMonitoringEnabled = true
      sendBatteryUpdate()
      // Start scanning if Bluetooth is ready, otherwise wait for delegate callback
      if central.state == .poweredOn {
        startScanInternal()
        // Attempt auto-reconnect if enabled
        if shouldAutoReconnect && connectionState == 0 {
          print("🔵 [BleManager] Scheduling auto-reconnect in 0.5s...")
          queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.attemptAutoConnect()
          }
        }
      } else {
        print("🔵 [BleManager] Waiting for Bluetooth to become available...")
      }
    }
  }

  func stopService() {
    print("🔴 [BleManager] ========== Stopping BLE Service ==========")
    logger.logServiceState("Stopping BLE Service")
    queue.async { [weak self] in
      guard let self else { return }
      shouldScan = false
      stopScanInternal()
      disconnect()
      stopChargeLimitTimer()
      stopDeviceTimeoutTimer()
      print("🔴 [BleManager] Service stopped")
      logger.logServiceState("Service stopped")
    }
  }

  func rescan() {
    queue.async { [weak self] in
      guard let self else { return }
      print("🟡 [BleManager] Rescan requested - clearing device list")
      let removedAddresses = Array(scannedDevices.keys)
      scannedDevices.removeAll() // Clear list on rescan (matching Android)
      deviceLastSeen.removeAll() // Clear last seen times
      // Notify Flutter about all removed devices
      DispatchQueue.main.async { [weak self] in
        for address in removedAddresses {
          self?.onDeviceRemoved?(address)
        }
      }
      shouldScan = true
      if central.state == .poweredOn {
        restartScan() // Stop and restart scan (matching Android restartScan())
      } else {
        print("🔴 [BleManager] Cannot rescan: Bluetooth not powered on")
      }
    }
  }
  
  private func restartScan() {
    stopScanInternal()
    startScanInternal()
  }

  func isServiceRunning() -> Bool {
    queue.sync { isScanning || connectionState == 2 }
  }

  func isBluetoothEnabled() -> Bool {
    central.state == .poweredOn
  }

  func getAdapterState() -> Int {
    switch central.state {
    case .poweredOn: return 2
    case .poweredOff: return 0
    case .resetting, .unauthorized, .unknown: return 1
    case .unsupported: return 0
    @unknown default: return 0
    }
  }

  func getScannedDevices() -> [[String: String]] {
    queue.sync {
      let devices = scannedDevices.map { ["address": $0.key, "name": $0.value] }
      print("📋 [BleManager] Device list requested: \(devices.count) device(s)")
      devices.forEach { device in
        if let name = device["name"], let address = device["address"] {
          print("📋 [BleManager]   - \(name) (\(address))")
        }
      }
      return devices
    }
  }

  func connect(address: String) -> Bool {
    guard central.state == .poweredOn else {
      print("🔴 [BleManager] Cannot connect: Bluetooth not powered on")
      return false
    }
    
    guard let uuid = UUID(uuidString: address) else {
      print("🔴 [BleManager] Invalid UUID format: \(address)")
      return false
    }
    
    queue.async { [weak self] in
      guard let self else { return }
      
      // User-initiated connection - enable auto-reconnect (matching Android)
      let deviceName = scannedDevices[address] ?? "Leo Usb"
      print("🟡 [BleManager] User-initiated connection to: \(deviceName) (\(address))")
      logger.logConnect(address: address, name: deviceName)
      shouldAutoReconnect = true
      reconnectAttempts = 0
      cancelReconnect()
      
      // Properly close existing GATT to avoid connection errors (matching Android)
      if let existingPeripheral = peripheral {
        print("🟡 [BleManager] Closing existing peripheral connection")
        central.cancelPeripheralConnection(existingPeripheral)
        // Small delay to let Bluetooth stack reset (matching Android)
        queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.connectInternal(address: address, uuid: uuid)
        }
      } else {
        connectInternal(address: address, uuid: uuid)
      }
    }
    return true
  }
  
  private func connectInternal(address: String, uuid: UUID?) {
    guard let uuid = uuid else {
      print("🔴 [BleManager] Invalid UUID for address: \(address)")
      return
    }
    
    connectionState = 1 // STATE_CONNECTING
    pendingConnectAddress = address
    updateConnectionState(1, address: address)
    
    // Ensure scanning is active (matching Android - always tries to connect)
    if !isScanning && shouldScan {
      startScanInternal()
    }
    
    // Try to find peripheral in cache first
    let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
    if let target = peripherals.first {
      print("🟡 [BleManager] Found device in cache, connecting...")
      peripheral = target
      peripheral?.delegate = self
      central.connect(target, options: [
        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
      ])
    } else {
      // Device not in cache - will connect when discovered during scan (matching Android)
      print("🟡 [BleManager] Device not in cache, scanning for device...")
      // Connection will happen in didDiscover when device is found
      // pendingConnectAddress is already set above
    }
  }

  func disconnect() {
    disconnectDevice(userInitiated: true)
  }
  
  private func disconnectDevice(userInitiated: Bool) {
    queue.async { [weak self] in
      guard let self else { return }
      
      cancelReconnect()
      stopChargeLimitTimer()
      
      if userInitiated {
        let address = peripheral?.identifier.uuidString ?? pendingConnectAddress ?? "unknown"
        let deviceName = peripheral?.name ?? scannedDevices[address] ?? "Unknown"
        print("🔴 [BleManager] User-initiated disconnect from: \(deviceName) (\(address))")
        shouldAutoReconnect = false
        reconnectAttempts = 0
        clearSavedDevice()
        print("🔴 [BleManager] Auto-reconnect disabled, saved device cleared")
        
        // Clear stale devices and restart scan immediately to show actual nearby devices
        // This ensures the scan list shows real devices in range
        let removedAddresses = Array(scannedDevices.keys)
        scannedDevices.removeAll()
        deviceLastSeen.removeAll()
        // Notify Flutter about all removed devices
        DispatchQueue.main.async { [weak self] in
          for address in removedAddresses {
            self?.onDeviceRemoved?(address)
          }
        }
      }
      
      pendingConnectAddress = nil
      isUartReady = false
      txChar = nil
      rxChar = nil
      otaDataChar = nil
      otaControlChar = nil
      fileStreamingChar = nil
      
      if let p = peripheral {
        central.cancelPeripheralConnection(p)
      }
      
      updateConnectionState(0, address: nil)
      peripheral = nil
      
      // Restart scanning when disconnected to show actual nearby devices
      // Cooldown period to let BLE stack reset after disconnect
      queue.asyncAfter(deadline: .now() + scanCooldownAfterDisconnect) { [weak self] in
        guard let self = self else { return }
        if self.connectionState == 0 && central.state == .poweredOn && self.shouldScan {
          self.restartScan()
          print("🟢 [BleManager] Scan restarted after disconnect to refresh device list")
        }
      }
      
      print("🔴 [BleManager] Disconnected successfully")
    }
  }

  func isConnected() -> Bool {
    queue.sync { connectionState == 2 }
  }

  func getConnectionState() -> Int {
    queue.sync { connectionState }
  }

  func getConnectedDeviceAddress() -> String? {
    queue.sync {
      if connectionState == 2 {
        return peripheral?.identifier.uuidString
      }
      return nil
    }
  }

  func sendCommand(_ command: String) -> Bool {
    queue.async { [weak self] in
      guard let self else { return }
      enqueueCommand(command)
    }
    return true
  }

  func getPhoneBattery() -> [String: Any] {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let level = Int(UIDevice.current.batteryLevel * 100)
    let charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
    return ["level": level < 0 ? -1 : level, "isCharging": charging]
  }

  func setChargeLimit(limit: Int, enabled: Bool) -> Bool {
    guard limit >= 0, limit <= 100 else { return false }
    chargeLimit = limit
    chargeLimitEnabled = enabled
    onChargeLimit?(chargeLimit, chargeLimitEnabled, chargeLimitConfirmed)
    if isUartReady && connectionState == 2 {
      sendChargeLimitCommand()
    }
    return true
  }

  func getChargeLimit() -> [String: Any] {
    ["limit": chargeLimit, "enabled": chargeLimitEnabled, "confirmed": chargeLimitConfirmed]
  }

  func setChargeLimitEnabled(_ enabled: Bool) -> Bool {
    chargeLimitEnabled = enabled
    onChargeLimit?(chargeLimit, chargeLimitEnabled, chargeLimitConfirmed)
    if isUartReady && connectionState == 2 {
      sendChargeLimitCommand()
    }
    return true
  }

  func getLedTimeout() -> Int {
    ledTimeoutSeconds
  }

  func setLedTimeout(seconds: Int) -> Bool {
    guard seconds >= 0 else { return false }
    ledTimeoutSeconds = seconds
    onLedTimeout?(seconds)
    if isUartReady && connectionState == 2 {
      enqueueCommand("app_msg led_time_before_dim \(seconds)")
      queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
        self?.enqueueCommand("py_msg")
      }
    }
    return true
  }

  func requestLedTimeout() -> Bool {
    guard isUartReady && connectionState == 2 else { return false }
    enqueueCommand("app_msg led_time_before_dim")
    queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
      self?.enqueueCommand("py_msg")
    }
    return true
  }

  func getAdvancedModes() -> [String: Bool] {
    [
      "ghostMode": ghostModeEnabled,
      "silentMode": silentModeEnabled,
      "higherChargeLimit": higherChargeLimitEnabled
    ]
  }

  func setGhostMode(_ enabled: Bool) -> Bool {
    ghostModeEnabled = enabled
    enqueueCommand("app_msg ghost_mode \(enabled ? 1 : 0)")
    queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
      self?.enqueueCommand("py_msg")
    }
    updateAdvancedModes()
    return true
  }

  func setSilentMode(_ enabled: Bool) -> Bool {
    silentModeEnabled = enabled
    enqueueCommand("app_msg quiet_mode \(enabled ? 1 : 0)")
    queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
      self?.enqueueCommand("py_msg")
    }
    updateAdvancedModes()
    return true
  }

  func setHigherChargeLimit(_ enabled: Bool) -> Bool {
    higherChargeLimitEnabled = enabled
    enqueueCommand("app_msg charge_limit \(enabled ? 1 : 0)")
    queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
      self?.enqueueCommand("py_msg")
    }
    updateAdvancedModes()
    return true
  }

  func requestAdvancedModes() -> Bool {
    guard isUartReady && connectionState == 2 else { return false }
    enqueueCommand("py_msg")
    return true
  }

  // OTA stubs (full parity can be added later)
  func startOtaUpdate(filePath: String) -> Bool {
    onOtaProgress?(0, false, "OTA on iOS is not implemented yet")
    return false
  }

  func cancelOtaUpdate() {
    onOtaProgress?(0, false, "OTA cancelled")
  }

  func getOtaProgress() -> Int { 0 }
  func isOtaUpdateInProgress() -> Bool { false }

  // MARK: - Private helpers
  private func startScanInternal() {
    guard central.state == .poweredOn else {
      print("🔵 [BleManager] Cannot start scan: Bluetooth not powered on (state: \(central.state.rawValue))")
      return
    }
    if isScanning {
      print("🔵 [BleManager] Scan already in progress")
      return
    }
    
    isScanning = true
    print("🔵 [BleManager] Starting BLE scan for '\(deviceFilter)' devices...")
    // Use efficient scan options to prevent OS from killing the app
    // Allow duplicates to keep device list active, but iOS will throttle automatically
    central.scanForPeripherals(withServices: nil, options: [
      CBCentralManagerScanOptionAllowDuplicatesKey: true // Allow duplicates to keep list active
    ])
  }

  private func stopScanInternal() {
    guard isScanning else { return }
    print("🔵 [BleManager] Stopping BLE scan")
    central.stopScan()
    isScanning = false
    print("🔵 [BleManager] Scan stopped. Found \(scannedDevices.count) device(s)")
  }

  private func updateConnectionState(_ state: Int, address: String?) {
    connectionState = state
    DispatchQueue.main.async { [weak self] in
      self?.onConnectionChange?(state, address)
    }
  }

  private func enqueueCommand(_ command: String) {
    guard isUartReady, connectionState == 2 else { return }
    commandQueue.append(command)
    processCommandQueue()
  }

  private func processCommandQueue() {
    guard !commandProcessing, !commandQueue.isEmpty else { return }
    commandProcessing = true
    let command = commandQueue.removeFirst()
    writeCommand(command)
    queue.asyncAfter(deadline: .now() + .milliseconds(Int(commandGapMs))) { [weak self] in
      guard let self else { return }
      self.commandProcessing = false
      self.processCommandQueue()
    }
  }

  private func writeCommand(_ command: String) {
    guard let p = peripheral,
          let tx = txChar,
          tx.properties.contains(.write) || tx.properties.contains(.writeWithoutResponse)
    else { return }
    let data = (command + "\n").data(using: .utf8) ?? Data()
    let type: CBCharacteristicWriteType = tx.properties.contains(.write) ? .withResponse : .withoutResponse
    p.writeValue(data, for: tx, type: type)
    logger.logCommand(command)
  }

  private func sendChargeLimitCommand() {
    // Mirror Android behaviour:
    // app_msg limit <limitValue> <phoneBatteryLevel> <chargingFlag> <timeValue>

    // Refresh phone battery info
    let battery = getPhoneBattery()
    let level = battery["level"] as? Int ?? -1
    let isCharging = (battery["isCharging"] as? Bool) == true

    // Detect charging state change and reset timers like Android
    if isCharging != isPhoneChargingFlag {
      chargingTimeSeconds = 0
      dischargingTimeSeconds = 0
    }

    phoneBatteryLevel = level
    isPhoneChargingFlag = isCharging

    let limitValue = chargeLimitEnabled ? chargeLimit : 0
    let chargingFlag = isCharging ? 1 : 0
    let timeValue = isCharging ? chargingTimeSeconds : dischargingTimeSeconds

    let command = "app_msg limit \(limitValue) \(phoneBatteryLevel) \(chargingFlag) \(timeValue)"
    enqueueCommand(command)
  }

  private func sendBatteryUpdate() {
    let battery = getPhoneBattery()
    onBattery?(battery["level"] as? Int ?? -1, battery["isCharging"] as? Bool ?? false)
  }

  private func startChargeLimitTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.chargeLimitTimer?.invalidate()
      self?.chargeLimitTimer = Timer.scheduledTimer(withTimeInterval: self?.chargeLimitInterval ?? 30, repeats: true) { _ in
        self?.queue.async {
          self?.sendChargeLimitCommand()
        }
      }
      // Start 1-second tracking of charging / discharging durations (matching Android)
      self?.startTimeTracking()
    }
  }

  private func stopChargeLimitTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.chargeLimitTimer?.invalidate()
      self?.chargeLimitTimer = nil
      self?.stopTimeTracking()
    }
  }

  private func updateAdvancedModes() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      onAdvancedModes?(ghostModeEnabled, silentModeEnabled, higherChargeLimitEnabled)
    }
  }
  
  // MARK: - Auto-reconnect helpers
  private func attemptAutoConnect() {
    guard connectionState == 0 else {
      print("🟡 [BleManager] Auto-connect skipped: Already connected (state: \(connectionState))")
      return
    }
    guard central.state == .poweredOn else {
      print("🟡 [BleManager] Auto-connect skipped: Bluetooth not powered on")
      return
    }
    guard shouldAutoReconnect else {
      print("🟡 [BleManager] Auto-connect skipped: Auto-reconnect disabled")
      return
    }
    guard let savedAddress = lastDeviceAddress else {
      print("🟡 [BleManager] Auto-connect skipped: No saved device address")
      return
    }
    
    let savedName = lastDeviceName ?? "Unknown"
    print("🟡 [BleManager] Attempting auto-connect to saved device: \(savedName) (\(savedAddress))")
    logger.logAutoConnect(address: savedAddress)
    
    // Android attempts connect even if device not in scannedDevices
    // Always try to connect (matching Android connectToDevice behavior)
    print("🟡 [BleManager] Attempting auto-connect to saved device: \(savedAddress)")
    
    // Use connectInternal which handles all cases
    if let uuid = UUID(uuidString: savedAddress) {
      connectInternal(address: savedAddress, uuid: uuid)
    } else {
      print("🔴 [BleManager] Invalid UUID format for saved address: \(savedAddress)")
    }
  }
  
  private func scheduleReconnect(address: String) {
    guard shouldAutoReconnect else {
      print("🟡 [BleManager] Reconnect cancelled: Auto-reconnect disabled")
      return
    }
    guard central.state == .poweredOn else {
      print("🟡 [BleManager] Reconnect cancelled: Bluetooth not powered on")
      return
    }
    
    cancelReconnect()
    
    // Ensure scanning is active during reconnect attempts (matching Android)
    if !isScanning && shouldScan {
      startScanInternal()
    }
    
    // After max attempts, add longer cooldown to let BLE stack cool down properly
    let delay: TimeInterval
    if reconnectAttempts >= maxReconnectAttempts {
      reconnectAttempts = 0
      delay = 30.0 // 30 second cooldown to prevent BLE stack overload
      print("🟡 [BleManager] Max reconnect attempts reached, waiting 30s before retry (BLE stack cooldown)")
      // Restart scan to refresh device cache (matching Android)
      restartScan()
    } else {
      // Progressive backoff with proper cooldown to prevent BLE stack overload
      // Minimum 2 seconds between attempts to properly cool down BLE stack
      let baseDelay = reconnectDelay + (Double(reconnectAttempts) * reconnectBackoff)
      delay = max(baseDelay, 2.0) // Increased minimum cooldown for better BLE stack stability
    }
    
    reconnectAttempts += 1
    print("🟡 [BleManager] Scheduling reconnect attempt #\(reconnectAttempts) to \(address) in \(String(format: "%.1f", delay))s")
    logger.logReconnect(attempt: reconnectAttempts, address: address)
    
    reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
      self?.queue.async {
        guard let self = self else { return }
        if self.shouldAutoReconnect && self.connectionState == 0 && self.central.state == .poweredOn {
          // Ensure scan is still active before attempting connection
          if !self.isScanning && self.shouldScan {
            self.startScanInternal()
          }
          // Try to connect (matching Android - always attempts connectToDevice)
          if let uuid = UUID(uuidString: address) {
            self.connectInternal(address: address, uuid: uuid)
          }
        }
      }
    }
  }
  
  private func cancelReconnect() {
    reconnectTimer?.invalidate()
    reconnectTimer = nil
  }
  
  private func saveLastDevice(address: String, name: String) {
    lastDeviceAddress = address
    lastDeviceName = name
  }
  
  private func clearSavedDevice() {
    lastDeviceAddress = nil
    lastDeviceName = nil
  }
  
  // MARK: - Device timeout management
  private func startDeviceTimeoutTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.deviceTimeoutTimer?.invalidate()
      self?.deviceTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
        self?.queue.async {
          self?.cleanupStaleDevices()
        }
      }
    }
  }
  
  private func stopDeviceTimeoutTimer() {
    DispatchQueue.main.async { [weak self] in
      self?.deviceTimeoutTimer?.invalidate()
      self?.deviceTimeoutTimer = nil
    }
  }
  
  private func cleanupStaleDevices() {
    let now = Date()
    var removedAddresses: [String] = []
    
    // Only clean up devices when not connected to avoid removing the connected device
    if connectionState != 2 {
      for (address, lastSeen) in deviceLastSeen {
        if now.timeIntervalSince(lastSeen) > deviceTimeoutInterval {
          scannedDevices.removeValue(forKey: address)
          deviceLastSeen.removeValue(forKey: address)
          removedAddresses.append(address)
          print("🟡 [BleManager] Removed stale device: \(address) (not seen for \(Int(now.timeIntervalSince(lastSeen)))s)")
        }
      }
    } else {
      // When connected, only remove devices that aren't the connected device
      let connectedAddress = peripheral?.identifier.uuidString
      for (address, lastSeen) in deviceLastSeen {
        if address != connectedAddress && now.timeIntervalSince(lastSeen) > deviceTimeoutInterval {
          scannedDevices.removeValue(forKey: address)
          deviceLastSeen.removeValue(forKey: address)
          removedAddresses.append(address)
          print("🟡 [BleManager] Removed stale device: \(address) (not seen for \(Int(now.timeIntervalSince(lastSeen)))s)")
        }
      }
    }
    
    // Notify Flutter about removed devices
    if !removedAddresses.isEmpty {
      print("🟡 [BleManager] Cleaned up \(removedAddresses.count) stale device(s). Remaining: \(scannedDevices.count)")
      DispatchQueue.main.async { [weak self] in
        for address in removedAddresses {
          self?.onDeviceRemoved?(address)
        }
      }
    }
  }
}

// MARK: - Time tracking helpers (charging / discharging seconds)
private extension BleManager {
  func startTimeTracking() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.timeTrackingTimer?.invalidate()
      self.timeTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        guard let self else { return }
        self.queue.async { [weak self] in
          guard let self else { return }
          if self.isPhoneChargingFlag {
            self.chargingTimeSeconds += 1
          } else {
            self.dischargingTimeSeconds += 1
          }
        }
      }
    }
  }

  func stopTimeTracking() {
    DispatchQueue.main.async { [weak self] in
      self?.timeTrackingTimer?.invalidate()
      self?.timeTrackingTimer = nil
    }
  }
}

// MARK: - CBCentralManagerDelegate
extension BleManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    queue.async { [weak self] in
      guard let self else { return }
      DispatchQueue.main.async { [weak self] in
        self?.onAdapterState?(self?.getAdapterState() ?? 0)
      }
      // Start scanning when Bluetooth becomes available and we want to scan
      if central.state == .poweredOn && shouldScan && !isScanning {
        startScanInternal()
      } else if central.state != .poweredOn {
        // Stop scanning if Bluetooth turns off
        stopScanInternal()
      }
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let name = peripheral.name ?? ""
    guard name.localizedCaseInsensitiveContains(deviceFilter) else { return }
    
    let address = peripheral.identifier.uuidString
    let isNew = !scannedDevices.keys.contains(address)
    scannedDevices[address] = name
    deviceLastSeen[address] = Date() // Update last seen time
    
    print("🟢 [BleManager] Discovered Leo device: \(name) (\(address)) RSSI: \(RSSI)")
    print("🟢 [BleManager] Total devices in list: \(scannedDevices.count)")
    logger.logScan("Found device: \(name) (\(address))")
    
    DispatchQueue.main.async { [weak self] in
      self?.onDeviceDiscovered?(address, name)
    }
    
    queue.async { [weak self] in
      guard let self = self else { return }
      
      // Handle pending connection (user-initiated or reconnect attempt)
      if let pendingAddress = pendingConnectAddress, address == pendingAddress {
        if connectionState == 1 || connectionState == 0 {
          print("🟡 [BleManager] Found pending connection device during reconnect, connecting...")
          cancelReconnect() // Cancel scheduled reconnect since we found the device
          peripheral.delegate = self
          self.peripheral = peripheral
          central.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
          ])
          if connectionState == 0 {
            updateConnectionState(1, address: address)
          }
          return
        }
      }
      
      // Auto-connect to saved device if found during scan (matching Android)
      // Android checks: isNew && shouldAutoReconnect && connectionState == STATE_DISCONNECTED
      // Also check if device matches saved address (even if not new, if it was removed and came back)
      if shouldAutoReconnect && connectionState == 0,
         let savedAddress = lastDeviceAddress,
         address == savedAddress {
        // Only auto-connect if it's a new discovery OR if reconnect is scheduled
        if isNew || reconnectTimer != nil {
          print("🟡 [BleManager] Auto-connecting to saved device: \(name) (\(savedAddress))")
          cancelReconnect() // Cancel scheduled reconnect since we found the device
          peripheral.delegate = self
          self.peripheral = peripheral
          central.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
          ])
          updateConnectionState(1, address: savedAddress)
        }
      }
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    let address = peripheral.identifier.uuidString
    let deviceName = peripheral.name ?? "Leo Usb"
    print("🟢 [BleManager] ✅ Connected to: \(deviceName) (\(address))")
    logger.logConnected(address: address, name: deviceName)
    
    connectionState = 2 // STATE_CONNECTED
    pendingConnectAddress = nil
    reconnectAttempts = 0
    
    self.peripheral = peripheral
    peripheral.delegate = self
    
    // Save device for auto-reconnect (matching Android)
    saveLastDevice(address: address, name: deviceName)
    shouldAutoReconnect = true
    
    // Ensure device is in scannedDevices (matching Android)
    scannedDevices[address] = deviceName
    
    cancelReconnect()
    
    // Keep scanning active when connected to discover nearby devices
    // This ensures scan list stays active and shows other devices in range
    if !isScanning && shouldScan {
      startScanInternal()
      print("🟢 [BleManager] Scan continues while connected to show nearby devices")
    }
    
    updateConnectionState(2, address: address)
    
    // Request MTU and discover services (matching Android)
    peripheral.discoverServices([serviceUUID, otaServiceUUID, dataTransferServiceUUID])
    print("🟢 [BleManager] Device saved for auto-reconnect. Discovering services...")
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    let address = peripheral.identifier.uuidString
    let deviceName = peripheral.name ?? "Unknown"
    let errorMsg = error?.localizedDescription ?? "Unknown error"
    print("🔴 [BleManager] ❌ Failed to connect to: \(deviceName) (\(address))")
    print("🔴 [BleManager] Error: \(errorMsg)")
    
    connectionState = 0 // STATE_DISCONNECTED
    let previousAddress = pendingConnectAddress ?? address
    pendingConnectAddress = nil
    
    updateConnectionState(0, address: nil)
    
    // Schedule reconnect if auto-reconnect is enabled (matching Android)
    if shouldAutoReconnect && central.state == .poweredOn {
      print("🟡 [BleManager] Scheduling reconnect attempt...")
      scheduleReconnect(address: previousAddress)
    }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    let wasConnected = connectionState == 2
    let previousAddress = peripheral.identifier.uuidString
    let deviceName = peripheral.name ?? scannedDevices[previousAddress] ?? "Unknown"
    let errorMsg = error?.localizedDescription ?? "No error"
    
    print("🔴 [BleManager] ⚠️ Disconnected from: \(deviceName) (\(previousAddress))")
    print("🔴 [BleManager] Was connected: \(wasConnected), Error: \(errorMsg)")
    print("🔴 [BleManager] Auto-reconnect enabled: \(shouldAutoReconnect)")
    logger.logDisconnect("Disconnected (wasConnected: \(wasConnected), error: \(errorMsg))")
    
    connectionState = 0 // STATE_DISCONNECTED
    isUartReady = false
    txChar = nil
    rxChar = nil
    otaDataChar = nil
    otaControlChar = nil
    fileStreamingChar = nil
    
    stopChargeLimitTimer()
    
    // Remove device from scanned list if it timed out (device is off)
    // This matches Android behavior where devices disappear when offline
    if errorMsg.contains("timed out") || errorMsg.contains("timeout") {
      print("🔴 [BleManager] Device timed out, removing from scanned list")
      scannedDevices.removeValue(forKey: previousAddress)
      deviceLastSeen.removeValue(forKey: previousAddress)
      // Notify Flutter about device removal
      DispatchQueue.main.async { [weak self] in
        self?.onDeviceRemoved?(previousAddress)
      }
    } else {
      // Keep device in list for other disconnect reasons (matching Android)
      scannedDevices[previousAddress] = deviceName
      deviceLastSeen[previousAddress] = Date() // Update last seen time
    }
    
    pendingConnectAddress = nil
    
    updateConnectionState(0, address: nil)
    
    // Restart scanning immediately when disconnected to refresh device list
    // Cooldown period to let BLE stack cool down properly before restarting scan
    queue.asyncAfter(deadline: .now() + scanCooldownAfterDisconnect) { [weak self] in
      guard let self = self else { return }
      if self.connectionState == 0 && central.state == .poweredOn && self.shouldScan {
        self.restartScan()
        print("🟢 [BleManager] Scan restarted after disconnect to refresh device list")
      }
    }
    
    // Only auto-reconnect if enabled and not user-initiated disconnect (matching Android)
    // For non-manual disconnects, use proper cooldown to let BLE stack reset
    if shouldAutoReconnect && central.state == .poweredOn && previousAddress != nil {
      // Android checks: status != GATT_SUCCESS || wasConnected
      // On iOS, we reconnect if wasConnected or if there's an error
      if wasConnected || error != nil {
        print("🟡 [BleManager] Scheduling auto-reconnect...")
        // Longer cooldown for non-manual disconnects to properly cool down BLE stack
        let cooldown: TimeInterval = wasConnected ? 2.0 : 1.0
        queue.asyncAfter(deadline: .now() + cooldown) { [weak self] in
          self?.scheduleReconnect(address: previousAddress)
        }
      }
    } else {
      print("🔴 [BleManager] Auto-reconnect disabled or Bluetooth off - not reconnecting")
    }
  }
}

// MARK: - CBPeripheralDelegate
extension BleManager: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard error == nil else { return }
    peripheral.services?.forEach { service in
      if service.uuid == serviceUUID || service.uuid == otaServiceUUID || service.uuid == dataTransferServiceUUID {
        peripheral.discoverCharacteristics(nil, for: service)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard error == nil else { return }
    service.characteristics?.forEach { characteristic in
      switch characteristic.uuid {
      case txCharUUID: txChar = characteristic
      case rxCharUUID:
        rxChar = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
      case otaDataCharUUID: otaDataChar = characteristic
      case otaControlCharUUID: otaControlChar = characteristic
      case dataTransmitCharUUID:
        fileStreamingChar = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
      default: break
      }
    }

    if txChar != nil, rxChar != nil {
      isUartReady = true
      // Start timers/initial commands
      sendChargeLimitCommand()
      requestLedTimeout()
      requestAdvancedModes()
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        onLedTimeout?(ledTimeoutSeconds)
        updateAdvancedModes()
        onChargeLimit?(chargeLimit, chargeLimitEnabled, chargeLimitConfirmed)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard error == nil, let data = characteristic.value else { return }
    if characteristic.uuid == rxCharUUID {
      let received = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      handleReceivedData(received)
      logger.logCommandResponse(received)
      DispatchQueue.main.async { [weak self] in
        self?.onDataReceived?(received)
      }
    } else if characteristic.uuid == dataTransmitCharUUID {
      // File streaming not exposed to Flutter right now.
    }
  }
}

// MARK: - Response parsing
private extension BleManager {
  var chargeLimitConfirmed: Bool {
    get { UserDefaults.standard.bool(forKey: "charge_limit_confirmed") }
    set { UserDefaults.standard.set(newValue, forKey: "charge_limit_confirmed") }
  }

  func handleReceivedData(_ data: String) {
    let parts = data.split(separator: " ").map(String.init)
    guard parts.count >= 2 else { return }

    if parts.count >= 4 && parts[2] == "charge_limit" {
      if let numeric = Int(parts[3].filter(\.isNumber)) {
        chargeLimitConfirmed = numeric == 1
        onChargeLimit?(chargeLimit, chargeLimitEnabled, chargeLimitConfirmed)
        handleAdvancedModeResponse(mode: "charge_limit", value: numeric)
      }
    }

    if parts.count >= 4 && parts[2] == "ghost_mode" {
      if let numeric = Int(parts[3].filter(\.isNumber)) {
        handleAdvancedModeResponse(mode: "ghost_mode", value: numeric)
      }
    }

    if parts.count >= 4 && parts[2] == "quiet_mode" {
      if let numeric = Int(parts[3].filter(\.isNumber)) {
        handleAdvancedModeResponse(mode: "quiet_mode", value: numeric)
      }
    }

    if parts.count >= 4 && parts[2] == "led_time_before_dim" {
      if let parsed = Int(parts[3].filter(\.isNumber)) {
        ledTimeoutSeconds = parsed
        onLedTimeout?(parsed)
      }
    }

    if parts.count >= 4 && parts[1] == "measure" {
      if let voltage = Double(parts[2]), let current = Double(parts[3]) {
        let voltageStr = String(format: "%.3f", voltage)
        let currentStr = String(format: "%.3f", abs(current))
        DispatchQueue.main.async { [weak self] in
          self?.onMeasureData?(voltageStr, currentStr)
        }
      }
    }
  }

  func handleAdvancedModeResponse(mode: String, value: Int) {
    switch mode {
    case "ghost_mode":
      ghostModeEnabled = value == 1
    case "quiet_mode":
      silentModeEnabled = value == 1
    case "charge_limit":
      higherChargeLimitEnabled = value == 1
    default:
      break
    }
    updateAdvancedModes()
  }
}

