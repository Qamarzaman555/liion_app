import 'package:get/get.dart';
import '../controllers/silent_mode_controller.dart';

class SilentModeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SilentModeController>(() => SilentModeController());
  }
}



