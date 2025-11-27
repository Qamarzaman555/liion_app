import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';

import '../../controllers/leo_home_controller.dart';

class BluetoothConnectionDialog extends StatefulWidget {
  const BluetoothConnectionDialog({super.key});

  @override
  State<BluetoothConnectionDialog> createState() =>
      _BluetoothConnectionDialogState();
}

class _BluetoothConnectionDialogState extends State<BluetoothConnectionDialog>
    with SingleTickerProviderStateMixin {
  final LeoHomeController controller = Get.find();
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: screenWidth,
        height: 450,
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Obx(() {
          final devices = controller.scannedDevices;
          final isConnected =
              controller.connectionState.value == BleConnectionState.connected;
          final connectedAddress = controller.connectedDeviceAddress.value;
          final connectedName = _connectedDeviceName(connectedAddress, devices);
          final filteredDevices = connectedAddress == null
              ? devices
              : devices
                    .where((device) => device['address'] != connectedAddress)
                    .toList();

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                child: Text(
                  'Connected Device',
                  style: TextStyle(
                    color: Color(0xFF282828),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (isConnected && connectedAddress != null)
                _ConnectedDeviceCard(
                  name: connectedName,
                  onTap: () async {
                    await controller.disconnectDevice();
                    await Future.delayed(const Duration(milliseconds: 300));
                    controller.rescan();
                  },
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No Device Connected',
                    style: TextStyle(
                      color: Color(0xFF282828),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RotationTransition(
                      turns: _rotationController,
                      child: const Icon(
                        Icons.autorenew_rounded,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Available Devices',
                      style: TextStyle(
                        color: Color(0xFF282828),
                        fontFamily: 'Inter',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredDevices.isEmpty
                    ? const Center(
                        child: Text(
                          'No available devices.\nTap Rescan to search again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        itemCount: filteredDevices.length,
                        itemBuilder: (context, index) {
                          final device = filteredDevices[index];
                          final name = _trimDeviceName(device['name']);
                          final address = device['address'] ?? '';
                          final isConnecting = controller.isDeviceConnecting(
                            address,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: (address.isEmpty || isConnecting)
                                  ? null
                                  : () async {
                                      await controller.connectToDevice(address);
                                      if (mounted) Navigator.of(context).pop();
                                    },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.primaryColor,
                                    width: 2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isConnecting)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.bluetooth,
                                          color: Colors.white,
                                          size: 25,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: controller.rescan,
                        child: Container(
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.secondaryColor,
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Rescan',
                              style: TextStyle(
                                color: AppColors.secondaryColor,
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 55,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.secondaryColor,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isConnected ? 'Done' : 'Cancel',
                              style: const TextStyle(
                                color: AppColors.secondaryColor,
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _connectedDeviceName(
    String? connectedAddress,
    List<Map<String, String>> devices,
  ) {
    if (connectedAddress == null) return 'Leo Device';
    try {
      final device = devices.firstWhere(
        (d) => d['address'] == connectedAddress,
      );
      final name = device['name'];
      if (name != null && name.isNotEmpty) {
        return name;
      }
    } catch (_) {}
    return 'Leo Device';
  }

  String _trimDeviceName(String? name) {
    final value = (name ?? 'Unknown').trim();
    return value.length > 18 ? '${value.substring(0, 18)}...' : value;
  }
}

class _ConnectedDeviceCard extends StatelessWidget {
  const _ConnectedDeviceCard({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF282828),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF282828), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.bluetooth,
                  color: AppColors.secondaryColor,
                  size: 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
