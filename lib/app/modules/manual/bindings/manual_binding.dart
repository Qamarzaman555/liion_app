import 'package:get/get.dart';
import '../controllers/manual_controller.dart';

class ManualBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ManualController>(() => ManualController());
  }
}


