import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/ota_done_dialog.dart';
import 'package:liion_app/app/modules/leo_empty/views/widgets/wait_for_install_dialog.dart';
import '../controllers/leo_troubleshoot_controller.dart';

class LeoTroubleshootView extends GetView<LeoTroubleshootController> {
  const LeoTroubleshootView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 26,
                          color: AppColors.blackColor,
                          weight: 8,
                        ),
                        onPressed: () => Get.back(),
                      ),
                      const Text(
                        'Leo Troubleshoot',
                        style: TextStyle(
                          color: Color(0xFF282828),
                          fontFamily: 'Inter',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Obx(
                    () => _buildActionButton(
                      text: 'Leo Reset',
                      icon: Icons.lock_reset_outlined,
                      onPressed: controller.isResetting.value
                          ? () {}
                          : () => controller.resetLeo(),
                      isLoading: controller.isResetting.value,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    text: 'FAQ',
                    icon: Icons.question_answer_outlined,
                    onPressed: () => controller.openFaq(),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => _buildActionButton(
                      text: 'Update From File',
                      icon: Icons.repeat_rounded,
                      onPressed: controller.isUpdating.value
                          ? () {}
                          : () => controller.updateFromFile(),
                      isLoading: controller.isUpdating.value,
                    ),
                  ),
                ],
              ),
            ),
            // Listener for OTA wait/done dialogs
            const _OtaDialogListener(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return CustomButton(
      text: text,
      onPressed: isLoading ? () {} : onPressed,
      isLoading: isLoading,
      borderRadius: 10,
      backgroundColor: AppColors.primaryColor,
      textColor: AppColors.whiteColor,
    );
  }
}

/// Listener widget to mirror the OTA wait/done dialog flow used in LeoHomeView.
class _OtaDialogListener extends StatefulWidget {
  const _OtaDialogListener();

  @override
  State<_OtaDialogListener> createState() => _OtaDialogListenerState();
}

class _OtaDialogListenerState extends State<_OtaDialogListener> {
  bool _hasShownDoneDialog = false;
  bool _hasShownWaitDialog = false;

  @override
  Widget build(BuildContext context) {
    final otaController = Get.put(LeoOtaController());

    return Obx(() {
      // Reset local wait flag if timer is not active
      if (!otaController.isInstallTimerActive &&
          !otaController.wasOtaCompleted) {
        _hasShownWaitDialog = false;
      }

      // Auto-show wait dialog if timer started and progress dialog was dismissed
      if (otaController.isTimerDialogOpen.value &&
          otaController.wasOtaCompleted &&
          otaController.isInstallTimerActive &&
          !otaController.isOtaProgressDialogOpen.value &&
          !_hasShownWaitDialog &&
          !otaController.hasWaitDialogShown.value) {
        _hasShownWaitDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (otaController.isTimerDialogOpen.value &&
              !otaController.isOtaProgressDialogOpen.value &&
              otaController.isInstallTimerActive &&
              !otaController.hasWaitDialogShown.value) {
            otaController.hasWaitDialogShown.value = true;
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (context) => const WaitForInstallDialogBox(),
            ).then((_) {
              _hasShownWaitDialog = false;
              otaController.hasWaitDialogShown.value = false;
            });
          } else {
            _hasShownWaitDialog = false;
          }
        });
      }

      // Show done dialog when flagged and wait dialog is not open
      if (otaController.shouldShowDoneDialog.value &&
          !_hasShownDoneDialog &&
          !otaController.isTimerDialogOpen.value &&
          !otaController.isDoneDialogShowing.value) {
        _hasShownDoneDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          otaController.shouldShowDoneDialog.value = false;
          otaController.isDoneDialogShowing.value = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const OTAUpdateDone(),
          ).then((_) {
            _hasShownDoneDialog = false;
            otaController.isDoneDialogShowing.value = false;
          });
        });
      }

      return const SizedBox.shrink();
    });
  }
}
