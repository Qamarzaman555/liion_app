import 'package:get/get.dart';
import '../controllers/ghost_mode_beta_controller.dart';

class GhostModeBetaBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GhostModeBetaController>(() => GhostModeBetaController());
  }
}



