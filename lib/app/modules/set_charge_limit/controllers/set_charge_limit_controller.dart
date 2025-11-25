import 'package:get/get.dart';

class SetChargeLimitController extends GetxController {
  final chargeLimit = 80.obs;

  void setLimit(int limit) {
    chargeLimit.value = limit;
  }
}

