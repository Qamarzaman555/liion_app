import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/constants/sizes.dart';
import 'package:liion_app/app/core/widgets/custom_appbar.dart';
import 'package:liion_app/app/modules/device_detail/views/widgets/charging_mode_expansion_tile.dart';
import 'package:liion_app/app/modules/leo_empty/graphs/charge_graph_widget.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/routes/app_routes.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import 'package:liion_app/app/core/widgets/disconnect_dialog.dart';

class DeviceDetailScreen extends GetView<LeoHomeController> {
  const DeviceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: NewAppColors.whiteBackground,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(AppSizes.appBarHeight * 1.5),
          child: Obx(() {
            final deviceName = _getDeviceName();
            return CustomAppBar(
              title: deviceName,
              height: AppSizes.appBarHeight * 1.5,
              backgroundColor: NewAppColors.whiteBackground,
              titleColor: Colors.black,
              centerTitle: true,
              showBackButton: true,
              onBackPressed: () {
                if (controller.connectionState.value ==
                    BleConnectionState.connected) {
                  _showDisconnectDialog(context);
                } else {
                  Get.back(id: 1);
                }
              },
              elevation: 2.0,
              actions: [
                GestureDetector(
                  onTap: () => Get.toNamed(
                    '${AppRoutes.newNavBarView}${AppRoutes.leoHome}${AppRoutes.advanceSettings}',
                    id: 1,
                  ),
                  child: SvgPicture.asset(AppImages.settings),
                ),
              ],
            );
          }),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.defaultSpace),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Spacer(flex: 8),
                    Image.asset(
                      AppImages.leoImageLg,
                      height: MediaQuery.sizeOf(context).width * 0.6,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Obx(
                      () => Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              color:
                                  controller.connectionState.value ==
                                      BleConnectionState.connected
                                  ? NewAppColors.accent
                                  : Colors.grey,
                              size: 8,
                            ),
                            const SizedBox(width: AppSizes.xs / 1.2),
                            Text(
                              controller.connectionState.value ==
                                      BleConnectionState.connected
                                  ? "Connected"
                                  : controller.connectionState.value ==
                                        BleConnectionState.connecting
                                  ? "Connecting..."
                                  : "Disconnected",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 3),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceBtwSections),
                const Text(
                  'Charging Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    fontFamily: "SF Pro Text",
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwTexts),
                const ChargingModeExpansionTile(),
                const SizedBox(height: AppSizes.spaceBtwInputFields),
                const Text(
                  'Leo Measurement',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    fontFamily: "SF Pro Text",
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwTexts),
                Obx(
                  () => Row(
                    children: [
                      _buildMeasurementCard(
                        'Current',
                        controller.connectionState.value ==
                                BleConnectionState.connected
                            ? controller.currentValue.value.isEmpty
                                  ? '--'
                                  : controller.currentValue.value
                            : '--',
                      ),
                      _buildMeasurementCard(
                        'Voltage',
                        controller.connectionState.value ==
                                BleConnectionState.connected
                            ? controller.voltageValue.value.isEmpty
                                  ? '--'
                                  : controller.voltageValue.value
                            : '--',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwSections),
                // Charge graphs
                const Text(
                  'Current Charge',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    fontFamily: "SF Pro Text",
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwTexts),
                Card(
                  color: NewAppColors.whiteBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadiusLg),
                    side: const BorderSide(
                      color: NewAppColors.containerBorder,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.defaultSpace),
                    child: const ChargeGraphWidget(
                      isCurrentCharge: true,
                      height: 250,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwSections),
                const Text(
                  'Past Charge',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    fontFamily: "SF Pro Text",
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwTexts),
                Card(
                  color: NewAppColors.whiteBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadiusLg),
                    side: const BorderSide(
                      color: NewAppColors.containerBorder,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.defaultSpace),
                    child: Obx(() {
                      return controller.isPastGraphLoading.value
                          ? SizedBox(
                              height: 250,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      NewAppColors.primary,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Loading past charge graph...',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : const ChargeGraphWidget(
                              isCurrentCharge: false,
                              height: 250,
                            );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementCard(String title, String value) {
    return Expanded(
      child: Card(
        color: NewAppColors.whiteBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadiusLg),
          side: const BorderSide(color: NewAppColors.containerBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spaceBtwSectionsHalf,
            vertical: AppSizes.defaultSpace - 4,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: "SF Pro Text",
                  color: NewAppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: NewAppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDeviceName() {
    final connectedAddress = controller.connectedDeviceAddress.value;
    if (connectedAddress == null) {
      return 'Leo Device';
    }

    try {
      final device = controller.scannedDevices.firstWhere(
        (d) => d['address'] == connectedAddress,
      );
      return device['name'] ?? 'Leo Device';
    } catch (_) {
      return 'Leo Device';
    }
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => DisconnectDialog(
        onConfirm: () async {
          Navigator.of(context).pop();
          await controller.disconnectDevice();
          // Navigate back to leo home screen
          Get.offNamed('${AppRoutes.newNavBarView}${AppRoutes.leoHome}', id: 1);
        },
        onCancel: () {
          Get.back();
        },
      ),
    );
  }
}
