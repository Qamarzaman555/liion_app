import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/battery_controller.dart';

class BatteryView extends GetView<BatteryController> {
  const BatteryView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Battery View')));
  }
}

