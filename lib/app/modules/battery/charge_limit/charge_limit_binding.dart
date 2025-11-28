import 'package:get/get.dart';
import 'controllers/charge_limit_controller.dart';

class ChargeLimitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ChargeLimitController>(() => ChargeLimitController());
  }
}

