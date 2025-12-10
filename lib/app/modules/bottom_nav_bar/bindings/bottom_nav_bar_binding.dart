import 'package:get/get.dart';
import 'package:liion_app/app/modules/led_timeout/controllers/led_timeout_controller.dart';
import '../controllers/bottom_nav_bar_controller.dart';
import '../../leo_empty/controllers/leo_home_controller.dart';
import '../../battery/controllers/battery_controller.dart';
import '../../settings/controllers/settings_controller.dart';
import '../../battery/charge_limit/controllers/charge_limit_controller.dart';

class BottomNavBarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BottomNavBarController>(() => BottomNavBarController());
    Get.lazyPut<LedTimeoutController>(() => LedTimeoutController());
    Get.lazyPut<LeoHomeController>(() => LeoHomeController());
    Get.lazyPut<BatteryController>(() => BatteryController());
    Get.lazyPut<SettingsController>(() => SettingsController());
    Get.lazyPut<ChargeLimitController>(() => ChargeLimitController());
  }
}
