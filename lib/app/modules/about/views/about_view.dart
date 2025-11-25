import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/about_controller.dart';

class AboutView extends GetView<AboutController> {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('About View')));
  }
}
