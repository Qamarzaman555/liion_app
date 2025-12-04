import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:file_picker/file_picker.dart';

import '../../controllers/leo_home_controller.dart';
import '../../controllers/leo_ota_controller.dart';

class LeoFirmwareUpdateDialog extends StatefulWidget {
  const LeoFirmwareUpdateDialog({super.key});

  @override
  State<LeoFirmwareUpdateDialog> createState() =>
      _LeoFirmwareUpdateDialogState();
}

class _LeoFirmwareUpdateDialogState extends State<LeoFirmwareUpdateDialog> {
  late LeoOtaController otaController;
  late LeoHomeController homeController;
  String? selectedFilePath;

  @override
  void initState() {
    super.initState();
    otaController = Get.put(LeoOtaController());
    homeController = Get.find<LeoHomeController>();
  }

  @override
  void dispose() {
    // Don't dispose the controller here as it's managed by GetX
    super.dispose();
  }

  Future<void> _checkConnectionAndStartUpdate() async {
    // Start OTA update (connection check is done inside controller)
    await otaController.startOtaUpdate(selectedFilePath);
  }

  Future<void> _downloadFromCloud() async {
    // Show folder name input dialog
    final TextEditingController folderController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Firmware'),
        content: TextField(
          controller: folderController,
          decoration: const InputDecoration(
            labelText: 'Firebase Storage Folder Name',
            hintText: 'e.g., firmware/leo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (folderController.text.isNotEmpty) {
                Navigator.pop(context, folderController.text);
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await otaController.downloadFolder(result);
      if (otaController.cloudBinFilePath.value.isNotEmpty) {
        selectedFilePath = otaController.cloudBinFilePath.value;
        await _checkConnectionAndStartUpdate();
      }
    }
  }

  Future<void> _pickFileFromDevice() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );

    if (result != null && result.files.single.path != null) {
      selectedFilePath = result.files.single.path!;
      await _checkConnectionAndStartUpdate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: screenWidth * 0.9,
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Obx(() {
            final isOtaInProgress = otaController.isOtaInProgress.value;
            final isDownloading = otaController.isDownloadingFirmware.value;
            final progress = otaController.otaProgress.value;
            final downloadProgress = otaController.downloadProgress.value;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isDownloading
                      ? 'Downloading Firmware'
                      : isOtaInProgress
                      ? 'OTA Update Progress'
                      : 'Firmware Update',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (isDownloading || isOtaInProgress)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: isDownloading ? downloadProgress : progress,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isDownloading
                            ? '${(downloadProgress * 100).toStringAsFixed(0)}%'
                            : '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isOtaInProgress &&
                          otaController.otaMessage.value.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            otaController.otaMessage.value,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  otaController.otaMessage.value
                                          .toLowerCase()
                                          .contains('error') ||
                                      otaController.otaMessage.value
                                          .toLowerCase()
                                          .contains('fail')
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (!isOtaInProgress &&
                          otaController.otaMessage.value.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            otaController.otaMessage.value,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  )
                else
                  Column(
                    children: [
                      CustomButton(
                        text: 'Download from Cloud',
                        backgroundColor: AppColors.primaryColor,
                        textColor: AppColors.whiteColor,
                        onPressed: _downloadFromCloud,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_download, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Download from Cloud',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Select from Device',
                        backgroundColor: AppColors.primaryInvertColor,
                        textColor: AppColors.whiteColor,
                        onPressed: _pickFileFromDevice,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Select from Device',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.whiteColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                if (isOtaInProgress || isDownloading)
                  CustomButton(
                    text: 'Cancel',
                    textColor: AppColors.blackColor,
                    borderColor: AppColors.blackColor,
                    backgroundColor: AppColors.transparentColor,
                    onPressed: () async {
                      await otaController.cancelOtaUpdate();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackColor,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  CustomButton(
                    text: 'Close',
                    textColor: AppColors.blackColor,
                    borderColor: AppColors.blackColor,
                    backgroundColor: AppColors.transparentColor,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Close',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blackColor,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
