import 'package:get/get.dart';
import '../controllers/higher_charge_limit_controller.dart';

class HigherChargeLimitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HigherChargeLimitController>(() => HigherChargeLimitController());
  }
}



