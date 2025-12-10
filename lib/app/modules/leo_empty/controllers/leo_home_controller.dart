import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/led_timeout/controllers/led_timeout_controller.dart';
import 'package:liion_app/app/modules/leo_empty/models/graph_point.dart';
import 'package:liion_app/app/modules/leo_empty/utils/charge_models.dart';
import 'package:liion_app/app/modules/leo_empty/utils/graph_hive_storage_service.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class LeoHomeController extends GetxController {
  final scannedDevices = <Map<String, String>>[].obs;
  final isScanning = false.obs;
  final connectionState = BleConnectionState.disconnected.obs;
  final connectedDeviceAddress = Rxn<String>();
  final connectingDeviceAddress = Rxn<String>();
  final adapterState = BleAdapterState.off.obs;
  final advancedGhostModeEnabled = false.obs;
  final advancedSilentModeEnabled = false.obs;
  final advancedHigherChargeLimitEnabled = false.obs;

  // Data from Leo
  final mwhValue = ''.obs;
  final binFileFromLeoName = ''.obs;
  final lastReceivedData = ''.obs;
  final receivedDataLog = <String>[].obs;

  String get leoFirmwareVersion => binFileFromLeoName.value;
  set leoFirmwareVersion(String value) {
    binFileFromLeoName.value = value;
  }

  // Measure data (voltage and current)
  final measureDataList = <String>[].obs;
  final voltageValue = ''.obs;
  final currentValue = ''.obs;
  final powerValue = ''.obs;

  // Graph data
  final currentGraphPoints = <GraphPoint>[].obs;
  final lastChargeGraphPoints = <GraphPoint>[].obs;
  final currentGraphXAxisMinLimit = 0.0.obs;
  final lastGraphXAxisMinLimit = 0.0.obs;
  final currentGraphXAxisLimit = 60.0.obs;
  final lastGraphXAxisLimit = 60.0.obs;
  final currentGraphXAxisInterval = 10.0.obs;
  final lastGraphXAxisInterval = 10.0.obs;
  final currentGraphStartTime = Rxn<DateTime>();
  final lastGraphStartTime = Rxn<DateTime>();

  // Add charging mode related variables
  final Rx<ChargingMode> currentMode = ChargingMode.smart.obs;

  StreamSubscription? _deviceSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _dataReceivedSubscription;
  StreamSubscription? _measureDataSubscription;
  Timer? _graphInactivityTimer;
  final isPastGraphLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    clearCurrentGraph();
    _listenToAdapterState();
    _listenToDeviceStream();
    _listenToConnectionStream();
    _listenToDataReceived();
    _listenToMeasureData();
    _loadInitialState();
  }

  @override
  void onReady() {
    super.onReady();
    // Load past graph after first frame so UI becomes visible quickly.
    _restoreGraphFromHive();
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

  void _listenToConnectionStream() async {
    _connectionSubscription = BleScanService.connectionStream.listen((
      event,
    ) async {
      final newState = event['state'] as int;
      final address = event['address'] as String?;

      connectionState.value = newState;

      if (newState == BleConnectionState.connected) {
        connectedDeviceAddress.value = address;
        connectingDeviceAddress.value = null;
        // Request mwh value when connected
        await Future.delayed(const Duration(seconds: 1), () {
          requestMwhValue();
        });
        await Future.delayed(const Duration(milliseconds: 100), () {
          requestLedTimeout();
        });

        await Future.delayed(Duration(milliseconds: 100), () async {
          await BleScanService.sendCommand('py_msg');
        });
        await Future.delayed(const Duration(milliseconds: 100), () {
          requestLeoFirmwareVersion();
        });
        await Future.delayed(const Duration(milliseconds: 100), () {
          requestChargingMode();
        });

        await Future.delayed(const Duration(milliseconds: 500), () {
          initializeAdvancedSettings();
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
      if (receivedDataLog.length > 10) {
        receivedDataLog.removeLast();
      }

      // Parse mwh value
      _parseReceivedData(data);
    });
  }

  void _listenToMeasureData() {
    _measureDataSubscription = BleScanService.measureDataStream.listen((data) {
      final voltage = double.tryParse(data.voltage);
      final current = double.tryParse(data.current);

      voltageValue.value = voltage != null
          ? '${voltage.toStringAsFixed(3)}V'
          : data.voltage;
      currentValue.value = current != null
          ? '${current.toStringAsFixed(3)}A'
          : data.current;

      _updatePower(voltage, current);
    });
  }

  void _parseReceivedData(String data) {
    try {
      List<String> parts = data.split(' ');
      print('Received data parts: $parts');

      // Parse mwh value
      if (parts.length >= 2 && parts[1].toLowerCase() == 'mwh') {
        String value = parts.length > 2 ? parts[2] : parts[0];
        value = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (value.isNotEmpty) {
          mwhValue.value = value;
        }
      }

      // Parse swversion value
      if (parts.length >= 2 && parts[1].toLowerCase() == 'swversion') {
        String value = parts.length > 2 ? parts[2] : parts[0];
        binFileFromLeoName.value = value.trim();
      }

      // Parse measure data - check if any part contains 'measure'
      if (parts.isNotEmpty &&
          (parts[1] == 'measure' || parts.contains('measure'))) {
        print('Measure data detected: $parts');
        bool isValid = _canParseToDouble(parts, 2, 4);
        print('Is valid: $isValid');
        if (isValid) {
          measureDataList.assignAll(parts);

          String safeValue = parts[10];
          // Get.find<LogsController>().logMessage(
          //     "(batteryController)measure command response received");

          /// Charge Mode Update
          if (safeValue == "0") {
            currentMode.value = ChargingMode.smart;
          } else if (safeValue == "1") {
            currentMode.value = ChargingMode.ghost;
          } else if (safeValue == "2") {
            currentMode.value = ChargingMode.safe;
          }

          // Index 4 is current
          double current = double.parse(parts[4]).abs();
          currentValue.value = '${current.toStringAsFixed(3)}A';
          print('Current value set: ${currentValue.value}');

          // Index 2 and 3 are voltages, show the higher one
          double v1 = double.parse(parts[2]);
          double v2 = double.parse(parts[3]);
          double voltage = v1 > v2 ? v1 : v2;
          voltageValue.value = '${voltage.toStringAsFixed(3)}V';
          print('Voltage value set: ${voltageValue.value}');
          _updatePower(voltage, current);

          // Add to graph using the same value shown in UI
          _addGraphSample(current);
        }
      }
      if (parts[2] == "chmode") {
        String safeValue = parts[1];
        safeValue = safeValue.replaceAll(RegExp(r'[^0-9]'), '');
        print("Safe value is $safeValue  ${safeValue.runtimeType}");
        if (safeValue == "0") {
          currentMode.value = ChargingMode.smart;
        } else if (safeValue == "1") {
          currentMode.value = ChargingMode.ghost;
        } else if (safeValue == "2") {
          currentMode.value = ChargingMode.safe;
        }
      }

      // Also try parsing if we have enough numeric values (fallback)
      if (parts.length >= 5 && voltageValue.value.isEmpty) {
        bool hasNumericData = _canParseToDouble(parts, 2, 4);
        if (hasNumericData) {
          print('Fallback measure parsing: $parts');
          measureDataList.assignAll(parts);

          double current = double.parse(parts[4]).abs();
          currentValue.value = '${current.toStringAsFixed(3)}A';

          double v1 = double.parse(parts[2]);
          double v2 = double.parse(parts[3]);
          double voltage = v1 > v2 ? v1 : v2;
          voltageValue.value = '${voltage.toStringAsFixed(3)}V';
          _updatePower(voltage, current);

          // Add to graph using the same value shown in UI
          _addGraphSample(current);
        }
      }

      if (parts.length > 3 && parts[2] == "ghost_mode") {
        String safeValue = parts[3];
        safeValue = safeValue.replaceAll(RegExp(r'[^0-9]'), '');
        if (safeValue == "1") {
          advancedGhostModeEnabled.value = true;
          print('Ghost mode enabled: $advancedGhostModeEnabled.value');
        } else {
          advancedGhostModeEnabled.value = false;
          print('Ghost mode disabled: $advancedGhostModeEnabled.value');
        }
      }

      if (parts.length > 3 && parts[2] == "quiet_mode") {
        String safeValue = parts[3];
        safeValue = safeValue.replaceAll(RegExp(r'[^0-9]'), '');
        if (safeValue == "1") {
          advancedSilentModeEnabled.value = true;
          print('Silent mode enabled: $advancedSilentModeEnabled.value');
        } else {
          advancedSilentModeEnabled.value = false;
          print('Silent mode disabled: $advancedSilentModeEnabled.value');
        }
      }

      if (parts.length > 3 && parts[2] == "charge_limit") {
        String safeValue = parts[3];
        safeValue = safeValue.replaceAll(RegExp(r'[^0-9]'), '');
        if (safeValue == "1") {
          advancedHigherChargeLimitEnabled.value = true;
          print(
            'Higher charge limit enabled: $advancedHigherChargeLimitEnabled.value',
          );
        } else {
          advancedHigherChargeLimitEnabled.value = false;
          print(
            'Higher charge limit disabled: $advancedHigherChargeLimitEnabled.value',
          );
        }
      }

      if (parts.length > 2 && parts[2] == "led_time_before_dim") {
        print("1");
        // Expect responses like: OK py_msg led_time_before_dim 50
        if (parts.length <= 3) return;
        print("2");

        final rawValue = parts[3].trim();
        final numericOnly = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
        final parsed = int.tryParse(numericOnly);
        if (parsed == null) {
          print('Ignoring non-numeric led_time_before_dim value: $rawValue');
          print("4");
          return;
        }

        final ledController = Get.find<LedTimeoutController>();
        ledController.timeoutSeconds.value = parsed;
        ledController.timeoutTextController.text = parsed.toString();
        print("LedTimer: ${ledController.timeoutSeconds.value}");
        print("LedTimer: ${ledController.timeoutTextController.text}");
      }
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  bool _canParseToDouble(List<String> list, int index1, int index2) {
    try {
      if (list.length <= index1 || list.length <= index2) return false;
      double.parse(list[index1]);
      double.parse(list[index2]);
      return true;
    } catch (e) {
      return false;
    }
  }

  void _updatePower(double? voltage, double? current) {
    if (voltage == null || current == null) return;
    final power = (voltage * current).abs();
    powerValue.value = '${power.toStringAsFixed(3)}W';
  }

  void _addGraphSample(double current) {
    final now = DateTime.now();
    currentGraphStartTime.value ??= now;
    final elapsedSeconds = now
        .difference(currentGraphStartTime.value!)
        .inSeconds
        .toDouble();
    currentGraphPoints.add(
      GraphPoint(seconds: elapsedSeconds, current: current.toDouble()),
    );
    _updateCurrentGraphAxis(elapsedSeconds);
    // Persist to Hive for crash/kill-safe recovery.
    GraphHiveStorageService.appendCurrentSample(
      seconds: elapsedSeconds,
      current: current.toDouble(),
    );
  }

  void _updateCurrentGraphAxis(double elapsedSeconds) {
    final adjustedMax = max(60.0, elapsedSeconds);
    currentGraphXAxisLimit.value = adjustedMax;
    currentGraphXAxisInterval.value = _computeXAxisInterval(adjustedMax);
  }

  /// Compute X axis interval so that we only show about 3–4 labels on the
  /// bottom axis, regardless of how long the session is.
  double _computeXAxisInterval(double maxRangeSeconds) {
    // Guard against invalid ranges
    if (maxRangeSeconds <= 0) {
      return 10.0;
    }

    // We want roughly this many labels on the X axis.
    const targetLabelCount = 4;

    // With minX fixed at 0 for now, the visible range is simply [0, maxRangeSeconds].
    final range = maxRangeSeconds;

    // Ensure at least two labels (start and end).
    final effectiveLabelCount = max(2, targetLabelCount);

    // Raw spacing to hit the target label count.
    final rawInterval = range / (effectiveLabelCount - 1);

    // We could "beautify" the interval to round values, but since labels are
    // formatted as durations (e.g. 5m13s, 1h02m), using the raw interval keeps
    // the label count low and readable even for long sessions.
    return rawInterval;
  }

  Future<void> _restoreGraphFromHive() async {
    isPastGraphLoading.value = true;
    try {
      // 1) Restore any previously archived "last" (past) session so it
      // survives across app restarts.
      final storedLast = await GraphHiveStorageService.getPastSamples();
      if (storedLast.isNotEmpty) {
        lastChargeGraphPoints.assignAll(
          storedLast
              .map((e) => GraphPoint(seconds: e.dataKey, current: e.value))
              .toList(),
        );

        final lastSeconds = lastChargeGraphPoints.last.seconds;
        final adjustedMaxLast = max(60.0, lastSeconds);
        lastGraphXAxisLimit.value = adjustedMaxLast;
        lastGraphXAxisInterval.value = _computeXAxisInterval(adjustedMaxLast);
      }

      // 2) Handle any interrupted "current" session from the previous run.
      final storedCurrent = await GraphHiveStorageService.getCurrentSamples();
      if (storedCurrent.isEmpty) {
        return;
      }

      final bool shouldPromote = GraphHiveStorageService.checkDataConditions(
        storedCurrent,
      );

      if (!shouldPromote) {
        // Session didn't meet overall conditions: drop it, but DO NOT touch
        // the previously archived past graph, which is already restored.
        await GraphHiveStorageService.clearCurrentSamples();
        clearCurrentGraph();
        return;
      }

      // Promote the completed current session to be the new "last" (past)
      // charge graph and persist it, replacing any older past graph.
      lastChargeGraphPoints.assignAll(
        storedCurrent
            .map((e) => GraphPoint(seconds: e.dataKey, current: e.value))
            .toList(),
      );

      final durationSeconds =
          storedCurrent.last.dataKey - storedCurrent.first.dataKey;
      final adjustedMax = max(60.0, durationSeconds);
      lastGraphXAxisLimit.value = adjustedMax;
      lastGraphXAxisInterval.value = _computeXAxisInterval(adjustedMax);

      await GraphHiveStorageService.replacePastSamples(storedCurrent);
      await GraphHiveStorageService.clearCurrentSamples();
      clearCurrentGraph();
    } finally {
      isPastGraphLoading.value = false;
    }
  }

  void finalizeCurrentGraphSession() {
    _graphInactivityTimer?.cancel();
    if (currentGraphPoints.isEmpty) return;

    final durationSeconds = currentGraphPoints.last.seconds;
    final hasOnlyTinyCurrents = currentGraphPoints.every(
      (point) => point.current < 0.2,
    );

    if (durationSeconds < 240 || hasOnlyTinyCurrents) {
      clearCurrentGraph();
      return;
    }

    lastChargeGraphPoints.assignAll(currentGraphPoints);
    lastGraphXAxisLimit.value = currentGraphXAxisLimit.value;
    lastGraphXAxisInterval.value = currentGraphXAxisInterval.value;
    lastGraphStartTime.value = currentGraphStartTime.value;

    clearCurrentGraph();
  }

  void clearCurrentGraph() {
    currentGraphPoints.clear();
    currentGraphStartTime.value = null;
    currentGraphXAxisMinLimit.value = 0.0;
    currentGraphXAxisLimit.value = 60.0;
    currentGraphXAxisInterval.value = 10.0;
  }

  String formatDurationLabel(double value) {
    final totalSeconds = value.round();
    if (totalSeconds <= 0) return '0s';
    final duration = Duration(seconds: totalSeconds);
    if (duration.inHours >= 1) {
      final minutes = duration.inMinutes
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      return '${duration.inHours}h${minutes}m';
    }
    if (duration.inMinutes >= 1) {
      final seconds = duration.inSeconds
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      return '${duration.inMinutes}m${seconds}s';
    }
    return '${duration.inSeconds}s';
  }

  double resolveYAxisMax(List<GraphPoint> points) {
    if (points.isEmpty) {
      return 2.0;
    }
    final maxValue = points.fold<double>(
      0,
      (previous, element) =>
          element.current > previous ? element.current : previous,
    );
    final base = max(maxValue, 2.0);
    return (base / 0.5).ceil() * 0.5;
  }

  double resolveYAxisInterval(double maxY) {
    if (maxY <= 1) return 0.1;
    if (maxY <= 5) return 0.5;
    if (maxY <= 10) return 1.0;
    return 2.0;
  }

  List<double> get currentTimeValues =>
      currentGraphPoints.map((point) => point.seconds).toList();

  List<double> get lastTimeValues =>
      lastChargeGraphPoints.map((point) => point.seconds).toList();

  String formatTimeForBottomGraph(double seconds) =>
      formatDurationLabel(seconds);

  /// Request mWh value from Leo
  Future<void> requestMwhValue() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('mwh');
    }
  }

  Future<void> requestLeoFirmwareVersion() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('swversion');
    }
  }

  Future<void> requestChargingMode() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('chmode');
    }
  }

  Future<void> requestAdvancedGhostMode() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('app_msg ghost_mode');
    }
  }

  Future<void> requestAdvancedSilentMode() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('app_msg quiet_mode');
    }
  }

  Future<void> requestAdvancedHigherChargeLimit() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('app_msg charge_limit');
    }
  }

  Future<void> requestLedTimeout() async {
    if (connectionState.value == BleConnectionState.connected) {
      await BleScanService.sendCommand('app_msg led_time_before_dim');
    }
  }

  /// Initialize advanced settings by sequentially requesting each mode
  /// to avoid BLE write collisions
  Future<void> initializeAdvancedSettings() async {
    if (connectionState.value != BleConnectionState.connected) {
      return;
    }

    // Request ghost mode
    await requestAdvancedGhostMode();
    await Future.delayed(const Duration(milliseconds: 200));
    await BleScanService.sendCommand('py_msg');
    await Future.delayed(const Duration(milliseconds: 200));

    // Request silent mode
    await requestAdvancedSilentMode();
    await Future.delayed(const Duration(milliseconds: 200));
    await BleScanService.sendCommand('py_msg');
    await Future.delayed(const Duration(milliseconds: 200));

    // Request higher charge limit
    await requestAdvancedHigherChargeLimit();
    await Future.delayed(const Duration(milliseconds: 200));
    await BleScanService.sendCommand('py_msg');

    await Future.delayed(const Duration(milliseconds: 200), () {});
  }

  /// Send custom command to Leo
  Future<bool> sendCommand(String command) async {
    if (connectionState.value != BleConnectionState.connected) {
      return false;
    }
    return await BleScanService.sendCommand(command);
  }

  // Update charging mode
  Future<void> updateChargingMode(ChargingMode mode) async {
    if (connectionState.value == BleConnectionState.disconnected) {
      AppSnackbars.showSuccess(
        title: "No Device Connected",
        message: "Please connect to a device to update the charging mode",
      );
      return;
    }

    try {
      // Send mode change command to Leo
      await BleScanService.sendCommand("chmode ${mode.index}\n");
    } catch (e) {
      // Revert the mode if the command fails
      currentMode.value = ChargingMode.smart;
      AppSnackbars.showSuccess(
        title: "Failed to update charging mode",
        message: "Please try again",
      );
    }
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
    _measureDataSubscription?.cancel();
    _graphInactivityTimer?.cancel();
    super.onClose();
  }
}
