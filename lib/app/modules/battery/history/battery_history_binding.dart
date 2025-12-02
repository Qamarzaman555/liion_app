import 'package:get/get.dart';
import 'package:liion_app/app/modules/battery/history/controllers/battery_history_controller.dart';

class BatteryHistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BatteryHistoryController>(
      () => BatteryHistoryController(),
    );
  }
}
