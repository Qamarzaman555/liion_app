import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/modules/leo_empty/models/graph_point.dart';
import 'package:liion_app/app/modules/leo_empty/utils/charge_models.dart';
import 'package:liion_app/app/modules/leo_empty/utils/graph_hive_storage_service.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/services/ios_ble_scan_service.dart';
import 'package:liion_app/app/modules/led_timeout/controllers/led_timeout_controller.dart';

class LeoHomeController extends GetxController {
  static const _thankYouNoteSeenKey = 'first_time_thank_you_seen';

  final scannedDevices = <Map<String, String>>[].obs;
  final isScanning = false.obs;
  final connectionState = BleConnectionState.disconnected.obs;
  final connectedDeviceAddress = Rxn<String>();
  final connectedDeviceName = Rxn<String>(); // Store connected device name
  final connectingDeviceAddress = Rxn<String>();
  final adapterState = BleAdapterState.off.obs;
  final advancedGhostModeEnabled = false.obs;
  final advancedSilentModeEnabled = false.obs;
  final advancedHigherChargeLimitEnabled = false.obs;
  final showThankYouNote = false.obs;
  final hasConnectedOnce = false.obs;
  final firmwareVersionStatusText = ''.obs;

  final oneTimeSendCommand = true.obs;

  // Track if initial requests have been sent for current connection (prevents duplicates)
  String? _lastInitialRequestsAddress;

  // Data from Leo
  final mwhValue = ''.obs;
  final binFileFromLeoName = ''.obs;
  final lastReceivedData = ''.obs;
  final receivedDataLog = <String>[].obs;
  final cloudBinFileName = ''.obs;
  final isFirmwareDownloading = false.obs;

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
  StreamSubscription? _advancedModesSubscription;
  Timer? _graphInactivityTimer;
  final isPastGraphLoading = false.obs;
  Future<void> _commandSerial = Future.value();

  @override
  void onInit() {
    super.onInit();
    clearCurrentGraph();
    _listenToAdapterState();
    _listenToDeviceStream();
    _listenToConnectionStream();
    _listenToDataReceived();
    _listenToMeasureData();
    _listenToAdvancedModes();
    _loadInitialState();
    _loadThankYouNoteState();
  }

  @override
  void onReady() {
    super.onReady();
    // Load past graph after first frame so UI becomes visible quickly.
    _restoreGraphFromHive();
  }

  String firmwareStatusText() {
    if (isFirmwareDownloading.value) {
      return 'Checking updates...';
    }

    final leoVersion = binFileFromLeoName.value.trim();
    final cloudVersion = cloudBinFileName.value.trim();

    return (cloudVersion == leoVersion || leoVersion.isEmpty)
        ? 'Leo is up-to-date'
        : 'Update Leo';
  }

  Future<void> _loadInitialState() async {
    // Get adapter state
    if (Platform.isIOS) {
      final enabled = await IOSBleScanService.isBluetoothEnabled();
      adapterState.value = enabled ? BleAdapterState.on : BleAdapterState.off;
    } else {
      adapterState.value = await BleScanService.getAdapterState();
    }

    // Get connection state
    if (Platform.isIOS) {
      final connected = await IOSBleScanService.isConnected();
      connectionState.value = connected
          ? BleConnectionState.connected
          : BleConnectionState.disconnected;
    } else {
      connectionState.value = await BleScanService.getConnectionState();
    }

    // Get connected device address and name
    if (Platform.isIOS) {
      final device = await IOSBleScanService.getConnectedDevice();
      connectedDeviceAddress.value = device?['address'];
      connectedDeviceName.value = device?['name']; // Load device name for iOS
    } else {
      connectedDeviceAddress.value =
          await BleScanService.getConnectedDeviceAddress();
    }

    // Get advanced modes (both Android and iOS)
    if (Platform.isAndroid) {
      final cachedAdvanced = await BleScanService.getAdvancedModes();
      advancedGhostModeEnabled.value = cachedAdvanced.ghostMode;
      advancedSilentModeEnabled.value = cachedAdvanced.silentMode;
      advancedHigherChargeLimitEnabled.value = cachedAdvanced.higherChargeLimit;
    } else if (Platform.isIOS) {
      final cachedAdvanced = await IOSBleScanService.getAdvancedModes();
      advancedGhostModeEnabled.value = cachedAdvanced['ghostMode'] ?? false;
      advancedSilentModeEnabled.value = cachedAdvanced['silentMode'] ?? false;
      advancedHigherChargeLimitEnabled.value =
          cachedAdvanced['higherChargeLimit'] ?? false;
    }

    // Request enable Bluetooth if needed
    if (adapterState.value != BleAdapterState.on) {
      if (Platform.isIOS) {
        await IOSBleScanService.isBluetoothEnabled();
      } else {
        await BleScanService.requestEnableBluetooth();
      }
    }

    await _loadDevices();
  }

  Future<void> _loadThankYouNoteState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenNote = prefs.getBool(_thankYouNoteSeenKey) ?? false;
    showThankYouNote.value = !hasSeenNote;
  }

  Future<void> dismissThankYouNote() async {
    showThankYouNote.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_thankYouNoteSeenKey, true);
  }

  Future<void> _loadDevices() async {
    final devices = Platform.isIOS
        ? await IOSBleScanService.getDiscoveredDevices()
        : await BleScanService.getScannedDevices();
    scannedDevices.assignAll(devices);
    isScanning.value = Platform.isIOS
        ? true
        : await BleScanService.isServiceRunning();
  }

  /// Download firmware from Firebase at app start to compare versions.
  Future<void> downloadFirmwareAtStart() async {
    if (isFirmwareDownloading.value) return;

    try {
      isFirmwareDownloading.value = true;
      cloudBinFileName.value = '';

      final storage = firebase_storage.FirebaseStorage.instance;
      final result = await storage.ref('Beta fw').listAll();

      if (result.items.isEmpty) {
        return;
      }

      final tempDirPath = (await getTemporaryDirectory()).path;

      for (var ref in result.items) {
        final fileName = ref.name.replaceAll('.img', '');
        final file = File('$tempDirPath/$fileName');
        await ref.writeToFile(file);

        // Capture the first downloaded filename for version comparison.
        if (cloudBinFileName.value.isEmpty) {
          cloudBinFileName.value = fileName;
        }
      }

      // Fallback to first item if somehow not set.
      if (cloudBinFileName.value.isEmpty) {
        cloudBinFileName.value = result.items.first.name.replaceAll('.img', '');
      }
    } catch (e) {
      print('Error downloading firmware at start: $e');
    } finally {
      isFirmwareDownloading.value = false;
      print('Cloud bin file name: ${cloudBinFileName.value}');
    }
  }

  void _listenToAdapterState() {
    final stream = Platform.isIOS
        ? IOSBleScanService.getAdapterStateStream()
        : BleScanService.adapterStateStream;
    _adapterStateSubscription = stream.listen((state) {
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
    final stream = Platform.isIOS
        ? IOSBleScanService.getDeviceStream()
        : BleScanService.deviceStream;
    _deviceSubscription = stream.listen((device) {
      final exists = scannedDevices.any(
        (d) => d['address'] == device['address'],
      );
      if (!exists) {
        scannedDevices.add(device);
      }
    });
  }

  void _listenToConnectionStream() async {
    final stream = Platform.isIOS
        ? IOSBleScanService.getConnectionStream()
        : BleScanService.connectionStream;

    if (Platform.isIOS) {
      // iOS-specific connection handling with new connection detection
      int? previousState; // Track previous state to detect transitions
      String? previousAddress; // Track previous address to detect reconnections

      _connectionSubscription = stream.listen((event) async {
        final newState = event['state'] as int;
        final address = event['address'] as String?;
        final name =
            event['name']
                as String?; // Extract device name from connection event

        connectionState.value = newState;

        final stateChanged = previousState != newState;
        final addressChanged = previousAddress != address;
        final isNewConnection =
            stateChanged &&
            newState == BleConnectionState.connected &&
            (previousState != BleConnectionState.connected || addressChanged);

        if (newState == BleConnectionState.connected) {
          if (oneTimeSendCommand.value) {
            oneTimeSendCommand.value = false;
            print('Sending firmware version commands');
            await requestLeoFirmwareVersion();
            await requestMwhValue();
            firmwareVersionStatusText.value = firmwareStatusText();
            print(
              'Firmware version commands sent: ${firmwareVersionStatusText.value}',
            );
            return;
          }
          // Only execute initial requests on NEW connection (not on every poll)
          if (isNewConnection) {
            hasConnectedOnce.value = true;
            if (showThankYouNote.value) {
              await dismissThankYouNote();
            }
            connectedDeviceAddress.value = address;
            connectedDeviceName.value = name; // Store connected device name
            connectingDeviceAddress.value = null;

            // Prevent duplicate initial requests for same device
            if (_lastInitialRequestsAddress != address) {
              _lastInitialRequestsAddress = address;

              // iOS native already sent: charge limit, LED timeout, advanced modes (when UART ready)
              // Flutter sends UI-ready commands once when UI is ready (not repeatedly)
              Future.delayed(const Duration(seconds: 2), () async {
                // Wait for UART to be ready and initial setup to complete
                try {
                  await IOSBleScanService.sendUIReadyCommands();
                } catch (e) {
                  print('[iOS] Failed to send UI-ready commands: $e');
                }
              });
            }
          } else {
            // Update address/name if changed but don't resend commands
            connectedDeviceAddress.value = address;
            connectedDeviceName.value = name;
          }
        } else if (newState == BleConnectionState.connecting) {
          oneTimeSendCommand.value = true;
          print('One time send command reset to ${oneTimeSendCommand.value}');
          connectingDeviceAddress.value = address;
        } else if (newState == BleConnectionState.disconnected) {
          connectedDeviceAddress.value = null;
          connectedDeviceName.value = null; // Clear device name on disconnect
          connectingDeviceAddress.value = null;
          // Reset initial requests flag on disconnect so they can be sent again on next connection
          _lastInitialRequestsAddress = null;
        }

        // Update previous state/address for next iteration (iOS only)
        previousState = newState;
        previousAddress = address;
      });
    } else {
      // Android: Keep original behavior completely unchanged
      _connectionSubscription = stream.listen((event) async {
        final newState = event['state'] as int;
        final address = event['address'] as String?;
        final name =
            event['name']
                as String?; // Extract device name from connection event

        connectionState.value = newState;

        if (newState == BleConnectionState.connected) {
          hasConnectedOnce.value = true;
          if (showThankYouNote.value) {
            await dismissThankYouNote();
          }
          connectedDeviceAddress.value = address;
          connectedDeviceName.value = name;
          connectingDeviceAddress.value = null;

          // Request firmware version after OTA reconnection to get updated version
          // Add delay to ensure BLE services are discovered and UART is ready
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              await requestLeoFirmwareVersion();
            } catch (e) {
              print(
                '🟡 [OTA Controller] Could not request firmware version: $e',
              );
            }
          });
          await _scheduleInitialRequests();
        } else if (newState == BleConnectionState.connecting) {
          connectingDeviceAddress.value = address;
        } else if (newState == BleConnectionState.disconnected) {
          connectedDeviceAddress.value = null;
          connectedDeviceName.value = null;
          connectingDeviceAddress.value = null;
        }
      });
    }
  }

  void _listenToDataReceived() {
    final stream = Platform.isAndroid
        ? BleScanService.dataReceivedStream
        : IOSBleScanService.getDataReceivedStream();
    _dataReceivedSubscription = stream.listen((data) {
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
    if (Platform.isAndroid) {
      // Android: Use EventChannel stream
      _measureDataSubscription = BleScanService.measureDataStream.listen((
        data,
      ) {
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
    } else if (Platform.isIOS) {
      // iOS: Use polling stream
      _measureDataSubscription = IOSBleScanService.getMeasureDataStream()
          .listen((data) {
            final voltage = double.tryParse(data['voltage'] ?? '');
            final current = double.tryParse(data['current'] ?? '');

            voltageValue.value = voltage != null
                ? '${voltage.toStringAsFixed(3)}V'
                : (data['voltage'] ?? '');
            currentValue.value = current != null
                ? '${current.toStringAsFixed(3)}A'
                : (data['current'] ?? '');

            _updatePower(voltage, current);
          });
    }
  }

  void _listenToAdvancedModes() {
    if (Platform.isAndroid) {
      // Android: Use EventChannel stream
      _advancedModesSubscription = BleScanService.advancedModesStream.listen((
        modes,
      ) {
        advancedGhostModeEnabled.value = modes.ghostMode;
        advancedSilentModeEnabled.value = modes.silentMode;
        advancedHigherChargeLimitEnabled.value = modes.higherChargeLimit;
      });
    } else if (Platform.isIOS) {
      // iOS: Use polling stream
      _advancedModesSubscription = IOSBleScanService.getAdvancedModesStream()
          .listen((modes) {
            advancedGhostModeEnabled.value = modes['ghostMode'] ?? false;
            advancedSilentModeEnabled.value = modes['silentMode'] ?? false;
            advancedHigherChargeLimitEnabled.value =
                modes['higherChargeLimit'] ?? false;
          });
    }
  }

  void _parseReceivedData(String data) {
    try {
      List<String> parts = data.split(' ');
      print('Received data parts: $parts');

      // Ignore very short messages to avoid RangeError on indexed access.
      if (parts.length < 3) {
        return;
      }

      // Parse mwh value: "OK mwh 363601" or "OK mwh 363601\n"
      if (parts.length >= 2 && parts[1].toLowerCase() == 'mwh') {
        String value = '';
        if (parts.length > 2) {
          // Format: "OK mwh 363601"
          value = parts[2].trim();
        } else if (parts.length == 2 && parts[0].toLowerCase() == 'ok') {
          // Format: "OK mwh" (unlikely but handle it)
          value = '';
        }
        // Extract only digits
        value = value.replaceAll(RegExp(r'[^0-9]'), '');
        print('Mwh value parsed: $value from parts: $parts');
        if (value.isNotEmpty) {
          mwhValue.value = value;
          print('Mwh value set to: ${mwhValue.value}');
        } else {
          print('Mwh value is empty after parsing');
        }
      }

      // Parse swversion value
      if (parts.length >= 2 && parts[1].toLowerCase() == 'swversion') {
        String value = parts.length > 2 ? parts[2] : parts[0];
        binFileFromLeoName.value = value.trim();
        firmwareVersionStatusText.value = firmwareStatusText();
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
      if (Platform.isAndroid) {
        await BleScanService.sendCommand('mwh');
      } else if (Platform.isIOS) {
        // On iOS, return the cached mWh value saved by native BLE service
        try {
          final cached = await IOSBleScanService.getCachedMwh();
          if (cached.isNotEmpty) {
            mwhValue.value = cached;
          }
        } catch (e) {
          // ignore and do not send command
        }
      }
    }
  }

  Future<void> requestLeoFirmwareVersion() async {
    if (connectionState.value == BleConnectionState.connected) {
      if (Platform.isAndroid) {
        await BleScanService.sendCommand('measure');
        await Future.delayed(const Duration(milliseconds: 300));
        await BleScanService.sendCommand('swversion');
      } else if (Platform.isIOS) {
        // Request live measure data, but fetch swversion & mwh from native cache
        try {
          final cachedSw = await IOSBleScanService.getCachedSwversion();
          print('Cached swversion: $cachedSw');
          if (cachedSw.isNotEmpty) {
            binFileFromLeoName.value = cachedSw.trim();
            print('Cached swversion set to: ${binFileFromLeoName.value}');
            firmwareVersionStatusText.value = firmwareStatusText();
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 200));

        try {
          final cachedMwh = await IOSBleScanService.getCachedMwh();
          if (cachedMwh.isNotEmpty) {
            mwhValue.value = cachedMwh;
          }
        } catch (_) {}
      }
    }
  }

  Future<void> requestChargingMode() async {
    if (connectionState.value == BleConnectionState.connected) {
      if (Platform.isAndroid) {
        await BleScanService.sendCommand('chmode');
      } else if (Platform.isIOS) {
        await IOSBleScanService.sendCommand('chmode');
      }
    }
  }

  Future<void> requestAdvancedGhostMode() async {
    if (connectionState.value == BleConnectionState.connected) {
      if (Platform.isAndroid) {
        await BleScanService.requestAdvancedModes();
      } else if (Platform.isIOS) {
        await IOSBleScanService.requestAdvancedModes();
      }
    }
  }

  Future<void> requestAdvancedSilentMode() async {
    if (connectionState.value == BleConnectionState.connected) {
      if (Platform.isAndroid) {
        await BleScanService.requestAdvancedModes();
      } else if (Platform.isIOS) {
        await IOSBleScanService.requestAdvancedModes();
      }
    }
  }

  Future<void> requestAdvancedHigherChargeLimit() async {
    if (connectionState.value == BleConnectionState.connected) {
      if (Platform.isAndroid) {
        await BleScanService.requestAdvancedModes();
      } else if (Platform.isIOS) {
        await IOSBleScanService.requestAdvancedModes();
      }
    }
  }

  Future<void> requestLedTimeout() async {
    if (connectionState.value == BleConnectionState.connected) {
      if (Platform.isAndroid) {
        await BleScanService.requestLedTimeout();
      } else if (Platform.isIOS) {
        await IOSBleScanService.requestLedTimeout();
      }
      // Also sync the UI controller with the latest cached value.
      try {
        final ledController = Get.find<LedTimeoutController>();
        await ledController.refreshTimeout();
      } catch (_) {
        // Controller might not be registered in some flows; ignore.
      }
    }
  }

  /// Initialize advanced settings by sequentially requesting each mode
  /// to avoid BLE write collisions
  Future<void> initializeAdvancedSettings() async {
    if (connectionState.value != BleConnectionState.connected) {
      return;
    }

    if (Platform.isAndroid) {
      final cachedModes = await BleScanService.getAdvancedModes();
      advancedGhostModeEnabled.value = cachedModes.ghostMode;
      advancedSilentModeEnabled.value = cachedModes.silentMode;
      advancedHigherChargeLimitEnabled.value = cachedModes.higherChargeLimit;
    } else if (Platform.isIOS) {
      final cachedModes = await IOSBleScanService.getAdvancedModes();
      advancedGhostModeEnabled.value = cachedModes['ghostMode'] ?? false;
      advancedSilentModeEnabled.value = cachedModes['silentMode'] ?? false;
      advancedHigherChargeLimitEnabled.value =
          cachedModes['higherChargeLimit'] ?? false;
    }
  }

  Future<void> _scheduleInitialRequests() async {
    // Requests are enqueued to a serialized chain so we never attempt
    // concurrent BLE writes (prevents "prior command not finished" errors).
    await _enqueueCommand(
      () => requestLedTimeout(),
      delayAfter: const Duration(milliseconds: 150),
    );
    await _enqueueCommand(
      () => requestMwhValue(),
      delayAfter: const Duration(milliseconds: 200),
    );
    await _enqueueCommand(
      () => requestLeoFirmwareVersion(),
      delayAfter: const Duration(milliseconds: 200),
    );
    await _enqueueCommand(
      () => requestChargingMode(),
      delayAfter: const Duration(milliseconds: 150),
    );
  }

  Future<void> _enqueueCommand(
    Future<void> Function() action, {
    Duration delayAfter = Duration.zero,
  }) {
    _commandSerial = _commandSerial.then((_) async {
      await action();
      if (delayAfter > Duration.zero) {
        await Future.delayed(delayAfter);
      }
    });

    return _commandSerial;
  }

  /// Send custom command to Leo
  Future<bool> sendCommand(String command) async {
    if (connectionState.value != BleConnectionState.connected) {
      return false;
    }
    if (Platform.isAndroid) {
      return await BleScanService.sendCommand(command);
    } else if (Platform.isIOS) {
      return await IOSBleScanService.sendCommand(command);
    }
    return false;
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
      if (Platform.isAndroid) {
        await BleScanService.sendCommand("chmode ${mode.index}\n");
      } else if (Platform.isIOS) {
        await IOSBleScanService.sendCommand("chmode ${mode.index}\n");
      }
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
      final enabled = Platform.isIOS
          ? await IOSBleScanService.isBluetoothEnabled()
          : await BleScanService.requestEnableBluetooth();
      if (!enabled) return;
    }

    isScanning.value = true;
    scannedDevices.clear();

    if (Platform.isIOS) {
      await IOSBleScanService.rescan();
    } else {
      await BleScanService.rescan();
    }

    await Future.delayed(const Duration(milliseconds: 500));
    isScanning.value = Platform.isIOS
        ? true
        : await BleScanService.isServiceRunning();
  }

  Future<void> connectToDevice(String address) async {
    connectingDeviceAddress.value = address;
    if (Platform.isIOS) {
      await IOSBleScanService.connect(address);
    } else {
      await BleScanService.connect(address);
    }
  }

  Future<void> disconnectDevice() async {
    if (Platform.isIOS) {
      await IOSBleScanService.disconnect();
    } else {
      await BleScanService.disconnect();
    }
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
    _advancedModesSubscription?.cancel();
    _graphInactivityTimer?.cancel();
    super.onClose();
  }
}
