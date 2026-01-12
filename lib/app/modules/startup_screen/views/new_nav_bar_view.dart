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
          body: IndexedStack(
            index: controller.currentIndex.value,
            children: [_buildLeoTab(), _buildHomeTab()],
          ),
          bottomNavigationBar: AnimatedBottomNavBar(),
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

// Placeholder Screens (You'll replace these with your actual screens)
class LeoHomeScreen extends StatelessWidget {
  const LeoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Leo Home Screen'),
          ElevatedButton(
            onPressed: () {
              // Example: Navigate to a different screen within the Leo tab
              // Navigator.of(context).pushNamed('/scan');
              Get.toNamed(
                '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.scan}',
                id: 1,
              );
            },
            child: const Text('Go to Scan Screen (Leo Tab)'),
          ),
        ],
      ),
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

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Screen'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Get.back(id: 1); // Use id: 1 for Leo tab navigator
          },
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Scan Screen'),
          ElevatedButton(
            onPressed: () {
              Get.toNamed(
                '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceList}',
                id: 1,
              );
            },
            child: Text('Go to Device List Screen'),
          ),
        ],
      ),
    );
  }
}

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device List Screen'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Get.back(id: 1); // Use id: 1 for Leo tab navigator
          },
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Device List Screen'),
          ElevatedButton(
            onPressed: () {
              Get.toNamed(
                '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceDetail}',
                id: 1,
              );
            },
            child: Text('Go to Device Detail Screen'),
          ),
        ],
      ),
    );
  }
}

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Detail Screen'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Get.back(id: 1); // Use id: 1 for Leo tab navigator
          },
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Text('Device Detail Screen')],
      ),
    );
  }
}

class PhoneDetailScreen extends StatelessWidget {
  const PhoneDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Phone Detail Screen'));
  }
}
