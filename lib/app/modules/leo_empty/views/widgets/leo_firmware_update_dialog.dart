import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import '../../controllers/leo_home_controller.dart';
import '../../controllers/leo_ota_controller.dart';
import 'wait_for_install_dialog.dart';

class LeoFirmwareUpdateDialog extends StatefulWidget {
  const LeoFirmwareUpdateDialog({super.key, this.autoDownloadFromCloud = true});

  /// When true, dialog auto-downloads firmware from the cloud on open.
  final bool autoDownloadFromCloud;

  @override
  State<LeoFirmwareUpdateDialog> createState() =>
      _LeoFirmwareUpdateDialogState();
}

class _LeoFirmwareUpdateDialogState extends State<LeoFirmwareUpdateDialog> {
  late LeoOtaController otaController;
  late LeoHomeController homeController;
  String? selectedFilePath;
  bool _hasShownWaitDialog = false;
  bool _autoStartedDownload = false;

  @override
  void initState() {
    super.initState();
    otaController = Get.put(LeoOtaController());
    homeController = Get.find<LeoHomeController>();

    // Only reset wait dialog flag if OTA is not in progress
    // This allows reopening the dialog to show current progress
    if (!otaController.isOtaInProgress.value &&
        !otaController.isDownloadingFirmware.value) {
      _hasShownWaitDialog = false;
    }

    // Mark OTA progress dialog as open
    otaController.isOtaProgressDialogOpen.value = true;

    // Auto-start cloud download when dialog opens and nothing is running.
    // If the post-OTA install timer is active, redirect to the wait dialog instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check if timer is active, dialog is open, or timer was completed but still counting down
      if (otaController.isInstallTimerActive ||
          otaController.isTimerDialogOpen.value ||
          (otaController.wasOtaCompleted &&
              otaController.secondsRemaining.value > 0)) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => const WaitForInstallDialogBox(),
        );
        return;
      }

      if (!widget.autoDownloadFromCloud) return;
      if (_autoStartedDownload) return;
      if (otaController.isOtaInProgress.value ||
          otaController.isDownloadingFirmware.value) {
        return;
      }
      _autoStartedDownload = true;
      _downloadFromCloud();
    });
  }

  @override
  void dispose() {
    // Only mark dialog as closed, don't reset state if OTA is still in progress
    // This allows reopening the dialog to show current progress
    otaController.isOtaProgressDialogOpen.value = false;

    // Only reset OTA state when dialog closes AND OTA is not in progress
    // This ensures state is cleaned up after completion/cancellation
    if (!otaController.isOtaInProgress.value &&
        !otaController.isDownloadingFirmware.value &&
        otaController.otaProgress.value == 0.0) {
      otaController.resetOtaState();
    }

    // Don't dispose the controller here as it's managed by GetX
    super.dispose();
  }

  Future<void> _checkConnectionAndStartUpdate() async {
    // Start OTA update (connection check is done inside controller)
    await otaController.startOtaUpdate(selectedFilePath);
  }

  Future<void> _downloadFromCloud() async {
    // Automatically download from "Bin file" folder
    const folderName = 'Bin file';
    await otaController.downloadFolder(folderName);
    if (otaController.cloudBinFilePath.value.isNotEmpty) {
      selectedFilePath = otaController.cloudBinFilePath.value;
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

            // When OTA reaches 100% and is complete, show wait for install dialog
            // Note: We check progress >= 1.0 even if isOtaInProgress is still true
            // because device may disconnect before acknowledgment
            if (progress >= 1.0 &&
                otaController.isOtaProgressDialogOpen.value &&
                !_hasShownWaitDialog) {
              _hasShownWaitDialog = true;
              // Start the install timer immediately when showing wait dialog
              // This handles the case where device disconnects before acknowledgment
              otaController.startInstallTimer();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) => const WaitForInstallDialogBox(),
                  );
                }
              });
            }

            // Check if OTA was cancelled or failed
            final message = otaController.otaMessage.value.toLowerCase();
            final isCancelled =
                message.contains('cancel') &&
                !isOtaInProgress &&
                !isDownloading;
            final isError =
                (message.contains('fail') || message.contains('error')) &&
                !isOtaInProgress &&
                !isDownloading;
            final shouldShowProgress =
                (isDownloading || isOtaInProgress) && !isCancelled && !isError;

            // Auto-close dialog if OTA failed
            if (isError && mounted && Navigator.canPop(context)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                  // Reset state after closing
                  otaController.resetOtaState();
                }
              });
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Update in progress',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                if (shouldShowProgress)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: isDownloading
                            ? downloadProgress.clamp(0.0, 1.0)
                            : progress.clamp(0.0, 1.0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isError ? Colors.red : AppColors.primaryColor,
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isDownloading
                            ? '${(downloadProgress.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%'
                            : '${(progress.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // if (isOtaInProgress &&
                      //     otaController.otaTotalPackets.value > 0)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 4.0),
                      //     child: Text(
                      //       'Packet ${otaController.otaCurrentPacket.value}/${otaController.otaTotalPackets.value}',
                      //       style: TextStyle(
                      //         fontSize: 12,
                      //         color: Colors.grey[600],
                      //       ),
                      //     ),
                      //   ),
                      // if (isOtaInProgress &&
                      //     otaController.otaMessage.value.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8.0),
                      //     child: Text(
                      //       otaController.otaMessage.value,
                      //       style: TextStyle(
                      //         fontSize: 12,
                      //         color:
                      //             otaController.otaMessage.value
                      //                     .toLowerCase()
                      //                     .contains('error') ||
                      //                 otaController.otaMessage.value
                      //                     .toLowerCase()
                      //                     .contains('fail')
                      //             ? Colors.red
                      //             : Colors.grey[600],
                      //       ),
                      //       textAlign: TextAlign.center,
                      //     ),
                      //   ),
                      // if (!isOtaInProgress &&
                      //     otaController.otaMessage.value.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8.0),
                      //     child: Text(
                      //       otaController.otaMessage.value,
                      //       style: const TextStyle(
                      //         fontSize: 12,
                      //         color: Colors.red,
                      //       ),
                      //       textAlign: TextAlign.center,
                      //     ),
                      //   ),
                    ],
                  )
                else if (!isCancelled && !isError)
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Preparing...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: null,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: Colors.grey[300],
                      ),
                    ],
                  )
                else if (isCancelled || isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      otaController.otaMessage.value.isNotEmpty
                          ? otaController.otaMessage.value
                          : isCancelled
                          ? 'Update cancelled'
                          : 'Update failed',
                      style: TextStyle(
                        fontSize: 14,
                        color: isCancelled ? Colors.orange : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                if (shouldShowProgress)
                  CustomButton(
                    text: 'Cancel',
                    textColor: AppColors.blackColor,
                    borderColor: AppColors.blackColor,
                    backgroundColor: AppColors.transparentColor,
                    borderWidth: 2,
                    onPressed: () async {
                      if (isDownloading) {
                        // Can't cancel download, just close
                        if (mounted) {
                          Navigator.pop(context);
                        }
                        return;
                      }

                      // Cancel OTA update
                      await otaController.cancelOtaUpdate();

                      // Wait a bit for state to update
                      await Future.delayed(const Duration(milliseconds: 300));

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
                    text:
                        otaController.otaMessage.value.toLowerCase().contains(
                              'success',
                            ) ||
                            otaController.otaMessage.value
                                .toLowerCase()
                                .contains('completed')
                        ? 'Done'
                        : 'Close',
                    textColor: AppColors.blackColor,
                    borderColor: AppColors.blackColor,
                    backgroundColor: AppColors.transparentColor,
                    onPressed: () {
                      // Reset state when closing dialog
                      if (!otaController.isOtaInProgress.value) {
                        otaController.resetOtaState();
                      }
                      Navigator.pop(context);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          otaController.otaMessage.value.toLowerCase().contains(
                                    'success',
                                  ) ||
                                  otaController.otaMessage.value
                                      .toLowerCase()
                                      .contains('completed')
                              ? 'Done'
                              : 'Close',
                          style: const TextStyle(
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
