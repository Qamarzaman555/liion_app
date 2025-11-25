import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/set_charge_limit_controller.dart';

class SetChargeLimitView extends GetView<SetChargeLimitController> {
  const SetChargeLimitView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Set Charge Limit View'),
      ),
    );
  }
}

