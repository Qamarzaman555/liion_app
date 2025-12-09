import 'package:get/get.dart';

class LedTimeoutController extends GetxController {
  final timeoutMinutes = 5.obs;
  final isEnabled = false.obs;

  final List<int> timeoutOptions = [1, 3, 5, 10, 15, 30, 60];

  void toggleLedTimeout(bool value) {
    isEnabled.value = value;
    // TODO: Implement actual LED timeout logic
  }

  void updateTimeout(int minutes) {
    timeoutMinutes.value = minutes;
    // TODO: Implement actual timeout update logic
  }
}



