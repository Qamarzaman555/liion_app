import 'package:get/get.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';

class AdvancedSettingsController extends GetxController {
  final ghostModeEnabled = false.obs;
  final silentModeEnabled = false.obs;
  final higherChargeLimitEnabled = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Get.put(LEDTimeoutController());

    ghostModeEnabled.value =
        Get.find<LeoHomeController>().advancedGhostModeEnabled.value;
    silentModeEnabled.value =
        Get.find<LeoHomeController>().advancedSilentModeEnabled.value;
    higherChargeLimitEnabled.value =
        Get.find<LeoHomeController>().advancedHigherChargeLimitEnabled.value;
  }
}
