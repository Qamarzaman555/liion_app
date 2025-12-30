import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LeoOtaController extends GetxController {
  // OTA state
  final isOtaInProgress = false.obs;
  final otaProgress = 0.0.obs;
  final cloudBinFilePath = ''.obs;
  final binFileFromFirebaseName = ''.obs;
  final isDownloadingFirmware = false.obs;
  final downloadProgress = 0.0.obs;
  final otaMessage = ''.obs;
  final otaCurrentPacket = 0.obs;
  final otaTotalPackets = 0.obs;

  // Dialog state
  final isOtaProgressDialogOpen = false.obs;
  final isTimerDialogOpen = false.obs;
  final secondsRemaining = 60.obs; // 1 minute timer
  final shouldShowDoneDialog =
      false.obs; // Flag to trigger done dialog on reconnection
  final isDoneDialogShowing = false.obs; // Prevent duplicate done dialogs
  final hasWaitDialogShown = false.obs; // Prevent duplicate wait dialogs
  Timer? _installTimer;

  // Connection state tracking for reconnection detection
  StreamSubscription? _connectionSubscription;
  int _previousConnectionState = BleConnectionState.disconnected;
  bool _wasOtaCompleted = false;
  bool _disconnectedDuringTimer =
      false; // Track if device disconnected during timer period

  // Getter/setter for wasOtaCompleted (needed for dialog access)
  bool get wasOtaCompleted => _wasOtaCompleted;
  set wasOtaCompleted(bool value) => _wasOtaCompleted = value;
  bool get isInstallTimerActive => _installTimer?.isActive ?? false;

  StreamSubscription<Map<String, dynamic>>? _otaProgressSubscription;
  Timer? _progressPollingTimer;

  @override
  void onInit() {
    super.onInit();
    _listenToOtaProgress();
    _listenToConnectionState();
  }

  @override
  void onClose() {
    _otaProgressSubscription?.cancel();
    _progressPollingTimer?.cancel();
    _connectionSubscription?.cancel();
    _installTimer?.cancel();
    super.onClose();
  }

  /// Listen to connection state changes to detect reconnection after OTA
  void _listenToConnectionState() {
    _connectionSubscription?.cancel();
    _connectionSubscription = BleScanService.connectionStream.listen((event) {
      final newState = event['state'] as int;

      print(
        'Connection state changed: previous=$_previousConnectionState, new=$newState, wasOtaCompleted=$_wasOtaCompleted, timerActive=$isInstallTimerActive, secondsRemaining=${secondsRemaining.value}, disconnectedDuringTimer=$_disconnectedDuringTimer',
      );

      // Track disconnection during timer period (after OTA completion)
      if (_wasOtaCompleted &&
          (isInstallTimerActive || secondsRemaining.value > 0) &&
          _previousConnectionState == BleConnectionState.connected &&
          newState == BleConnectionState.disconnected) {
        print('Device disconnected during timer period');
        _disconnectedDuringTimer = true;
      }

      // Detect reconnection after OTA completion
      // Check if OTA was completed and timer is still running (either active or seconds remaining)
      // Also check if device was disconnected during timer period
      if (_wasOtaCompleted &&
          newState == BleConnectionState.connected &&
          (_disconnectedDuringTimer ||
              _previousConnectionState == BleConnectionState.disconnected) &&
          (isInstallTimerActive ||
              isTimerDialogOpen.value ||
              secondsRemaining.value > 0)) {
        print(
          '🟢 [OTA Controller] Device reconnected after OTA - cancelling timer and showing done dialog',
        );
        print(
          '🟢 [OTA Controller] isTimerDialogOpen: ${isTimerDialogOpen.value}, secondsRemaining: ${secondsRemaining.value}',
        );

        // Cancel timer and trigger done dialog
        _installTimer?.cancel();
        _installTimer = null;
        secondsRemaining.value = 0;
        isTimerDialogOpen.value = false;
        _disconnectedDuringTimer = false; // Reset flag
        shouldShowDoneDialog.value = true; // Trigger done dialog to show
        shouldShowDoneDialog.refresh();
        print(
          '🟢 [OTA Controller] Timer cancelled, shouldShowDoneDialog=${shouldShowDoneDialog.value}',
        );
      }

      _previousConnectionState = newState;
    });
  }

  /// Public method to close wait dialog when device reconnects
  void handleDeviceReconnected() {
    if (isTimerDialogOpen.value && _wasOtaCompleted) {
      print('Handling device reconnection - closing wait dialog');
      _closeWaitDialogAndShowDone();
      // Trigger a rebuild to show done dialog
      isTimerDialogOpen.refresh();
    }
  }

  /// Start the install timer and show wait dialog
  /// Made public so dialog can start it when showing (in case device disconnects before acknowledgment)
  void startInstallTimer() async {
    print('🟡 [OTA Controller] startInstallTimer called');

    // Prevent starting timer multiple times
    if (_wasOtaCompleted && isInstallTimerActive) {
      print('🟡 [OTA Controller] Timer already active - skipping');
      return;
    }

    _installTimer?.cancel();
    secondsRemaining.value = 60; // 1 minute
    isTimerDialogOpen.value = true;
    _wasOtaCompleted = true;

    // Check current connection state - if already disconnected, mark it
    final currentConnectionState = await BleScanService.getConnectionState();
    _disconnectedDuringTimer =
        (currentConnectionState == BleConnectionState.disconnected);
    _previousConnectionState = currentConnectionState;

    print(
      '🟡 [OTA Controller] Starting install timer: currentConnectionState=$currentConnectionState, disconnectedDuringTimer=$_disconnectedDuringTimer, isTimerDialogOpen=${isTimerDialogOpen.value}',
    );

    _installTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 0) {
        secondsRemaining.value--;
      } else {
        timer.cancel();
        print(
          '🟢 [OTA Controller] Timer completed - secondsRemaining reached 0, isTimerDialogOpen: ${isTimerDialogOpen.value}',
        );
        // Timer completed - show done dialog if wait dialog is still open
        if (isTimerDialogOpen.value) {
          print(
            '🟢 [OTA Controller] Timer dialog is open - closing and showing done dialog',
          );
          _closeWaitDialogAndShowDone();
        } else {
          print(
            '🟡 [OTA Controller] Timer dialog is NOT open - setting shouldShowDoneDialog flag',
          );
          shouldShowDoneDialog.value = true;
          shouldShowDoneDialog.refresh();
        }
      }
    });
  }

  /// Close wait dialog and show done dialog
  void _closeWaitDialogAndShowDone() {
    print('🟢 [OTA Controller] _closeWaitDialogAndShowDone called');
    _installTimer?.cancel();
    _installTimer = null;
    isTimerDialogOpen.value = false;
    secondsRemaining.value = 0; // Set to 0 to indicate completion
    shouldShowDoneDialog.value = true; // Trigger done dialog to show
    shouldShowDoneDialog.refresh();
    print(
      '🟢 [OTA Controller] Wait dialog closed, shouldShowDoneDialog=${shouldShowDoneDialog.value}',
    );
  }

  /// Start periodic progress polling as backup (in case stream has issues)
  void _startProgressPolling() {
    _progressPollingTimer?.cancel();
    _progressPollingTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      // Continue polling even if isOtaInProgress is false, to check for 100% completion
      // This ensures we catch 100% progress even if the stream didn't send it
      final shouldContinuePolling = isOtaInProgress.value || !_wasOtaCompleted;

      try {
        final progress = await BleScanService.getOtaProgress();
        final inProgress = await BleScanService.isOtaUpdateInProgress();

        // Check if progress reached 100% and start timer if not already started
        // This handles the case where progress stream doesn't send the 100% event
        // Check this even if inProgress is false (device may disconnect before acknowledgment)
        if (progress == 100 && (!_wasOtaCompleted || !isInstallTimerActive)) {
          print(
            '🟢 [OTA Controller] Progress polling detected 100% - starting install timer',
          );
          print(
            '🟢 [OTA Controller] wasOtaCompleted: $_wasOtaCompleted, isInstallTimerActive: $isInstallTimerActive, inProgress: $inProgress',
          );
          startInstallTimer();
        }

        if (progress != (otaProgress.value * 100).round()) {
          print(
            'Progress polling: Updating from ${otaProgress.value * 100}% to $progress%',
          );
          otaProgress.value = progress / 100.0;
          otaProgress.refresh();
        }

        if (inProgress != isOtaInProgress.value) {
          print(
            'Progress polling: Updating inProgress from ${isOtaInProgress.value} to $inProgress',
          );
          isOtaInProgress.value = inProgress;
          isOtaInProgress.refresh();
        }

        // Stop polling when OTA completes (inProgress becomes false) AND timer has started
        if (!isOtaInProgress.value && _wasOtaCompleted) {
          timer.cancel();
          return;
        }
      } catch (e) {
        print('Error polling progress: $e');
        // Stop polling on error if OTA is not in progress and timer started
        if (!isOtaInProgress.value && _wasOtaCompleted) {
          timer.cancel();
        }
      }
    });
  }

  /// Listen to OTA progress updates from Kotlin service
  void _listenToOtaProgress() {
    _otaProgressSubscription?.cancel();
    _otaProgressSubscription = BleScanService.otaProgressStream.listen(
      (event) {
        print('OTA Progress Event: $event');
        final progress = event['progress'] as int? ?? 0;
        final inProgress = event['inProgress'] as bool? ?? false;
        final message = event['message'] as String? ?? '';

        print(
          'OTA Progress: $progress%, InProgress: $inProgress, Message: $message',
        );

        // Update progress (ensure it's between 0 and 1)
        final progressValue = (progress.clamp(0, 100) / 100.0);
        otaProgress.value = progressValue;
        isOtaInProgress.value = inProgress;
        otaMessage.value = message;

        // Extract packet numbers from message if available
        final packetMatch = RegExp(r'(\d+)/(\d+)').firstMatch(message);
        if (packetMatch != null) {
          otaCurrentPacket.value =
              int.tryParse(packetMatch.group(1) ?? '0') ?? 0;
          otaTotalPackets.value =
              int.tryParse(packetMatch.group(2) ?? '0') ?? 0;
        }

        print(
          'Updated UI - Progress: $progressValue (${progress}%), InProgress: $inProgress, Message: $message',
        );

        // Force UI refresh
        otaProgress.refresh();
        isOtaInProgress.refresh();
        otaMessage.refresh();

        // Stop polling when OTA completes
        if (!inProgress) {
          _progressPollingTimer?.cancel();
        }

        if (progress == 100) {
          // OTA completed successfully (all packets sent)
          print(
            '🟢 [OTA Controller] OTA completed successfully - progress reached 100%',
          );
          print(
            '🟢 [OTA Controller] inProgress: $inProgress, isOtaProgressDialogOpen: ${isOtaProgressDialogOpen.value}',
          );

          // When progress reaches 100%, always start the timer if not already started
          // This ensures timer runs even if progress dialog was dismissed
          if (!_wasOtaCompleted || !isInstallTimerActive) {
            print(
              '🟢 [OTA Controller] Starting install timer (progress reached 100%)',
            );
            startInstallTimer();
          } else {
            print('🟡 [OTA Controller] Timer already started - skipping');
          }
        } else if (!inProgress &&
            message.isNotEmpty &&
            (message.toLowerCase().contains('fail') ||
                message.toLowerCase().contains('error'))) {
          // OTA failed - close dialogs and reset state
          print('OTA failed: $message');
          _handleOtaFailure(message);
        }
      },
      onError: (error) {
        print('OTA progress stream error: $error');
        isOtaInProgress.value = false;
      },
      cancelOnError: false,
    );
  }

  /// Download firmware files from Firebase Storage
  Future<void> downloadFolder(String folderName) async {
    try {
      isDownloadingFirmware.value = true;
      downloadProgress.value = 0.0;

      // Clear cache first
      await clearCache();
      print("Start of download folder");

      firebase_storage.FirebaseStorage storage =
          firebase_storage.FirebaseStorage.instance;
      print("After storage initialization");

      firebase_storage.ListResult result = await storage
          .ref(folderName)
          .listAll();
      print("After storage found");

      List<Future<void>> downloadTasks = [];
      String tempDirPath = (await getTemporaryDirectory()).path;

      print("Results length is ${result.items.length}");

      if (result.items.isEmpty) {
        AppSnackbars.showSuccess(
          title: 'No Firmware Found',
          message: 'No firmware files found in the specified folder.',
        );
        isDownloadingFirmware.value = false;
        return;
      }

      int completedDownloads = 0;
      int totalFiles = result.items.length;

      for (var ref in result.items) {
        String fileName = ref.name;
        fileName = fileName.replaceAll('.img', '');

        binFileFromFirebaseName.value = fileName;

        print("File name just received is $fileName");
        File file = File('$tempDirPath/$fileName');

        downloadTasks.add(
          ref.writeToFile(file).then((_) {
            completedDownloads++;
            downloadProgress.value = completedDownloads / totalFiles;
            print("Downloaded $fileName ($completedDownloads/$totalFiles)");
          }),
        );
      }

      await Future.wait(downloadTasks);

      // Set the first downloaded file as the bin file path
      if (result.items.isNotEmpty) {
        String firstFileName = result.items.first.name.replaceAll('.img', '');
        cloudBinFilePath.value = '$tempDirPath/$firstFileName';
        print("Cloud bin file path set to: ${cloudBinFilePath.value}");
      }

      checkDownloadedFiles();
      print("End of download folder");

      AppSnackbars.showSuccess(
        title: 'Download Complete',
        message: 'Firmware downloaded successfully.',
      );
    } catch (e) {
      print("Error in downloadFolder: $e");
      AppSnackbars.showSuccess(
        title: 'Download Failed',
        message: 'Failed to download firmware: $e',
      );
    } finally {
      isDownloadingFirmware.value = false;
    }
  }

  /// Clear cache directory
  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      if (await dir.exists()) {
        await for (var entity in dir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }

  /// Check downloaded files
  void checkDownloadedFiles() {
    // Implementation to verify downloaded files if needed
    print("Checking downloaded files...");
  }

  /// Start OTA update process
  Future<void> startOtaUpdate(String? binFilePath) async {
    print(
      '🔵 [OTA Controller] startOtaUpdate called - isOtaInProgress: ${isOtaInProgress.value}, isOtaProgressDialogOpen: ${isOtaProgressDialogOpen.value}',
    );

    if (isOtaInProgress.value) {
      print(
        '🟡 [OTA Controller] OTA already in progress - showing existing progress dialog',
      );
      AppSnackbars.showSuccess(
        title: 'Update In Progress',
        message: 'OTA update is already in progress.',
      );
      return;
    }

    // Check if device is connected
    final connectionState = await BleScanService.getConnectionState();
    if (connectionState != BleConnectionState.connected) {
      AppSnackbars.showSuccess(
        title: 'Not Connected',
        message: 'Please connect to Leo device first.',
      );
      return;
    }

    try {
      // Enable wake lock
      await WakelockPlus.enable();
      print("Wake lock enabled");

      final filePath = binFilePath ?? cloudBinFilePath.value;
      if (filePath.isEmpty) {
        throw Exception('No firmware file path provided');
      }

      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Firmware file does not exist: $filePath');
      }

      // Validate firmware versions before proceeding
      final homeController = Get.find<LeoHomeController>();
      final currentVersion = homeController.binFileFromLeoName.value;
      final targetVersion = binFileFromFirebaseName.value;

      print("Current device firmware: $currentVersion");
      print("Target firmware: $targetVersion");

      if (currentVersion.isNotEmpty && targetVersion.isNotEmpty) {
        // Simple version comparison - check if target is different from current
        if (currentVersion == targetVersion) {
          throw Exception(
            'Device is already running firmware version $currentVersion. No update needed.',
          );
        }

        // Additional validation could be added here for version comparison logic
        print(
          "Proceeding with firmware update: $currentVersion -> $targetVersion",
        );
      } else {
        print(
          "Warning: Could not validate firmware versions (current: '$currentVersion', target: '$targetVersion')",
        );
      }

      // Send initial progress
      otaProgress.value = 0.0;
      isOtaInProgress.value = true;
      otaCurrentPacket.value = 0;
      otaTotalPackets.value = 0;
      otaMessage.value = 'Starting OTA update...';

      // Force UI refresh
      otaProgress.refresh();
      isOtaInProgress.refresh();
      otaMessage.refresh();

      // Start OTA update via platform-specific service
      print("Starting OTA update with file: $filePath");
      final success = await BleScanService.startOtaUpdate(filePath);

      if (!success) {
        isOtaInProgress.value = false;
        otaProgress.value = 0.0;
        otaMessage.value = 'Failed to start OTA update';
        isOtaInProgress.refresh();
        otaProgress.refresh();
        // Error message will be sent via progress stream
        throw Exception(
          'Failed to start OTA update. Check error message for details.',
        );
      }

      print("OTA update started successfully");

      // Start periodic progress check as backup
      _startProgressPolling();
    } catch (e) {
      print("Error in startOtaUpdate: $e");
      await WakelockPlus.disable();
      AppSnackbars.showSuccess(
        title: 'Update Failed',
        message: 'Failed to start firmware update: $e',
      );
    }
  }

  /// Cancel OTA update
  Future<void> cancelOtaUpdate() async {
    try {
      print("Cancelling OTA update...");

      // Stop progress polling
      _progressPollingTimer?.cancel();

      await BleScanService.cancelOtaUpdate();
      await WakelockPlus.disable();

      // Reset all OTA state
      resetOtaState();

      print("OTA update cancelled - UI state updated");
    } catch (e) {
      print("Error cancelling OTA update: $e");
      // Still update UI state even if cancel fails
      _progressPollingTimer?.cancel();
      resetOtaState();
    }
  }

  /// Handle OTA failure - close dialogs and reset state
  void _handleOtaFailure(String message) {
    print('Handling OTA failure: $message');
    AppSnackbars.showSuccess(
      title: 'Update Failed',
      message: 'Failed to update firmware: $message',
    );

    // Stop progress polling
    _progressPollingTimer?.cancel();

    // Stop install timer if running
    _installTimer?.cancel();

    // Close all OTA-related dialogs
    isOtaProgressDialogOpen.value = false;
    isTimerDialogOpen.value = false;

    // Disable wake lock
    WakelockPlus.disable();

    // Reset state after a short delay to allow UI to update
    Future.delayed(const Duration(milliseconds: 500), () {
      resetOtaState();
    });
  }

  /// Reset all OTA state to initial values
  void resetOtaState() {
    print('🔄 [OTA Controller] resetOtaState called');
    isOtaInProgress.value = false;
    otaProgress.value = 0.0;
    otaMessage.value = '';
    otaCurrentPacket.value = 0;
    otaTotalPackets.value = 0;
    isOtaProgressDialogOpen.value = false;
    isTimerDialogOpen.value = false;
    secondsRemaining.value = 60;
    shouldShowDoneDialog.value = false;
    isDoneDialogShowing.value = false;
    hasWaitDialogShown.value = false;
    _wasOtaCompleted = false;
    _disconnectedDuringTimer = false;
    _installTimer?.cancel();
    _installTimer = null;
    _previousConnectionState = BleConnectionState.disconnected;

    // Force UI refresh
    isOtaInProgress.refresh();
    otaProgress.refresh();
    otaMessage.refresh();
    isOtaProgressDialogOpen.refresh();
    isTimerDialogOpen.refresh();
    shouldShowDoneDialog.refresh();

    print("🔄 [OTA Controller] OTA state reset complete");
  }
}
