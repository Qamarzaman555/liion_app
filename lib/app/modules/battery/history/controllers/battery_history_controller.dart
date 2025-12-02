import 'package:get/get.dart';
import 'package:liion_app/app/modules/battery/models/battery_session.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class BatteryHistoryController extends GetxController {
  final sessions = <BatterySession>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSessions();
  }

  Future<void> loadSessions() async {
    isLoading.value = true;
    try {
      final sessionMaps = await BleScanService.getBatterySessionHistory();
      sessions.value = sessionMaps
          .map((map) => BatterySession.fromMap(map))
          .toList();
    } catch (e) {
      print('Error loading battery sessions: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshLoadSessions() async {
    await loadSessions();
  }
}
