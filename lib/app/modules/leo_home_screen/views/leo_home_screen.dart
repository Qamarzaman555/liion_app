import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/core/widgets/custom_list_tile.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class LeoHomeScreen extends GetView<LeoHomeController> {
  const LeoHomeScreen({super.key});

  static bool _didTriggerInitialFirmwareDownload = false;

  @override
  Widget build(BuildContext context) {
    _ensureInitialFirmwareDownload();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (controller.connectionState.value == BleConnectionState.connected) {
    //     Get.offAllNamed(
    //       '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceDetail}',
    //     );
    //   }
    // });

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            _buildBackgroundGradient(context),

            // Backdrop filter for blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.defaultSpace,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.defaultSpace),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: SvgPicture.asset(
                            AppImages.appLogoWhite,
                            height: MediaQuery.sizeOf(context).width * 0.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwSections),

                  const Text(
                    "Add Devices",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwTexts),
                  CustomListTile(
                    onTap: () async {
                      await _handleAddDeviceTap(context);
                    },
                    titleText: "Leo: The Battery Life Extender",
                    suffixIconPath: AppImages.addSymbol,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _ensureInitialFirmwareDownload() {
    if (_didTriggerInitialFirmwareDownload) {
      return;
    }
    _didTriggerInitialFirmwareDownload = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.downloadFirmwareAtStart();
    });
  }

  Future<void> _handleAddDeviceTap(BuildContext context) async {
    // Check if device is already connected
    if (controller.connectionState.value == BleConnectionState.connected) {
      // Navigate to device detail if connected
      Get.toNamed(
        '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceDetail}',
        id: 1,
      );
      return;
    }

    // Check Bluetooth state
    if (!controller.isBluetoothOn) {
      BleScanService.requestEnableBluetooth();
      return;
    }

    await controller.rescan();

    // Navigate to scanning screen
    Get.toNamed(
      '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.scan}',
      id: 1,
    );
  }

  Widget _buildBackgroundGradient(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        // Main large green circle (top-left area)
        Positioned(
          top: -screenSize.height * 0.3,
          left: -screenSize.width * 1.2,
          child: Container(
            height: screenSize.height * 0.8,
            width: screenSize.height * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color.fromARGB(255, 54, 230, 1).withOpacity(0.6),
                  const Color.fromARGB(255, 54, 230, 1).withOpacity(0.3),
                  const Color.fromARGB(255, 54, 230, 1).withOpacity(0.05),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // Secondary green circle (bottom-right area)
        Positioned(
          bottom: -screenSize.height * 0.3,
          right: -screenSize.width * 0.9,
          child: Container(
            height: screenSize.height * 0.8,
            width: screenSize.height * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color.fromARGB(255, 95, 246, 49).withOpacity(0.6),
                  const Color.fromARGB(255, 95, 246, 49).withOpacity(0.3),
                  const Color.fromARGB(255, 54, 230, 1).withOpacity(0.05),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
