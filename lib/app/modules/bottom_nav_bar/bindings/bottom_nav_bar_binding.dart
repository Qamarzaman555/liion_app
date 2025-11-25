import 'package:get/get.dart';
import '../controllers/bottom_nav_bar_controller.dart';
import '../../leo_empty/controllers/leo_empty_controller.dart';
import '../../battery/controllers/battery_controller.dart';
import '../../settings/controllers/settings_controller.dart';

class BottomNavBarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BottomNavBarController>(() => BottomNavBarController());
    Get.lazyPut<LeoEmptyController>(() => LeoEmptyController());
    Get.lazyPut<BatteryController>(() => BatteryController());
    Get.lazyPut<SettingsController>(() => SettingsController());
  }
}
