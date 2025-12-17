import Foundation
import CoreBluetooth
import UIKit

/// iOS counterpart of the Android BLE foreground service.
/// Professional implementation with robust connection management, scanning, and auto-reconnect.
final class BleManager: NSObject {
  // MARK: - Singleton
  static let shared = BleManager()
  private override init() {
    super.init()
    central = CBCentralManager(delegate: self, queue: queue, options: [
      CBCentralManagerOptionShowPowerAlertKey: true,
      CBCentralManagerOptionRestoreIdentifierKey: "nl.liionpower.app.ble.central"
    ])
  }

  // MARK: - Logging
  private lazy var logger = BackendLoggingService.shared

  // MARK: - Constants
  private let deviceFilter = "Leo Usb"
  private let commandGapMs: UInt64 = 250
  private let chargeLimitInterval: TimeInterval = 30
  
  // Connection management constants
  private let maxReconnectAttempts = 10
  private let reconnectBaseDelay: TimeInterval = 2.0
  private let reconnectBackoff: TimeInterval = 1.0
  private let reconnectMaxCooldown: TimeInterval = 30.0
  private let deviceTimeoutInterval: TimeInterval = 10.0
  private let scanCooldownAfterDisconnect: TimeInterval = 0.5
  private let connectionTimeout: TimeInterval = 10.0

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

  // MARK: - Core Bluetooth
  private let queue = DispatchQueue(label: "nl.liionpower.app.ble", qos: .userInitiated)
  private var central: CBCentralManager!
  private var peripheral: CBPeripheral?
  private var txChar: CBCharacteristic?
  private var rxChar: CBCharacteristic?
  private var otaDataChar: CBCharacteristic?
  private var otaControlChar: CBCharacteristic?
  private var fileStreamingChar: CBCharacteristic?

  // MARK: - Connection State Management
  private enum ConnectionState {
    case disconnected
    case connecting
    case connected
  }
  
  private var connectionState: ConnectionState = .disconnected {
    didSet {
      let stateInt: Int
      switch connectionState {
      case .disconnected: stateInt = 0
      case .connecting: stateInt = 1
      case .connected: stateInt = 2
      }
      // Get address directly without sync to avoid deadlock (we're already on queue thread)
      let address: String? = (connectionState == .connected) ? peripheral?.identifier.uuidString : nil
      updateConnectionState(stateInt, address: address)
    }
  }
  
  private var isUartReady = false
  private var pendingConnectAddress: String?
  private var connectionTimeoutTimer: Timer?

  // MARK: - Scanning State Management
  private struct ScannedDevice {
    let address: String
    let name: String
    var lastSeen: Date
    var rssi: Int
  }
  
  private var scannedDevices: [String: ScannedDevice] = [:]
  private var isScanning = false
  private var shouldScan = false
  private var deviceTimeoutTimer: Timer?

  // MARK: - Auto-Reconnect State Management
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

  // MARK: - Charge Limit / Battery Tracking
  private var phoneBatteryLevel: Int = -1
  private var isPhoneChargingFlag: Bool = false
  private var chargingTimeSeconds: Int = 0
  private var dischargingTimeSeconds: Int = 0
  private var timeTrackingTimer: Timer?
  private var chargeLimitTimer: Timer?

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

  // MARK: - Event callbacks (wired to Flutter EventChannels in AppDelegate)
  var onDeviceDiscovered: ((String, String) -> Void)?
  var onDeviceRemoved: ((String) -> Void)?
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
      self.shouldScan = true
      print("🔵 [BleManager] Service started. Auto-reconnect: \(self.shouldAutoReconnect)")
      logger.logServiceState("Service started. Auto-reconnect: \(self.shouldAutoReconnect)")
      
      if let savedAddr = self.lastDeviceAddress, let savedName = self.lastDeviceName {
        print("🔵 [BleManager] Saved device: \(savedName) (\(savedAddr))")
      } else {
        print("🔵 [BleManager] No saved device")
      }
      
      self.startChargeLimitTimer()
      self.startDeviceTimeoutTimer()
      UIDevice.current.isBatteryMonitoringEnabled = true
      self.sendBatteryUpdate()
      
      if self.central.state == .poweredOn {
        self.startScanning()
        if self.shouldAutoReconnect && self.connectionState == .disconnected {
          print("🔵 [BleManager] Scheduling auto-reconnect in 0.5s...")
          self.queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
      self.shouldScan = false
      self.stopScanning()
      self.disconnectDevice(userInitiated: true)
      self.stopChargeLimitTimer()
      self.stopDeviceTimeoutTimer()
      print("🔴 [BleManager] Service stopped")
      logger.logServiceState("Service stopped")
    }
  }

  func rescan() {
    queue.async { [weak self] in
      guard let self else { return }
      print("🟡 [BleManager] Rescan requested - clearing device list")
      let removedAddresses = Array(self.scannedDevices.keys)
      self.scannedDevices.removeAll()
      
      DispatchQueue.main.async { [weak self] in
        for address in removedAddresses {
          self?.onDeviceRemoved?(address)
        }
      }
      
      self.shouldScan = true
      if self.central.state == .poweredOn {
        self.restartScanning()
      } else {
        print("🔴 [BleManager] Cannot rescan: Bluetooth not powered on")
      }
    }
  }

  func isServiceRunning() -> Bool {
    queue.sync { isScanning || connectionState == .connected }
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
      let devices = scannedDevices.values.map { ["address": $0.address, "name": $0.name] }
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
    
    guard UUID(uuidString: address) != nil else {
      print("🔴 [BleManager] Invalid UUID format: \(address)")
      return false
    }
    
    queue.async { [weak self] in
      guard let self else { return }
      
      let deviceName = self.scannedDevices[address]?.name ?? "Leo Usb"
      print("🟡 [BleManager] User-initiated connection to: \(deviceName) (\(address))")
      self.logger.logConnect(address: address, name: deviceName)
      
      self.shouldAutoReconnect = true
      self.reconnectAttempts = 0
      self.cancelReconnect()
      
      // Close existing connection if any
      if let existingPeripheral = self.peripheral {
        print("🟡 [BleManager] Closing existing peripheral connection")
        self.central.cancelPeripheralConnection(existingPeripheral)
        self.queue.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          self?.connectToDevice(address: address)
        }
      } else {
        self.connectToDevice(address: address)
      }
    }
    return true
  }

  func disconnect() {
    disconnectDevice(userInitiated: true)
  }

  func isConnected() -> Bool {
    queue.sync { connectionState == .connected }
  }

  func getConnectionState() -> Int {
    queue.sync {
      switch connectionState {
      case .disconnected: return 0
      case .connecting: return 1
      case .connected: return 2
      }
    }
  }

  func getConnectedDeviceAddress() -> String? {
    queue.sync {
      if connectionState == .connected {
        return peripheral?.identifier.uuidString
      }
      return nil
    }
  }

  func sendCommand(_ command: String) -> Bool {
    queue.async { [weak self] in
      guard let self else { return }
      self.enqueueCommand(command)
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
    print("🟢 [BleManager] Charge limit updated: \(limit)%, enabled: \(enabled)")
    onChargeLimit?(chargeLimit, chargeLimitEnabled, chargeLimitConfirmed)
    if isUartReady && connectionState == .connected {
      sendChargeLimitCommand()
    }
    return true
  }

  func getChargeLimit() -> [String: Any] {
    ["limit": chargeLimit, "enabled": chargeLimitEnabled, "confirmed": chargeLimitConfirmed]
  }

  func setChargeLimitEnabled(_ enabled: Bool) -> Bool {
    chargeLimitEnabled = enabled
    print("🟢 [BleManager] Charge limit enabled: \(enabled)")
    onChargeLimit?(chargeLimit, chargeLimitEnabled, chargeLimitConfirmed)
    if isUartReady && connectionState == .connected {
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
    if isUartReady && connectionState == .connected {
      enqueueCommand("app_msg led_time_before_dim \(seconds)")
      queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
        self?.enqueueCommand("py_msg")
      }
    }
    return true
  }

  func requestLedTimeout() -> Bool {
    guard isUartReady && connectionState == .connected else { return false }
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
    guard isUartReady && connectionState == .connected else { return false }
    enqueueCommand("py_msg")
    return true
  }

  // OTA stubs
  func startOtaUpdate(filePath: String) -> Bool {
    onOtaProgress?(0, false, "OTA on iOS is not implemented yet")
    return false
  }

  func cancelOtaUpdate() {
    onOtaProgress?(0, false, "OTA cancelled")
  }

  func getOtaProgress() -> Int { 0 }
  func isOtaUpdateInProgress() -> Bool { false }

  // MARK: - Scanning Management
  private func startScanning() {
    guard central.state == .poweredOn else {
      print("🔵 [BleManager] Cannot start scan: Bluetooth not powered on")
      return
    }
    
    guard !isScanning else {
      print("🔵 [BleManager] Scan already in progress")
      return
    }
    
    isScanning = true
    print("🔵 [BleManager] Starting BLE scan for '\(deviceFilter)' devices...")
    central.scanForPeripherals(withServices: nil, options: [
      CBCentralManagerScanOptionAllowDuplicatesKey: true
    ])
  }

  private func stopScanning() {
    guard isScanning else { return }
    print("🔵 [BleManager] Stopping BLE scan")
    central.stopScan()
    isScanning = false
    print("🔵 [BleManager] Scan stopped. Found \(scannedDevices.count) device(s)")
  }

  private func restartScanning() {
    stopScanning()
    startScanning()
  }

  // MARK: - Connection Management
  private func connectToDevice(address: String) {
    // Validate UUID format
    guard let uuid = UUID(uuidString: address) else {
      print("🔴 [BleManager] Invalid UUID format: \(address)")
      return
    }
    
    // Check if already connecting/connected to this device
    if connectionState == .connected, peripheral?.identifier.uuidString == address {
      print("🟡 [BleManager] Already connected to this device")
      return
    }
    
    if connectionState == .connecting, pendingConnectAddress == address {
      print("🟡 [BleManager] Already connecting to this device")
      return
    }
    
    // Cancel any existing connection attempt
    if let existingPeripheral = peripheral, existingPeripheral.identifier.uuidString != address {
      print("🟡 [BleManager] Cancelling existing connection to different device")
      central.cancelPeripheralConnection(existingPeripheral)
      peripheral = nil
    }
    
    // Set connection state
    connectionState = .connecting
    pendingConnectAddress = address
    cancelConnectionTimeout()
    startConnectionTimeout()
    
    // Ensure scanning is active
    if !isScanning && shouldScan {
      startScanning()
    }
    
    // Try to find peripheral in cache first
    let peripherals = central.retrievePeripherals(withIdentifiers: [uuid])
    if let target = peripherals.first {
      print("🟡 [BleManager] Found device in cache, connecting...")
      peripheral = target
      peripheral?.delegate = self
      central.connect(target, options: [
        CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
        CBConnectPeripheralOptionNotifyOnConnectionKey: true
      ])
    } else {
      print("🟡 [BleManager] Device not in cache, will connect when discovered during scan")
      // Connection will happen in didDiscover when device is found
    }
  }

  private func disconnectDevice(userInitiated: Bool) {
    queue.async { [weak self] in
      guard let self else { return }
      
      cancelReconnect()
      cancelConnectionTimeout()
      stopChargeLimitTimer()
      
      if userInitiated {
        let address = self.peripheral?.identifier.uuidString ?? self.pendingConnectAddress ?? "unknown"
        let deviceName = self.peripheral?.name ?? self.scannedDevices[address]?.name ?? "Unknown"
        print("🔴 [BleManager] User-initiated disconnect from: \(deviceName) (\(address))")
        self.shouldAutoReconnect = false
        self.reconnectAttempts = 0
        self.clearSavedDevice()
        
        // Clear device list on user disconnect
        let removedAddresses = Array(self.scannedDevices.keys)
        self.scannedDevices.removeAll()
        DispatchQueue.main.async { [weak self] in
          for address in removedAddresses {
            self?.onDeviceRemoved?(address)
          }
        }
      }
      
      self.pendingConnectAddress = nil
      self.isUartReady = false
      self.txChar = nil
      self.rxChar = nil
      self.otaDataChar = nil
      self.otaControlChar = nil
      self.fileStreamingChar = nil
      
      if let p = self.peripheral {
        self.central.cancelPeripheralConnection(p)
      }
      
      self.connectionState = .disconnected
      self.peripheral = nil
      
      // Restart scanning after disconnect
      self.queue.asyncAfter(deadline: .now() + self.scanCooldownAfterDisconnect) { [weak self] in
        guard let self = self else { return }
        if self.connectionState == .disconnected && self.central.state == .poweredOn && self.shouldScan {
          self.restartScanning()
        }
      }
      
      print("🔴 [BleManager] Disconnected successfully")
    }
  }

  private func startConnectionTimeout() {
    DispatchQueue.main.async { [weak self] in
      self?.connectionTimeoutTimer?.invalidate()
      guard let self = self, let address = self.pendingConnectAddress else { return }
      
      self.connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: self.connectionTimeout, repeats: false) { [weak self] _ in
        self?.queue.async {
          guard let self = self else { return }
          // Only timeout if we're still connecting and address matches
          if self.connectionState == .connecting && self.pendingConnectAddress == address {
            print("🔴 [BleManager] Connection timeout after \(Int(self.connectionTimeout))s")
            self.connectionState = .disconnected
            
            // Cancel any pending connection
            if let peripheral = self.peripheral {
              self.central.cancelPeripheralConnection(peripheral)
              self.peripheral = nil
            }
            
            // Schedule reconnect if enabled
            if self.shouldAutoReconnect && self.central.state == .poweredOn {
              self.scheduleReconnect(address: address)
            } else {
              self.pendingConnectAddress = nil
            }
          }
        }
      }
    }
  }

  private func cancelConnectionTimeout() {
    DispatchQueue.main.async { [weak self] in
      self?.connectionTimeoutTimer?.invalidate()
      self?.connectionTimeoutTimer = nil
    }
  }

  // MARK: - Auto-Reconnect Management
  private func attemptAutoConnect() {
    guard connectionState == .disconnected else { return }
    guard central.state == .poweredOn else { return }
    guard shouldAutoReconnect else { return }
    guard let savedAddress = lastDeviceAddress else { return }
    
    let savedName = lastDeviceName ?? "Unknown"
    print("🟡 [BleManager] Attempting auto-connect to saved device: \(savedName) (\(savedAddress))")
    logger.logAutoConnect(address: savedAddress)
    
    if UUID(uuidString: savedAddress) != nil {
      connectToDevice(address: savedAddress)
    }
  }

  private func scheduleReconnect(address: String) {
    // Validate address format
    guard UUID(uuidString: address) != nil else {
      print("🔴 [BleManager] Cannot schedule reconnect: Invalid UUID format")
      return
    }
    
    // Check preconditions
    guard shouldAutoReconnect else {
      print("🟡 [BleManager] Reconnect cancelled: Auto-reconnect disabled")
      return
    }
    guard central.state == .poweredOn else {
      print("🟡 [BleManager] Reconnect cancelled: Bluetooth not powered on")
      return
    }
    guard connectionState == .disconnected else {
      print("🟡 [BleManager] Reconnect cancelled: Already connected/connecting (state: \(connectionState))")
      return
    }
    
    // Cancel any existing reconnect attempt
    cancelReconnect()
    
    // Ensure scanning is active
    if !isScanning && shouldScan {
      startScanning()
    }
    
    // Calculate delay with progressive backoff
    let delay: TimeInterval
    if reconnectAttempts >= maxReconnectAttempts {
      reconnectAttempts = 0
      delay = reconnectMaxCooldown
      print("🟡 [BleManager] Max reconnect attempts reached, waiting \(Int(delay))s before retry")
      restartScanning()
    } else {
      let baseDelay = reconnectBaseDelay + (Double(reconnectAttempts) * reconnectBackoff)
      delay = max(baseDelay, 2.0)
    }
    
    reconnectAttempts += 1
    print("🟡 [BleManager] Scheduling reconnect attempt #\(reconnectAttempts) to \(address) in \(String(format: "%.1f", delay))s")
    logger.logReconnect(attempt: reconnectAttempts, address: address)
    
    reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
      self?.queue.async {
        guard let self = self else { return }
        
        // Re-validate all conditions before attempting reconnect
        guard self.shouldAutoReconnect else {
          print("🟡 [BleManager] Reconnect cancelled: Auto-reconnect disabled during delay")
          return
        }
        guard self.connectionState == .disconnected else {
          print("🟡 [BleManager] Reconnect cancelled: Connection state changed during delay")
          return
        }
        guard self.central.state == .poweredOn else {
          print("🟡 [BleManager] Reconnect cancelled: Bluetooth turned off during delay")
          return
        }
        guard UUID(uuidString: address) != nil else {
          print("🔴 [BleManager] Reconnect cancelled: Invalid UUID")
          return
        }
        
        // Ensure scanning is active
        if !self.isScanning && self.shouldScan {
          self.startScanning()
        }
        
        // Attempt connection
        print("🟡 [BleManager] Executing reconnect attempt #\(self.reconnectAttempts)")
        self.connectToDevice(address: address)
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

  // MARK: - Device List Management
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
    let connectedAddress = peripheral?.identifier.uuidString
    
    for (address, device) in scannedDevices {
      // Don't remove connected device
      if address == connectedAddress { continue }
      
      // Remove stale devices
      if now.timeIntervalSince(device.lastSeen) > deviceTimeoutInterval {
        scannedDevices.removeValue(forKey: address)
        removedAddresses.append(address)
        print("🟡 [BleManager] Removed stale device: \(device.name) (\(address))")
      }
    }
    
    if !removedAddresses.isEmpty {
      print("🟡 [BleManager] Cleaned up \(removedAddresses.count) stale device(s). Remaining: \(scannedDevices.count)")
      DispatchQueue.main.async { [weak self] in
        for address in removedAddresses {
          self?.onDeviceRemoved?(address)
        }
      }
    }
  }

  private func addScannedDevice(peripheral: CBPeripheral, rssi: Int) {
    let address = peripheral.identifier.uuidString
    let name = peripheral.name ?? "Leo Usb"
    
    let isNew = scannedDevices[address] == nil
    scannedDevices[address] = ScannedDevice(
      address: address,
      name: name,
      lastSeen: Date(),
      rssi: rssi
    )
    
    if isNew {
      print("🟢 [BleManager] Discovered Leo device: \(name) (\(address)) RSSI: \(rssi)")
      logger.logScan("Found device: \(name) (\(address))")
      DispatchQueue.main.async { [weak self] in
        self?.onDeviceDiscovered?(address, name)
      }
    }
  }

  // MARK: - Command Queue Management
  private func enqueueCommand(_ command: String) {
    guard isUartReady, connectionState == .connected else { return }
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

  // MARK: - Charge Limit Management
  private func sendChargeLimitCommand() {
    guard isUartReady, connectionState == .connected else {
      print("🟡 [BleManager] Charge limit command skipped: UART not ready or not connected")
      return
    }
    
    let battery = getPhoneBattery()
    let level = battery["level"] as? Int ?? -1
    let isCharging = (battery["isCharging"] as? Bool) == true

    if isCharging != isPhoneChargingFlag {
      chargingTimeSeconds = 0
      dischargingTimeSeconds = 0
      print("🟡 [BleManager] Charging state changed: \(isPhoneChargingFlag) -> \(isCharging), resetting timers")
    }

    phoneBatteryLevel = level
    isPhoneChargingFlag = isCharging

    let limitValue = chargeLimitEnabled ? chargeLimit : 0
    let chargingFlag = isCharging ? 1 : 0
    let timeValue = isCharging ? chargingTimeSeconds : dischargingTimeSeconds

    let command = "app_msg limit \(limitValue) \(phoneBatteryLevel) \(chargingFlag) \(timeValue)"
    print("🟢 [BleManager] Sending charge limit command: \(command)")
    enqueueCommand(command)
  }

  private func sendBatteryUpdate() {
    let battery = getPhoneBattery()
    onBattery?(battery["level"] as? Int ?? -1, battery["isCharging"] as? Bool ?? false)
  }

  private func startChargeLimitTimer() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.chargeLimitTimer?.invalidate()
      self.chargeLimitTimer = Timer.scheduledTimer(withTimeInterval: self.chargeLimitInterval, repeats: true) { [weak self] _ in
        self?.queue.async {
          self?.sendChargeLimitCommand()
        }
      }
      self.startTimeTracking()
      print("🟢 [BleManager] Charge limit timer started (interval: \(self.chargeLimitInterval)s)")
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

  private func updateConnectionState(_ state: Int, address: String?) {
    DispatchQueue.main.async { [weak self] in
      self?.onConnectionChange?(state, address)
    }
  }

  // MARK: - Time Tracking
  private func startTimeTracking() {
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

  private func stopTimeTracking() {
    DispatchQueue.main.async { [weak self] in
      self?.timeTrackingTimer?.invalidate()
      self?.timeTrackingTimer = nil
    }
  }
}

// MARK: - CBCentralManagerDelegate
extension BleManager: CBCentralManagerDelegate {
  func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
    print("🟢 [BleManager] BLE state restoration triggered")
    logger.logServiceState("BLE state restoration triggered")
    
    if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
      print("🟢 [BleManager] Restoring \(peripherals.count) peripheral(s)")
      for peripheral in peripherals {
        let address = peripheral.identifier.uuidString
        let name = peripheral.name ?? "Leo Usb"
        
        self.peripheral = peripheral
        peripheral.delegate = self
        
        if peripheral.state == .connected {
          print("🟢 [BleManager] Restored connected peripheral: \(name) (\(address))")
          connectionState = .connected
          isUartReady = false
          saveLastDevice(address: address, name: name)
          scannedDevices[address] = ScannedDevice(address: address, name: name, lastSeen: Date(), rssi: 0)
          peripheral.discoverServices([serviceUUID, otaServiceUUID, dataTransferServiceUUID])
          startChargeLimitTimer()
        } else if peripheral.state == .connecting {
          print("🟡 [BleManager] Restored connecting peripheral: \(name) (\(address))")
          connectionState = .connecting
        }
      }
    }
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    queue.async { [weak self] in
      guard let self else { return }
      DispatchQueue.main.async { [weak self] in
        self?.onAdapterState?(self?.getAdapterState() ?? 0)
      }
      
      if central.state == .poweredOn && self.shouldScan && !self.isScanning {
        self.startScanning()
        if self.shouldAutoReconnect && self.connectionState == .disconnected {
          self.queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.attemptAutoConnect()
          }
        }
      } else if central.state != .poweredOn {
        self.stopScanning()
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
    
    queue.async { [weak self] in
      guard let self = self else { return }
      
      let address = peripheral.identifier.uuidString
      let rssiValue = RSSI.intValue
      let isNew = self.scannedDevices[address] == nil
      
      self.addScannedDevice(peripheral: peripheral, rssi: rssiValue)
      
      // Handle pending connection
      if let pendingAddress = self.pendingConnectAddress, address == pendingAddress {
        if self.connectionState == .connecting || self.connectionState == .disconnected {
          print("🟡 [BleManager] Found pending connection device, connecting...")
          self.cancelReconnect()
          self.cancelConnectionTimeout()
          peripheral.delegate = self
          self.peripheral = peripheral
          central.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnConnectionKey: true
          ])
          if self.connectionState == .disconnected {
            self.connectionState = .connecting
          }
          return
        }
      }
      
      // Auto-connect to saved device
      if self.shouldAutoReconnect && self.connectionState == .disconnected,
         let savedAddress = self.lastDeviceAddress,
         address == savedAddress {
        if isNew || self.reconnectTimer != nil {
          print("🟡 [BleManager] Auto-connecting to saved device: \(name) (\(savedAddress))")
          self.cancelReconnect()
          peripheral.delegate = self
          self.peripheral = peripheral
          central.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnConnectionKey: true
          ])
          self.connectionState = .connecting
        }
      }
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    let address = peripheral.identifier.uuidString
    let deviceName = peripheral.name ?? "Leo Usb"
    
    queue.async { [weak self] in
      guard let self = self else { return }
      
      // Verify this is the device we're trying to connect to
      guard self.pendingConnectAddress == address || self.lastDeviceAddress == address else {
        print("🟡 [BleManager] Ignoring connection to unexpected device: \(address)")
        self.central.cancelPeripheralConnection(peripheral)
        return
      }
      
      print("🟢 [BleManager] ✅ Connected to: \(deviceName) (\(address))")
      self.logger.logConnected(address: address, name: deviceName)
      
      self.connectionState = .connected
      self.pendingConnectAddress = nil
      self.reconnectAttempts = 0
      self.cancelConnectionTimeout()
      
      self.peripheral = peripheral
      peripheral.delegate = self
      
      self.saveLastDevice(address: address, name: deviceName)
      self.shouldAutoReconnect = true
      
      if self.scannedDevices[address] == nil {
        self.addScannedDevice(peripheral: peripheral, rssi: 0)
      }
      
      // Cancel any pending reconnect since we're now connected
      self.cancelReconnect()
      
      // Continue scanning to discover nearby devices
      if !self.isScanning && self.shouldScan {
        self.startScanning()
      }
      
      // Discover services to establish UART communication
      peripheral.discoverServices([self.serviceUUID, self.otaServiceUUID, self.dataTransferServiceUUID])
      print("🟢 [BleManager] Device saved for auto-reconnect. Discovering services...")
    }
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    let address = peripheral.identifier.uuidString
    let deviceName = peripheral.name ?? "Unknown"
    let errorMsg = error?.localizedDescription ?? "Unknown error"
    print("🔴 [BleManager] ❌ Failed to connect to: \(deviceName) (\(address))")
    print("🔴 [BleManager] Error: \(errorMsg)")
    
    queue.async { [weak self] in
      guard let self = self else { return }
      
      self.connectionState = .disconnected
      let previousAddress = self.pendingConnectAddress ?? address
      self.pendingConnectAddress = nil
      self.cancelConnectionTimeout()
      
      if self.shouldAutoReconnect && central.state == .poweredOn {
        print("🟡 [BleManager] Scheduling reconnect attempt...")
        self.scheduleReconnect(address: previousAddress)
      }
    }
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    let previousAddress = peripheral.identifier.uuidString
    let deviceName = peripheral.name ?? scannedDevices[previousAddress]?.name ?? "Unknown"
    let errorMsg = error?.localizedDescription ?? "No error"
    
    queue.async { [weak self] in
      guard let self = self else { return }
      
      // Check if we were actually connected (thread-safe check)
      let wasConnected = self.connectionState == .connected
      
      print("🔴 [BleManager] ⚠️ Disconnected from: \(deviceName) (\(previousAddress))")
      print("🔴 [BleManager] Was connected: \(wasConnected), Error: \(errorMsg)")
      logger.logDisconnect("Disconnected (wasConnected: \(wasConnected), error: \(errorMsg))")
      
      // Only process disconnect if this peripheral matches our current one
      guard self.peripheral?.identifier.uuidString == previousAddress || self.pendingConnectAddress == previousAddress else {
        print("🟡 [BleManager] Ignoring disconnect from different peripheral")
        return
      }
      
      self.connectionState = .disconnected
      self.isUartReady = false
      self.txChar = nil
      self.rxChar = nil
      self.otaDataChar = nil
      self.otaControlChar = nil
      self.fileStreamingChar = nil
      self.cancelConnectionTimeout()
      
      self.stopChargeLimitTimer()
      
      // Handle device removal based on error type
      if errorMsg.contains("timed out") || errorMsg.contains("timeout") {
        print("🔴 [BleManager] Device timed out, removing from scanned list")
        self.scannedDevices.removeValue(forKey: previousAddress)
        DispatchQueue.main.async { [weak self] in
          self?.onDeviceRemoved?(previousAddress)
        }
      } else {
        // Keep device in list, update last seen
        if var device = self.scannedDevices[previousAddress] {
          device.lastSeen = Date()
          self.scannedDevices[previousAddress] = device
        }
      }
      
      // Clear pending address only if it matches
      if self.pendingConnectAddress == previousAddress {
        self.pendingConnectAddress = nil
      }
      
      // Clear peripheral reference if it matches
      if self.peripheral?.identifier.uuidString == previousAddress {
        self.peripheral = nil
      }
      
      // Restart scanning after disconnect
      self.queue.asyncAfter(deadline: .now() + self.scanCooldownAfterDisconnect) { [weak self] in
        guard let self = self else { return }
        if self.connectionState == .disconnected && central.state == .poweredOn && self.shouldScan {
          self.restartScanning()
        }
      }
      
      // Schedule reconnect if enabled and conditions are met
      if self.shouldAutoReconnect && central.state == .poweredOn && self.connectionState == .disconnected {
        // Only reconnect if we were actually connected or if there was an error
        if wasConnected || error != nil {
          print("🟡 [BleManager] Scheduling auto-reconnect...")
          let cooldown: TimeInterval = wasConnected ? 2.0 : 1.0
          self.queue.asyncAfter(deadline: .now() + cooldown) { [weak self] in
            guard let self = self else { return }
            // Double-check state before scheduling reconnect
            if self.connectionState == .disconnected && self.shouldAutoReconnect {
              self.scheduleReconnect(address: previousAddress)
            }
          }
        }
      }
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
      startChargeLimitTimer()
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
