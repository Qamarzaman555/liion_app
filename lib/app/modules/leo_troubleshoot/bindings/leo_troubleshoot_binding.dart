import 'package:get/get.dart';
import '../controllers/leo_troubleshoot_controller.dart';

class LeoTroubleshootBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LeoTroubleshootController>(() => LeoTroubleshootController());
  }
}

