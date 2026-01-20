import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final controller = Get.find<LeoHomeController>();
  Worker? _connectionWorker;
  Timer? _connectionCheckTimer;
  String? _pendingConnectionAddress;

  @override
  void dispose() {
    _connectionWorker?.dispose();
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      Get.back(id: 1);
                    },
                    child: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Center(
                    child: SvgPicture.asset(
                      AppImages.appLogoColored,
                      height: MediaQuery.sizeOf(context).width * 0.2,
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwSections),
              const Text(
                "Available Devices",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontFamily: "SF Pro Text",
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: AppSizes.spaceBtwTexts),
              Obx(() {
                if (controller.scannedDevices.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "No devices found",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: "SF Pro Text",
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceBtwSections),
                          ElevatedButton(
                            onPressed: () {
                              Get.back(id: 1);
                            },
                            child: const Text('Go Back to Scan'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView.separated(
                    itemCount: controller.scannedDevices.length,
                    itemBuilder: (context, index) {
                      final device = controller.scannedDevices[index];
                      final address = device['address'] ?? '';
                      final name = device['name'] ?? 'Unknown Device';
                      final isConnecting = controller.isDeviceConnecting(address);
                      final isConnected = controller.isDeviceConnected(address);

                      return InkWell(
                        onTap: isConnecting || isConnected
                            ? null
                            : () => _handleDeviceTap(context, address),
                        child: Card(
                          elevation: 3,
                          color: NewAppColors.whiteBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.cardRadiusSm),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.defaultSpace - 4,
                                  vertical: AppSizes.md,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SvgPicture.asset(SvgAssets.leoTabIcon),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: AppSizes.fontSizeMd,
                                          fontFamily: 'SF Pro Text',
                                          fontWeight: FontWeight.w400,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (isConnecting)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else if (isConnected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: NewAppColors.accent,
                                        size: 20,
                                      )
                                    else
                                      SvgPicture.asset(AppImages.addSymbol, height: 18),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return const SizedBox(
                        height: AppSizes.spaceBtwInputFields / 3,
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeviceTap(BuildContext context, String address) async {
    // Cancel any existing worker and timer
    _connectionWorker?.dispose();
    _connectionCheckTimer?.cancel();
    _pendingConnectionAddress = address;

    print('🔵 [Device List] Connecting to device: $address');

    // Connect to the device
    await controller.connectToDevice(address);

    // Use ever() to listen to controller's connectionState observable
    // This will trigger when connectionState changes
    _connectionWorker = everAll([
      controller.connectionState,
      controller.connectedDeviceAddress,
    ], ([state, connectedAddress]) {
      print('🔵 [Device List] Connection state: $state, address: $connectedAddress, target: $address');
      if (state == BleConnectionState.connected &&
          connectedAddress == address) {
        print('🟢 [Device List] Device connected! Navigating to detail screen');
        _navigateToDeviceDetail();
      }
    });

    // Also set up a periodic check as fallback (in case ever() misses the change)
    _connectionCheckTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (controller.connectionState.value == BleConnectionState.connected &&
          controller.connectedDeviceAddress.value == address) {
        print('🟢 [Device List] Device connected (periodic check)! Navigating to detail screen');
        timer.cancel();
        _navigateToDeviceDetail();
      } else if (controller.connectionState.value == BleConnectionState.disconnected &&
          _pendingConnectionAddress == address) {
        // If disconnected and we were trying to connect, cancel the timer
        print('🔴 [Device List] Connection failed or cancelled');
        timer.cancel();
        _pendingConnectionAddress = null;
      }
    });

    // Also check immediately if already connected (in case connection happened very quickly)
    if (controller.connectionState.value == BleConnectionState.connected &&
        controller.connectedDeviceAddress.value == address) {
      print('🟢 [Device List] Already connected! Navigating immediately');
      _navigateToDeviceDetail();
    }
  }

  void _navigateToDeviceDetail() {
    _connectionWorker?.dispose();
    _connectionWorker = null;
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _pendingConnectionAddress = null;

    if (mounted) {
      Get.toNamed(
        '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.deviceDetail}',
        id: 1,
      );
    }
  }
}
