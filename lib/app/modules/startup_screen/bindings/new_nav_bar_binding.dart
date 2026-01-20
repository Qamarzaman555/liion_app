import 'package:get/get.dart';
import 'package:liion_app/app/modules/startup_screen/controllers/new_nav_bar_controller.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';

class NewNavBarBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NewNavBarController>(
      () => NewNavBarController(),
    );
    Get.lazyPut<LeoHomeController>(
      () => LeoHomeController(),
    );
  }
}
