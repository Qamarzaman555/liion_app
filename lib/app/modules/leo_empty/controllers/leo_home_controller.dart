import 'dart:async';
import 'package:get/get.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class LeoHomeController extends GetxController {
  final scannedDevices = <Map<String, String>>[].obs;
  final isScanning = false.obs;
  final connectionState = BleConnectionState.disconnected.obs;
  final connectedDeviceAddress = Rxn<String>();
  final connectingDeviceAddress = Rxn<String>();
  final adapterState = BleAdapterState.off.obs;

  StreamSubscription? _deviceSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _adapterStateSubscription;
  Timer? _reconnectTimer;
  bool _shouldAutoReconnect = true;

  @override
  void onInit() {
    super.onInit();
    _listenToAdapterState();
    _listenToDeviceStream();
    _listenToConnectionStream();
    _ensureBluetoothAndLoad();
  }

  Future<void> _ensureBluetoothAndLoad() async {
    // Get initial adapter state
    adapterState.value = await BleScanService.getAdapterState();

    if (adapterState.value != BleAdapterState.on) {
      await BleScanService.requestEnableBluetooth();
    }

    if (adapterState.value == BleAdapterState.on) {
      await _loadDevices();
      await _loadConnectionState();
      _attemptAutoConnect();
    }
  }

  Future<void> _loadDevices() async {
    final devices = await BleScanService.getScannedDevices();
    scannedDevices.assignAll(devices);
    isScanning.value = await BleScanService.isServiceRunning();
  }

  Future<void> _loadConnectionState() async {
    connectionState.value = await BleScanService.getConnectionState();
    connectedDeviceAddress.value =
        await BleScanService.getConnectedDeviceAddress();
  }

  void _listenToAdapterState() {
    _adapterStateSubscription = BleScanService.adapterStateStream.listen((
      state,
    ) {
      final previousState = adapterState.value;
      adapterState.value = state;

      // Bluetooth turned on
      if (state == BleAdapterState.on && previousState != BleAdapterState.on) {
        _onBluetoothEnabled();
      }

      // Bluetooth turned off
      if (state == BleAdapterState.off) {
        _onBluetoothDisabled();
      }
    });
  }

  void _onBluetoothEnabled() async {
    // Start service and load devices when BT is enabled
    await BleScanService.startService();
    await _loadDevices();
    _attemptAutoConnect();
  }

  void _onBluetoothDisabled() {
    // Clear connection state when BT is disabled
    connectionState.value = BleConnectionState.disconnected;
    connectedDeviceAddress.value = null;
    connectingDeviceAddress.value = null;
    scannedDevices.clear();
    _reconnectTimer?.cancel();
  }

  void _listenToDeviceStream() {
    _deviceSubscription = BleScanService.deviceStream.listen((device) {
      final exists = scannedDevices.any(
        (d) => d['address'] == device['address'],
      );
      if (!exists) {
        scannedDevices.add(device);
        // Try auto-connect when a new device is found
        _attemptAutoConnect();
      }
    });
  }

  void _listenToConnectionStream() {
    _connectionSubscription = BleScanService.connectionStream.listen((event) {
      final newState = event['state'] as int;
      final address = event['address'] as String?;

      connectionState.value = newState;

      if (newState == BleConnectionState.connected) {
        connectedDeviceAddress.value = address;
        connectingDeviceAddress.value = null;
        _reconnectTimer?.cancel();

        // Save for auto-reconnect
        if (address != null) {
          final device = scannedDevices.firstWhereOrNull(
            (d) => d['address'] == address,
          );
          if (device != null) {
            BleScanService.saveLastConnectedDevice(
              address,
              device['name'] ?? 'Leo Usb',
            );
          }
        }
      } else if (newState == BleConnectionState.disconnected) {
        connectedDeviceAddress.value = null;
        connectingDeviceAddress.value = null;

        // Auto-reconnect if disconnected unexpectedly and BT is still on
        if (_shouldAutoReconnect && adapterState.value == BleAdapterState.on) {
          _scheduleAutoReconnect();
        }
      }
    });
  }

  void _attemptAutoConnect() async {
    // Don't auto-connect if already connected or connecting
    if (connectionState.value != BleConnectionState.disconnected) return;
    // Don't auto-connect if BT is off
    if (adapterState.value != BleAdapterState.on) return;

    final lastDevice = BleScanService.getLastConnectedDevice();
    if (lastDevice == null) return;

    final address = lastDevice['address'];
    if (address == null) return;

    // Check if the device is in scanned list
    final deviceInList = scannedDevices.any((d) => d['address'] == address);
    if (deviceInList) {
      await connectToDevice(address);
    }
  }

  void _scheduleAutoReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _attemptAutoConnect();
    });
  }

  Future<void> refreshDevices() async {
    await _ensureBluetoothAndLoad();
  }

  Future<void> rescan() async {
    if (adapterState.value != BleAdapterState.on) {
      final enabled = await BleScanService.requestEnableBluetooth();
      if (!enabled) return;
      await BleScanService.startService();
    }

    isScanning.value = true;
    scannedDevices.clear();
    await BleScanService.rescan();
    await Future.delayed(const Duration(milliseconds: 500));
    isScanning.value = await BleScanService.isServiceRunning();
  }

  Future<void> connectToDevice(String address) async {
    _shouldAutoReconnect = true;
    connectingDeviceAddress.value = address;
    await BleScanService.connect(address);
  }

  Future<void> disconnectDevice() async {
    _shouldAutoReconnect = false; // User manually disconnected
    _reconnectTimer?.cancel();
    BleScanService.clearLastConnectedDevice();
    await BleScanService.disconnect();
  }

  bool isDeviceConnected(String address) {
    return connectionState.value == BleConnectionState.connected &&
        connectedDeviceAddress.value == address;
  }

  bool isDeviceConnecting(String address) {
    return connectionState.value == BleConnectionState.connecting &&
        connectingDeviceAddress.value == address;
  }

  bool get isBluetoothOn => adapterState.value == BleAdapterState.on;

  String get adapterStateName => BleAdapterState.getName(adapterState.value);

  @override
  void onClose() {
    _deviceSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _reconnectTimer?.cancel();
    super.onClose();
  }
}
