import 'package:get/get.dart';
import '../controllers/advanced_settings_controller.dart';
import '../../led_timeout/controllers/led_timeout_controller.dart';

class AdvancedSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdvancedSettingsController>(() => AdvancedSettingsController());
    Get.lazyPut<LedTimeoutController>(() => LedTimeoutController());
  }
}
