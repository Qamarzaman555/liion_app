import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_ota_controller.dart';

class OTAUpdateDone extends StatefulWidget {
  const OTAUpdateDone({super.key});

  @override
  State<OTAUpdateDone> createState() => _OTAUpdateDoneState();
}

class _OTAUpdateDoneState extends State<OTAUpdateDone> {
  late LeoOtaController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<LeoOtaController>();
    // Defer flag update to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.isDoneDialogShowing.value = true;
      controller.wasOtaCompleted = false; // reset completion flag
      print('🟢 [Done Dialog] initState - showing done dialog (post-frame)');
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(
        child: Text('Software Update Complete!', textAlign: TextAlign.center),
      ),
      content: const Text(
        'Software Update is fully completed and installed.',
        style: TextStyle(fontWeight: FontWeight.w400),
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
          onPressed: () {
            print('🟢 [Done Dialog] Okay button pressed - resetting OTA state');
            // Reset OTA state and close dialog
            controller.isDoneDialogShowing.value = false;
            controller.resetOtaState();
            Navigator.pop(context);
          },
          child: const Text('Okay', style: TextStyle(color: Color(0xFF006555))),
        ),
      ],
    );
  }
}
