import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private enum ChannelNames {
    static let method = "com.liion_app/ble_service"
    static let devices = "com.liion_app/ble_devices"
    static let connection = "com.liion_app/ble_connection"
    static let adapter = "com.liion_app/adapter_state"
    static let dataReceived = "com.liion_app/data_received"
    static let battery = "com.liion_app/phone_battery"
    static let chargeLimit = "com.liion_app/charge_limit"
    static let ledTimeout = "com.liion_app/led_timeout"
    static let advancedModes = "com.liion_app/advanced_modes"
    static let batteryHealth = "com.liion_app/battery_health"
    static let measureData = "com.liion_app/measure_data"
    static let batteryMetrics = "com.liion_app/battery_metrics" // intentionally silent on iOS
    static let otaProgress = "com.liion_app/ota_progress"
  }

  private var deviceSink: FlutterEventSink?
  private var connectionSink: FlutterEventSink?
  private var adapterSink: FlutterEventSink?
  private var dataSink: FlutterEventSink?
  private var batterySink: FlutterEventSink?
  private var chargeLimitSink: FlutterEventSink?
  private var ledTimeoutSink: FlutterEventSink?
  private var advancedModesSink: FlutterEventSink?
  private var batteryHealthSink: FlutterEventSink?
  private var measureDataSink: FlutterEventSink?
  private var batteryMetricsSink: FlutterEventSink?
  private var otaProgressSink: FlutterEventSink?

  private let bleManager = BleManager.shared

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let messenger = controller.binaryMessenger

    setupMethodChannel(messenger: messenger)
    setupEventChannels(messenger: messenger)
    wireManagerCallbacks()

    // Initialize backend logging service
    initializeBackendLogging()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Channels
  private func setupMethodChannel(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: ChannelNames.method, binaryMessenger: messenger)
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "APP_DEALLOCATED", message: nil, details: nil))
        return
      }

      switch call.method {
      case "startService":
        bleManager.startService()
        result(true)
      case "stopService":
        bleManager.stopService()
        result(true)
      case "rescan":
        bleManager.rescan()
        result(true)
      case "getScannedDevices":
        result(bleManager.getScannedDevices())
      case "isServiceRunning":
        result(bleManager.isServiceRunning())
      case "isBluetoothEnabled":
        result(bleManager.isBluetoothEnabled())
      case "getAdapterState":
        result(bleManager.getAdapterState())
      case "requestEnableBluetooth":
        // iOS cannot prompt programmatically; return current state.
        result(bleManager.isBluetoothEnabled())
      case "connect":
        let address = call.argumentsAsDict()["address"] as? String
        result(address.flatMap { self.bleManager.connect(address: $0) } ?? false)
      case "disconnect":
        bleManager.disconnect()
        result(true)
      case "isConnected":
        result(bleManager.isConnected())
      case "getConnectionState":
        result(bleManager.getConnectionState())
      case "getConnectedDeviceAddress":
        result(bleManager.getConnectedDeviceAddress())
      case "sendCommand":
        let command = call.argumentsAsDict()["command"] as? String
        result(command.flatMap { self.bleManager.sendCommand($0) } ?? false)
      case "getPhoneBattery":
        result(bleManager.getPhoneBattery())
      case "setChargeLimit":
        let args = call.argumentsAsDict()
        let limit = args["limit"] as? Int ?? 90
        let enabled = args["enabled"] as? Bool ?? false
        result(bleManager.setChargeLimit(limit: limit, enabled: enabled))
      case "getChargeLimit":
        result(bleManager.getChargeLimit())
      case "setChargeLimitEnabled":
        let enabled = call.argumentsAsDict()["enabled"] as? Bool ?? false
        result(bleManager.setChargeLimitEnabled(enabled))
      case "isBatteryOptimizationDisabled":
        result(true) // iOS does not expose this optimization toggle
      case "requestDisableBatteryOptimization":
        result(true)
      case "getBatteryHealthInfo",
           "startBatteryHealthCalculation",
           "stopBatteryHealthCalculation",
           "resetBatteryHealthReadings",
           "getBatterySessionHistory",
           "clearBatterySessionHistory":
        // Battery health/history intentionally not implemented on iOS.
        result(nil)
      case "startOtaUpdate":
        let filePath = call.argumentsAsDict()["filePath"] as? String ?? ""
        result(bleManager.startOtaUpdate(filePath: filePath))
      case "cancelOtaUpdate":
        bleManager.cancelOtaUpdate()
        result(true)
      case "getOtaProgress":
        result(bleManager.getOtaProgress())
      case "isOtaUpdateInProgress":
        result(bleManager.isOtaUpdateInProgress())
      case "getLedTimeout":
        result(bleManager.getLedTimeout())
      case "requestLedTimeout":
        result(bleManager.requestLedTimeout())
      case "setLedTimeout":
        let seconds = call.argumentsAsDict()["seconds"] as? Int ?? 0
        result(bleManager.setLedTimeout(seconds: seconds))
      case "getAdvancedModes":
        result(bleManager.getAdvancedModes())
      case "setGhostMode":
        let enabled = call.argumentsAsDict()["enabled"] as? Bool ?? false
        result(bleManager.setGhostMode(enabled))
      case "setSilentMode":
        let enabled = call.argumentsAsDict()["enabled"] as? Bool ?? false
        result(bleManager.setSilentMode(enabled))
      case "setHigherChargeLimit":
        let enabled = call.argumentsAsDict()["enabled"] as? Bool ?? false
        result(bleManager.setHigherChargeLimit(enabled))
      case "requestAdvancedModes":
        result(bleManager.requestAdvancedModes())
      case "minimizeApp":
        // Not applicable on iOS, just succeed.
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func setupEventChannels(messenger: FlutterBinaryMessenger) {
    FlutterEventChannel(name: ChannelNames.devices, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in self?.deviceSink = sink },
        onCancel: { [weak self] in self?.deviceSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.connection, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in
          self?.connectionSink = sink
          sink?(["state": self?.bleManager.getConnectionState() ?? 0,
                 "address": self?.bleManager.getConnectedDeviceAddress() as Any])
        },
        onCancel: { [weak self] in self?.connectionSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.adapter, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in
          self?.adapterSink = sink
          sink?(self?.bleManager.getAdapterState())
        },
        onCancel: { [weak self] in self?.adapterSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.dataReceived, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in self?.dataSink = sink },
        onCancel: { [weak self] in self?.dataSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.battery, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in
          self?.batterySink = sink
          if let info = self?.bleManager.getPhoneBattery() {
            sink?(info)
          }
        },
        onCancel: { [weak self] in self?.batterySink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.chargeLimit, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in
          self?.chargeLimitSink = sink
          sink?(self?.bleManager.getChargeLimit())
        },
        onCancel: { [weak self] in self?.chargeLimitSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.ledTimeout, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in
          self?.ledTimeoutSink = sink
          sink?(self?.bleManager.getLedTimeout())
        },
        onCancel: { [weak self] in self?.ledTimeoutSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.advancedModes, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in
          self?.advancedModesSink = sink
          sink?(self?.bleManager.getAdvancedModes())
        },
        onCancel: { [weak self] in self?.advancedModesSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.batteryHealth, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in self?.batteryHealthSink = sink },
        onCancel: { [weak self] in self?.batteryHealthSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.measureData, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in self?.measureDataSink = sink },
        onCancel: { [weak self] in self?.measureDataSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.batteryMetrics, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in self?.batteryMetricsSink = sink },
        onCancel: { [weak self] in self?.batteryMetricsSink = nil }
      ))
    FlutterEventChannel(name: ChannelNames.otaProgress, binaryMessenger: messenger)
      .setStreamHandler(EventSinkHandler(
        onListen: { [weak self] sink in self?.otaProgressSink = sink },
        onCancel: { [weak self] in self?.otaProgressSink = nil }
      ))
  }

  private func wireManagerCallbacks() {
    bleManager.onDeviceDiscovered = { [weak self] address, name in
      self?.deviceSink?([
        "address": address,
        "name": name
      ])
    }
    bleManager.onDeviceRemoved = { [weak self] address in
      // Send removal event with address and removed flag
      self?.deviceSink?([
        "address": address,
        "name": "", // Empty name indicates removal
        "removed": true
      ])
    }
    bleManager.onConnectionChange = { [weak self] state, address in
      self?.connectionSink?([
        "state": state,
        "address": address as Any
      ])
    }
    bleManager.onAdapterState = { [weak self] state in
      self?.adapterSink?(state)
    }
    bleManager.onDataReceived = { [weak self] data in
      self?.dataSink?(data)
    }
    bleManager.onBattery = { [weak self] level, charging in
      self?.batterySink?([
        "level": level,
        "isCharging": charging
      ])
    }
    bleManager.onChargeLimit = { [weak self] limit, enabled, confirmed in
      self?.chargeLimitSink?([
        "limit": limit,
        "enabled": enabled,
        "confirmed": confirmed
      ])
    }
    bleManager.onLedTimeout = { [weak self] seconds in
      self?.ledTimeoutSink?(seconds)
    }
    bleManager.onAdvancedModes = { [weak self] ghost, silent, higher in
      self?.advancedModesSink?([
        "ghostMode": ghost,
        "silentMode": silent,
        "higherChargeLimit": higher
      ])
    }
    bleManager.onMeasureData = { [weak self] voltage, current in
      self?.measureDataSink?([
        "voltage": voltage,
        "current": current
      ])
    }
    bleManager.onOtaProgress = { [weak self] progress, inProgress, message in
      self?.otaProgressSink?([
        "progress": progress,
        "inProgress": inProgress,
        "message": message ?? ""
      ])
    }
    // batteryMetrics intentionally no-op
  }
  
  // MARK: - Backend Logging
  private func initializeBackendLogging() {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    BackendLoggingService.shared.initialize(appVersion: appVersion, buildNumber: buildNumber)
  }
}

private extension FlutterMethodCall {
  func argumentsAsDict() -> [String: Any] {
    return arguments as? [String: Any] ?? [:]
  }
}

private final class EventSinkHandler: NSObject, FlutterStreamHandler {
  private let onListenClosure: (FlutterEventSink?) -> Void
  private let onCancelClosure: () -> Void

  init(onListen: @escaping (FlutterEventSink?) -> Void, onCancel: @escaping () -> Void) {
    self.onListenClosure = onListen
    self.onCancelClosure = onCancel
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    onListenClosure(events)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    onCancelClosure()
    return nil
  }
}
