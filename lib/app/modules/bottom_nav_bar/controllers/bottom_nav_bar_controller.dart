import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../leo_empty/views/leo_empty_view.dart';
import '../../battery/views/battery_view.dart';
import '../../settings/views/settings_view.dart';

class BottomNavBarController extends GetxController {
  final currentIndex = 0.obs;

  final List<Widget> navBarViews = [
    const LeoEmptyView(),
    const BatteryView(),
    const SettingsView(),
  ];

  void changeIndex(int index) {
    currentIndex.value = index;
  }

  Widget get currentView => navBarViews[currentIndex.value];
}
