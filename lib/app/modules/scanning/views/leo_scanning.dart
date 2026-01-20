import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/widgets/animated_bottom_navbar.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class ScanningLeoScreen extends StatefulWidget {
  const ScanningLeoScreen({super.key});

  @override
  State<ScanningLeoScreen> createState() => _ScanningLeoScreenState();
}

class _ScanningLeoScreenState extends State<ScanningLeoScreen> {
  final controller = Get.find<LeoHomeController>();
  Timer? _deviceCheckTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Start scanning when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupDeviceListener();
    });
  }

  @override
  void dispose() {
    _deviceCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for devices and navigate when found
    return Obx(() {
      return SafeArea(
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(AppSizes.defaultSpace),
            child: Column(
              children: [
                Center(child: SvgPicture.asset(AppImages.appLogoColored)),
                const SizedBox(height: AppSizes.spaceBtwSections),

                // Tab content switcher for scanning
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Get.back(id: 1);
                          },
                          child: SvgPicture.asset(AppImages.leoLogoOutlinedLg),
                        ),
                        const SizedBox(height: AppSizes.spaceBtwSections),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Obx(
                              () => Icon(
                                Icons.circle,
                                color: controller.isScanning.value
                                    ? NewAppColors.blue
                                    : Colors.grey,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Obx(
                              () => Text(
                                controller.isScanning.value
                                    ? "Scanning for Leo's nearby"
                                    : controller.scannedDevices.isEmpty
                                    ? "No devices found"
                                    : "Found ${controller.scannedDevices.length} device(s)",
                                style: const TextStyle(
                                  fontSize: AppSizes.fontSizeMd,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: "SF Pro Text",
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            if (controller.isScanning.value) ...[
                              const SizedBox(width: AppSizes.xs),
                              SvgPicture.asset(AppImages.loadingRight),
                            ],
                          ],
                        ),
                        if (!controller.isScanning.value &&
                            controller.scannedDevices.isEmpty) ...[
                          const SizedBox(height: AppSizes.spaceBtwSections),
                          ElevatedButton(
                            onPressed: () => _startScanning(),
                            child: const Text('Scan Again'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const AnimatedBottomNavBar(),
        ),
      );
    });
  }

  Future<void> _startScanning() async {
    if (!controller.isBluetoothOn) {
      await BleScanService.requestEnableBluetooth();
      return;
    }

    await controller.rescan();
  }

  void _setupDeviceListener() {
    _deviceCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (controller.scannedDevices.isNotEmpty && !_hasNavigated && mounted) {
        _hasNavigated = true;
        timer.cancel();
        Get.toNamed(
          '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceList}',
          id: 1,
        );
      }
    });
  }
}
