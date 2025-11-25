import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/leo_home_controller.dart';

class LeoHomeView extends GetView<LeoHomeController> {
  const LeoHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Leo Empty View')));
  }
}
