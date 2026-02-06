import 'package:get/get.dart';
import 'package:liion_app/app/modules/battery/controllers/battery_controller.dart';
import 'controllers/charge_limit_controller.dart';

class ChargeLimitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChargeLimitController>(() => ChargeLimitController());
    // Ensure BatteryController is available if not already initialized
    if (!Get.isRegistered<BatteryController>()) {
      Get.lazyPut<BatteryController>(() => BatteryController());
    }
  }
}
