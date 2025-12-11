import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';
import 'ota_done_dialog.dart';

class WaitForInstallDialogBox extends StatefulWidget {
  const WaitForInstallDialogBox({super.key});

  @override
  State<WaitForInstallDialogBox> createState() =>
      _WaitForInstallDialogBoxState();
}

class _WaitForInstallDialogBoxState extends State<WaitForInstallDialogBox> {
  late LeoOtaController controller;
  bool _hasShownDoneDialog = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<LeoOtaController>();
    print(
      '🟡 [Wait Dialog] initState - isTimerDialogOpen: ${controller.isTimerDialogOpen.value}, secondsRemaining: ${controller.secondsRemaining.value}',
    );
    print(
      '🟡 [Wait Dialog] initState - wasOtaCompleted: ${controller.wasOtaCompleted}, shouldShowDoneDialog: ${controller.shouldShowDoneDialog.value}',
    );

    // Mark dialog open after first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.hasWaitDialogShown.value = true;
      controller.isTimerDialogOpen.value = true;
      print(
        '🟡 [Wait Dialog] postFrame set isTimerDialogOpen=true, secondsRemaining: ${controller.secondsRemaining.value}',
      );
    });

    // Ensure timer is started if it hasn't been started yet
    if (!controller.isInstallTimerActive && controller.wasOtaCompleted) {
      print(
        '🟡 [Wait Dialog] Timer not active but OTA completed - starting timer',
      );
      controller.startInstallTimer();
    }
  }

  @override
  void dispose() {
    print('🔴 [Wait Dialog] dispose called');
    print(
      '🔴 [Wait Dialog] dispose - secondsRemaining: ${controller.secondsRemaining.value}, shouldShowDoneDialog: ${controller.shouldShowDoneDialog.value}',
    );
    super.dispose();
    controller.isTimerDialogOpen.value = false;
    print('🔴 [Wait Dialog] Marked isTimerDialogOpen = false');
  }

  @override
  Widget build(BuildContext context) {
    // Listen for timer completion, reconnection, or failure
    return Obx(() {
      // Check if OTA failed (shouldn't happen normally, but handle it)
      final message = controller.otaMessage.value.toLowerCase();
      final hasFailed =
          (message.contains('fail') || message.contains('error')) &&
          !controller.isOtaInProgress.value;

      // If OTA failed, close dialog immediately
      if (hasFailed && mounted && Navigator.canPop(context)) {
        print('🔴 [Wait Dialog] OTA failed - closing dialog');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
            controller.resetOtaState();
          }
        });
        return const SizedBox.shrink();
      }

      // If timer completed (secondsRemaining == 0), dialog was closed (reconnection),
      // or shouldShowDoneDialog flag is set (device reconnected), show done dialog
      final shouldShowDone =
          controller.secondsRemaining.value == 0 ||
          controller.shouldShowDoneDialog.value;

      if (shouldShowDone && !_hasShownDoneDialog) {
        print('🟢 [Wait Dialog] shouldShowDone=$shouldShowDone');
        print(
          '🟢 [Wait Dialog] secondsRemaining=${controller.secondsRemaining.value}, shouldShowDoneDialog=${controller.shouldShowDoneDialog.value}',
        );
        print(
          '🟢 [Wait Dialog] isTimerDialogOpen=${controller.isTimerDialogOpen.value}, hasShownDoneDialog=$_hasShownDoneDialog',
        );
      }

      if (!_hasShownDoneDialog && shouldShowDone) {
        _hasShownDoneDialog = true;
        print('🟢 [Wait Dialog] Showing done dialog');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            print(
              '🟢 [Wait Dialog] Closing wait dialog and showing done dialog',
            );
            Navigator.pop(context);
            // Reset the flag before showing done dialog
            controller.shouldShowDoneDialog.value = false;
            controller.isDoneDialogShowing.value = true;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const OTAUpdateDone(),
            ).then((_) {
              controller.isDoneDialogShowing.value = false;
            });
          }
        });
      }

      return AlertDialog(
        title: const Center(
          child: Text('Software Update Complete', textAlign: TextAlign.center),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please do not power off or unplug Leo for 1 minute, until the software firmware update is fully installed. If a red light appears, please restart the update process.',
              style: TextStyle(fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Obx(
              () => Text(
                '${(controller.secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(controller.secondsRemaining % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    });
  }
}
