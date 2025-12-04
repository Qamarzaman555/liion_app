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
  }

  @override
  void dispose() {
    super.dispose();
    controller.isTimerDialogOpen.value = false;
  }

  @override
  Widget build(BuildContext context) {
    controller.isTimerDialogOpen.value = true;

    // Listen for timer completion or reconnection
    return Obx(() {
      // If timer completed (secondsRemaining == 0) or dialog was closed (reconnection), show done dialog
      if (!_hasShownDoneDialog &&
          (controller.secondsRemaining.value == 0 ||
              !controller.isTimerDialogOpen.value)) {
        _hasShownDoneDialog = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const OTAUpdateDone(),
            );
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
