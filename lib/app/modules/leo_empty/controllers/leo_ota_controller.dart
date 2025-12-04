import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
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

  StreamSubscription<Map<String, dynamic>>? _otaProgressSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToOtaProgress();
  }

  @override
  void onClose() {
    _otaProgressSubscription?.cancel();
    super.onClose();
  }

  /// Listen to OTA progress updates from Kotlin service
  void _listenToOtaProgress() {
    _otaProgressSubscription?.cancel();
    _otaProgressSubscription = BleScanService.otaProgressStream.listen(
      (event) {
        final progress = event['progress'] as int? ?? 0;
        final inProgress = event['inProgress'] as bool? ?? false;
        final message = event['message'] as String? ?? '';

        otaProgress.value = progress / 100.0;
        isOtaInProgress.value = inProgress;
        otaMessage.value = message;

        if (!inProgress && progress == 100) {
          // OTA completed successfully
          AppSnackbars.showSuccess(
            title: 'Update Successful',
            message: 'Firmware update completed successfully.',
          );
        } else if (!inProgress && progress == 0 && message.isNotEmpty) {
          // OTA failed
          AppSnackbars.showSuccess(title: 'Update Failed', message: message);
        }
      },
      onError: (error) {
        print('OTA progress stream error: $error');
      },
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
    if (isOtaInProgress.value) {
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

      // Send initial progress
      otaProgress.value = 0.0;
      isOtaInProgress.value = true;

      // Start OTA update via Kotlin service
      print("Starting OTA update with file: $filePath");
      final success = await BleScanService.startOtaUpdate(filePath);

      if (!success) {
        isOtaInProgress.value = false;
        // Error message will be sent via progress stream
        throw Exception(
          'Failed to start OTA update. Check error message for details.',
        );
      }

      print("OTA update started successfully");
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
      await BleScanService.cancelOtaUpdate();
      await WakelockPlus.disable();
      print("OTA update cancelled");
    } catch (e) {
      print("Error cancelling OTA update: $e");
    }
  }
}
