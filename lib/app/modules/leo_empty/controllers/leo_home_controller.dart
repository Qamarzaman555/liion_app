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

  // Data from Leo
  final mwhValue = ''.obs;
  final lastReceivedData = ''.obs;
  final receivedDataLog = <String>[].obs;

  StreamSubscription? _deviceSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _dataReceivedSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToAdapterState();
    _listenToDeviceStream();
    _listenToConnectionStream();
    _listenToDataReceived();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    adapterState.value = await BleScanService.getAdapterState();
    connectionState.value = await BleScanService.getConnectionState();
    connectedDeviceAddress.value =
        await BleScanService.getConnectedDeviceAddress();

    if (adapterState.value != BleAdapterState.on) {
      await BleScanService.requestEnableBluetooth();
    }

    await _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await BleScanService.getScannedDevices();
    scannedDevices.assignAll(devices);
    isScanning.value = await BleScanService.isServiceRunning();
  }

  void _listenToAdapterState() {
    _adapterStateSubscription = BleScanService.adapterStateStream.listen((
      state,
    ) {
      adapterState.value = state;

      if (state == BleAdapterState.on) {
        _loadDevices();
      }

      if (state == BleAdapterState.off) {
        scannedDevices.clear();
      }
    });
  }

  void _listenToDeviceStream() {
    _deviceSubscription = BleScanService.deviceStream.listen((device) {
      final exists = scannedDevices.any(
        (d) => d['address'] == device['address'],
      );
      if (!exists) {
        scannedDevices.add(device);
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
        // Request mwh value when connected
        Future.delayed(const Duration(seconds: 1), () {
          requestMwhValue();
        });
      } else if (newState == BleConnectionState.connecting) {
        connectingDeviceAddress.value = address;
      } else if (newState == BleConnectionState.disconnected) {
        connectedDeviceAddress.value = null;
        connectingDeviceAddress.value = null;
      }
    });
  }

  void _listenToDataReceived() {
    _dataReceivedSubscription = BleScanService.dataReceivedStream.listen((
      data,
    ) {
      lastReceivedData.value = data;
      receivedDataLog.insert(
        0,
        '${DateTime.now().toString().substring(11, 19)}: $data',
      );

      // Keep only last 50 entries
      if (receivedDataLog.length > 50) {
        receivedDataLog.removeLast();
      }

      // Parse mwh value
      _parseReceivedData(data);
    });
  }

  void _parseReceivedData(String data) {
    try {
      List<String> parts = data.split(' ');
      if (parts.length >= 2 && parts[1].toLowerCase() == 'mwh') {
        String value = parts.length > 2 ? parts[2] : parts[0];
        value = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (value.isNotEmpty) {
          mwhValue.value = value;
        }
      }
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  /// Request mWh value from Leo
  Future<void> requestMwhValue() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('mwh');
    }
  }

  /// Send custom command to Leo
  Future<bool> sendCommand(String command) async {
    if (connectionState.value != BleConnectionState.connected) {
      return false;
    }
    return await BleScanService.sendCommand(command);
  }

  Future<void> refreshDevices() async {
    await _loadInitialState();
  }

  Future<void> rescan() async {
    if (adapterState.value != BleAdapterState.on) {
      final enabled = await BleScanService.requestEnableBluetooth();
      if (!enabled) return;
    }

    isScanning.value = true;
    scannedDevices.clear();
    await BleScanService.rescan();
    await Future.delayed(const Duration(milliseconds: 500));
    isScanning.value = await BleScanService.isServiceRunning();
  }

  Future<void> connectToDevice(String address) async {
    connectingDeviceAddress.value = address;
    await BleScanService.connect(address);
  }

  Future<void> disconnectDevice() async {
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
    _dataReceivedSubscription?.cancel();
    super.onClose();
  }
}
