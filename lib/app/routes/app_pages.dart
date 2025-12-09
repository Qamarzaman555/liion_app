import 'package:get/get.dart';
import 'app_routes.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/bottom_nav_bar/views/bottom_nav_bar_view.dart';
import '../modules/bottom_nav_bar/bindings/bottom_nav_bar_binding.dart';
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
import '../modules/led_timeout/views/led_timeout_view.dart';
import '../modules/led_timeout/bindings/led_timeout_binding.dart';

class AppPages {
  static const initial = AppRoutes.splash;

  static final routes = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.navBarView,
      page: () => const BottomNavBarView(),
      binding: BottomNavBarBinding(),
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
    GetPage(
      name: AppRoutes.ledTimeout,
      page: () => const LedTimeoutView(),
      binding: LedTimeoutBinding(),
    ),
  ];
}
