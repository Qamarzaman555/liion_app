import 'package:get/get.dart';
import '../controllers/led_timeout_controller.dart';

class LedTimeoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LedTimeoutController>(() => LedTimeoutController());
  }
}



