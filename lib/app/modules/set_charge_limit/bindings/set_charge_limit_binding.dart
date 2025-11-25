import 'package:get/get.dart';
import '../controllers/set_charge_limit_controller.dart';

class SetChargeLimitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SetChargeLimitController>(() => SetChargeLimitController());
  }
}

