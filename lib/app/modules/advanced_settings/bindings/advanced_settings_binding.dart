import 'package:get/get.dart';
import '../controllers/advanced_settings_controller.dart';

class AdvancedSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdvancedSettingsController>(() => AdvancedSettingsController());
  }
}

