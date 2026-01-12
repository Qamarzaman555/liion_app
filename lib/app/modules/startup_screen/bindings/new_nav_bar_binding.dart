import 'package:get/get.dart';
import 'package:liion_app/app/modules/startup_screen/controllers/new_nav_bar_controller.dart';

class NewNavBarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewNavBarController>(
      () => NewNavBarController(),
    );
  }
}
