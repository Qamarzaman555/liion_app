import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/leo_empty_controller.dart';

class LeoEmptyView extends GetView<LeoEmptyController> {
  const LeoEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Leo Empty View')));
  }
}
