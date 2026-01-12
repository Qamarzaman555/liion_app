import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/modules/startup_screen/views/bluetooth_access_screen.dart';
import 'package:liion_app/app/modules/startup_screen/views/location_access_screen.dart';
import 'package:liion_app/app/modules/startup_screen/views/notification_access_screen.dart';
import 'app_routes.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import 'package:liion_app/app/modules/startup_screen/views/new_nav_bar_view.dart';
import 'package:liion_app/app/modules/startup_screen/bindings/new_nav_bar_binding.dart';
import '../modules/battery/charge_limit/views/charge_limit_view.dart';
import '../modules/battery/charge_limit/charge_limit_binding.dart';
import '../modules/feedback/views/feedback_view.dart';
import '../modules/feedback/bindings/feedback_binding.dart';
import '../modules/about/views/about_view.dart';
import '../modules/about/bindings/about_binding.dart';
import '../modules/advanced_settings/views/advanced_settings_view.dart';
import '../modules/advanced_settings/bindings/advanced_settings_binding.dart';
import '../modules/leo_troubleshoot/views/leo_troubleshoot_view.dart';
import '../modules/leo_troubleshoot/bindings/leo_troubleshoot_binding.dart';
import '../modules/manual/views/manual_view.dart';
import '../modules/manual/bindings/manual_binding.dart';
import '../modules/battery/history/views/battery_history_view.dart';
import '../modules/battery/history/battery_history_binding.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.bluetoothAccessScreen,
      page: () => const BluetoothAccessScreen(),
      // binding: BluetoothAccessBinding(),
    ),
    GetPage(
      name: AppRoutes.notificationAccessScreen,
      page: () => const NotificationAccessScreen(),
      // binding: NotificationAccessBinding(),
    ),
    GetPage(
      name: AppRoutes.locationAccessScreen,
      page: () => const LocationAccessScreen(),
      // binding: LocationAccessBinding(),
    ),
    GetPage(
      name: AppRoutes.newNavBarView,
      page: () => NewNavBarView(),
      binding: NewNavBarBinding(),
      children: [
        GetPage(
          name: AppRoutes.leoHome,
          page: () => const LeoHomeScreen(),
          // Leo tab will have id: 1 for its nested navigator
          bindings:
              [], // You can add specific bindings for Leo tab routes here if needed
          children: [
            GetPage(
              name: AppRoutes.scan,
              page: () => const ScanScreen(),
              bindings: [],
            ),
            GetPage(
              name: AppRoutes.deviceList,
              page: () => const DeviceListScreen(),
              bindings: [],
            ),
            GetPage(
              name: AppRoutes.deviceDetail,
              page: () => const DeviceDetailScreen(),
              bindings: [],
            ),
          ],
        ),
        GetPage(
          name: AppRoutes.phoneDetail,
          page: () => const PhoneDetailScreen(),
          // Home tab will have id: 2 for its nested navigator
          bindings:
              [], // You can add specific bindings for Home tab routes here if needed
        ),
      ],
    ),
    GetPage(
      name: AppRoutes.setChargeLimitView,
      page: () => const ChargeLimitView(),
      binding: ChargeLimitBinding(),
    ),
    GetPage(
      name: AppRoutes.feedbackView,
      page: () => const FeedbackView(),
      binding: FeedbackBinding(),
    ),
    GetPage(
      name: AppRoutes.aboutView,
      page: () => const AboutView(),
      binding: AboutBinding(),
    ),
    GetPage(
      name: AppRoutes.advanceSettings,
      page: () => const AdvancedSettingsView(),
      binding: AdvancedSettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.leoTroubleshoot,
      page: () => const LeoTroubleshootView(),
      binding: LeoTroubleshootBinding(),
    ),
    GetPage(
      name: AppRoutes.leoManual,
      page: () => const ManualView(),
      binding: ManualBinding(),
    ),
    GetPage(
      name: AppRoutes.batteryHistoryView,
      page: () => const BatteryHistoryView(),
      binding: BatteryHistoryBinding(),
    ),
  ];

  static Route<dynamic> onGenerateNestedRoute(int id, RouteSettings settings) {
    String? requestedRouteName = settings.name;
    String? baseRouteName;

    if (id == 1) {
      baseRouteName = AppRoutes.newNavBarView + AppRoutes.leoHome;
    } else if (id == 2) {
      baseRouteName = AppRoutes.newNavBarView + AppRoutes.phoneDetail;
    }

    String? actualRouteName = requestedRouteName;

    // Handle default route for nested navigators
    if (requestedRouteName == '/') {
      if (id == 1) {
        actualRouteName = AppRoutes.leoHome;
      } else if (id == 2) {
        actualRouteName = AppRoutes.phoneDetail;
      }
    } else if (baseRouteName != null &&
        requestedRouteName!.startsWith(baseRouteName)) {
      // Extract the relative path for nested routes
      actualRouteName = requestedRouteName.substring(baseRouteName.length);
      if (actualRouteName.isEmpty) {
        if (id == 1) {
          actualRouteName = AppRoutes.leoHome;
        } else if (id == 2) {
          actualRouteName = AppRoutes.phoneDetail;
        }
      } else if (!actualRouteName.startsWith('/')) {
        actualRouteName = '/' + actualRouteName;
      }
    } else if (requestedRouteName != null &&
        requestedRouteName.startsWith('/')) {
      // If the route doesn't start with the full base path, but is a direct sub-route
      // This handles cases like Get.toNamed('/scan', id: 1) where only the sub-route is provided.
      actualRouteName = requestedRouteName;
    }

    final GetPage? newNavBarPage = routes.firstWhereOrNull(
      (element) => element.name == AppRoutes.newNavBarView,
    );

    if (newNavBarPage != null) {
      GetPage? activeTabRoute;

      if (id == 1) {
        // Leo Tab
        activeTabRoute = newNavBarPage.children.firstWhereOrNull(
          (element) => element.name == AppRoutes.leoHome,
        );
      } else if (id == 2) {
        // Home Tab
        activeTabRoute = newNavBarPage.children.firstWhereOrNull(
          (element) => element.name == AppRoutes.phoneDetail,
        );
      }

      if (activeTabRoute != null) {
        // Check if the requested route is the active tab route itself (e.g., leoHome or phoneDetail)
        if (actualRouteName == activeTabRoute.name) {
          return GetPageRoute(
            routeName: actualRouteName,
            page: activeTabRoute.page,
            binding: activeTabRoute.binding,
            settings: settings,
            transition: activeTabRoute.transition,
            transitionDuration:
                activeTabRoute.transitionDuration ??
                const Duration(milliseconds: 300),
          );
        }

        // Search within the children of the active tab route
        final GetPage? nestedRoute = activeTabRoute.children.firstWhereOrNull(
          (element) => element.name == actualRouteName,
        );

        if (nestedRoute != null) {
          return GetPageRoute(
            routeName: actualRouteName,
            page: nestedRoute.page,
            binding: nestedRoute.binding,
            settings: settings,
            transition: nestedRoute.transition,
            transitionDuration:
                nestedRoute.transitionDuration ??
                const Duration(milliseconds: 300),
          );
        }
      }
    }

    return MaterialPageRoute(
      builder: (_) => const Text('Error - Unknown Nested Route'),
      settings: settings,
    );
  }
}
