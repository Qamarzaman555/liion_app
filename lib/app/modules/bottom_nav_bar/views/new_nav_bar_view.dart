import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/widgets/animated_bottom_navbar.dart';
import 'package:liion_app/app/routes/app_pages.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/modules/startup_screen/controllers/new_nav_bar_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class NewNavBarView extends GetView<NewNavBarController> {
  NewNavBarView({super.key});

  // GlobalKeys for each nested navigator to maintain their state
  final GlobalKey<NavigatorState> _leoTabNavigatorKey = Get.nestedKey(1)!;
  final GlobalKey<NavigatorState> _homeTabNavigatorKey = Get.nestedKey(2)!;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => WillPopScope(
        onWillPop: () async {
          // Get the current navigator based on the active tab
          final currentNavigator = controller.currentIndex.value == 0
              ? _leoTabNavigatorKey.currentState
              : _homeTabNavigatorKey.currentState;

          // Check if the navigator can pop (has more than one route in the stack)
          if (currentNavigator != null && currentNavigator.canPop()) {
            // Pop from the current tab's navigator
            currentNavigator.pop();
            return false; // Prevent default back button behavior
          } else {
            // At the root of the current tab, minimize the app
            await BleScanService.minimizeApp();
            return false; // Prevent default back button behavior
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              // Main content
              IndexedStack(
                index: controller.currentIndex.value,
                children: [_buildLeoTab(), _buildHomeTab()],
              ),
              // Bottom navbar overlaid on top
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(top: false, child: AnimatedBottomNavBar()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeoTab() {
    return Navigator(
      key: _leoTabNavigatorKey,
      onGenerateRoute: (settings) =>
          AppPages.onGenerateNestedRoute(1, settings),
    );
  }

  Widget _buildHomeTab() {
    return Navigator(
      key: _homeTabNavigatorKey,
      onGenerateRoute: (settings) =>
          AppPages.onGenerateNestedRoute(2, settings),
    );
  }
}

class HomePhoneDetailScreen extends StatelessWidget {
  const HomePhoneDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Home Phone Detail Screen'));
  }
}

class PhoneDetailScreen extends StatelessWidget {
  const PhoneDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Phone Detail Screen'));
  }
}
