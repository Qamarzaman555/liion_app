import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

class ManualController extends GetxController {
  static const String MANUAL_FILENAME = 'manual.pdf';

  final fullPathOfPdf = "".obs;
  final isOfflineMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadManual();
  }

  Future<void> loadManual() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      String fullPath = '${appDir.path}/$MANUAL_FILENAME';
      File manualFile = File(fullPath);

      // First check if we have a cached version and use it immediately
      if (await manualFile.exists()) {
        fullPathOfPdf.value = fullPath;
        isOfflineMode.value = true; // Mark as offline until we get fresh copy
      }

      // Always try to download latest version
      await downloadPdf();
    } catch (e) {
      print("Error loading manual: $e");
    }
  }

  Future<void> downloadPdf() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      String fullPath = '${appDir.path}/$MANUAL_FILENAME';
      String tempPath = '${fullPath}_temp'; // Use temp file for download

      // Download to temporary file first
      Dio dio = Dio();
      await dio.download("https://liionpower.nl/manual.pdf", tempPath);

      // If download successful, replace old file with new one
      File tempFile = File(tempPath);
      await tempFile.rename(fullPath);

      print("Manual downloaded and updated successfully");
      fullPathOfPdf.value = fullPath;
      isOfflineMode.value = false; // We have latest version now
    } catch (e) {
      print("Error downloading PDF: $e");
      isOfflineMode.value = true;

      // Clean up temp file if it exists
      try {
        File tempFile = File('${fullPathOfPdf.value}_temp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (cleanupError) {
        print("Error cleaning up temp file: $cleanupError");
      }

      // If we don't have any version of the file yet, throw the error
      if (fullPathOfPdf.value.isEmpty) {
        Directory appDir = await getApplicationDocumentsDirectory();
        String fullPath = '${appDir.path}/$MANUAL_FILENAME';
        if (await File(fullPath).exists()) {
          fullPathOfPdf.value = fullPath;
        } else {
          throw Exception("No cached version available and download failed");
        }
      }
    }
  }
}
