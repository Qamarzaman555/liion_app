import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:liion_app/app/core/constants/app_assets.dart';
import 'package:liion_app/app/core/constants/app_colors.dart';
import 'package:liion_app/app/core/widgets/custom_button.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import '../controllers/leo_home_controller.dart';

class LeoHomeView extends GetView<LeoHomeController> {
  const LeoHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: AppBar(
          scrolledUnderElevation: 0.0,
          automaticallyImplyLeading: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          flexibleSpace: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(50, 50, 50, 0),
              child: Image.asset(
                PngAssets.leoMainLogo,
                height: 60,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Padding(
                //   padding: const EdgeInsets.fromLTRB(20, 40, 20, 10),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       const Text(
                //         "Leo",
                //         style: TextStyle(
                //           color: Color(0xFF282828),
                //           fontFamily: 'Inter',
                //           fontSize: 24,
                //           fontWeight: FontWeight.w700,
                //         ),
                //       ),
                //       Obx(
                //         () => controller.isScanning.value
                //             ? const SizedBox(
                //                 width: 20,
                //                 height: 20,
                //                 child: CircularProgressIndicator(strokeWidth: 2),
                //               )
                //             : const SizedBox.shrink(),
                //       ),
                //     ],
                //   ),
                // ),
                Obx(
                  () => CustomButton(
                    height: 70,
                    backgroundColor:
                        controller.connectionState.value ==
                            BleConnectionState.connected
                        ? AppColors.primaryColor
                        : AppColors.primaryInvertColor,
                    text:
                        controller.connectionState.value ==
                            BleConnectionState.connected
                        ? 'Connected'
                        : controller.connectionState.value ==
                              BleConnectionState.connecting
                        ? 'Connecting...'
                        : 'Disconnected',
                    onPressed: () => _handleConnectionButtonTap(context),
                  ),
                ),
                const SizedBox(height: 10),
                Obx(
                  () => CustomButton(
                    height: 70,
                    backgroundColor:
                        controller.connectionState.value ==
                            BleConnectionState.disconnected
                        ? AppColors.primaryColor
                        : AppColors.primaryInvertColor,
                    text:
                        controller.connectionState.value ==
                            BleConnectionState.connected
                        ? 'Leo is up-to-date'
                        : 'Update Leo',
                    onPressed: () {
                      if (controller.isBluetoothOn) {
                        controller.connectionState.value ==
                                BleConnectionState.connected
                            ? controller.disconnectDevice()
                            : controller.connectToDevice(
                                controller.scannedDevices[0]['address'] ?? '',
                              );
                      } else {
                        BleScanService.requestEnableBluetooth();
                      }
                    },
                  ),
                ),

                SizedBox(height: 20),

                Card(
                  color: AppColors.whiteColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bolt,
                                  color: AppColors.secondaryColor,
                                  size: 22,
                                ),
                                Text("Current"),
                                SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4DAEA7),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                  ),

                                  child: Obx(
                                    () => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        controller.currentValue.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            Row(
                              children: [
                                Text("Voltage"),
                                SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4DAEA7),
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                  ),
                                  child: Obx(
                                    () => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        controller.voltageValue.value,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Power"),
                            SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF4DAEA7),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              child: Obx(
                                () => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: Text(controller.powerValue.value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Card(
                  color: AppColors.whiteColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const Icon(
                          Icons.bolt,
                          color: AppColors.secondaryColor,
                          size: 22,
                        ),
                        Text("Total Charges"),
                        SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4DAEA7),
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),

                          child: Obx(
                            () => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              child: Text(controller.mwhValue.value),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded(
                //   child: Obx(() {
                //     if (controller.connectionState.value ==
                //         BleConnectionState.connected) {
                //       return _buildDataLog();
                //     }
                //     if (controller.scannedDevices.isEmpty) {
                //       return _buildEmptyState();
                //     }
                //     return _buildDeviceList();
                //   }),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleConnectionButtonTap(BuildContext context) {
    if (!controller.isBluetoothOn) {
      BleScanService.requestEnableBluetooth();
      return;
    }

    _showDeviceSelectionDialog(context);
  }

  void _showDeviceSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _BluetoothConnectionDialog(),
    );
  }

  Widget _buildDataLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Data Log',
                style: TextStyle(
                  color: Color(0xFF282828),
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => controller.receivedDataLog.clear(),
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (controller.receivedDataLog.isEmpty) {
              return const Center(
                child: Text(
                  'No data received yet',
                  style: TextStyle(
                    color: Color(0xFF888888),
                    fontFamily: 'Inter',
                    fontSize: 14,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: controller.receivedDataLog.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    controller.receivedDataLog[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF282828),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(PngAssets.leoIllustration, height: 200),
          const SizedBox(height: 40),
          const Text(
            "No Leo device found",
            style: TextStyle(
              color: Color(0xFF282828),
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Scanning for Leo USB devices...\nMake sure your device is powered on",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF888888),
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () => controller.rescan(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Scan for Leo",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Found Devices (${controller.scannedDevices.length})",
                style: const TextStyle(
                  color: Color(0xFF282828),
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => controller.rescan(),
                child: Text(
                  "Rescan",
                  style: TextStyle(
                    color: AppColors.primaryColor,
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: controller.scannedDevices.length,
            itemBuilder: (context, index) {
              final device = controller.scannedDevices[index];
              final address = device['address'] ?? '';
              return Obx(() {
                final isConnected = controller.isDeviceConnected(address);
                final isConnecting = controller.isDeviceConnecting(address);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isConnected
                        ? const BorderSide(color: Colors.green, width: 2)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? Colors.green.withOpacity(0.1)
                            : AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth,
                        color: isConnected
                            ? Colors.green
                            : AppColors.primaryColor,
                      ),
                    ),
                    title: Text(
                      device['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      isConnected ? 'Connected' : address,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isConnected
                            ? Colors.green
                            : const Color(0xFF888888),
                      ),
                    ),
                    trailing: isConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              if (isConnected) {
                                controller.disconnectDevice();
                              } else {
                                controller.connectToDevice(address);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isConnected
                                  ? Colors.red
                                  : AppColors.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isConnected ? "Disconnect" : "Connect",
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                );
              });
            },
          ),
        ),
      ],
    );
  }
}

class _BluetoothConnectionDialog extends StatefulWidget {
  const _BluetoothConnectionDialog();

  @override
  State<_BluetoothConnectionDialog> createState() =>
      _BluetoothConnectionDialogState();
}

class _BluetoothConnectionDialogState extends State<_BluetoothConnectionDialog>
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
                  "Connected Device",
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
                    "No Device Connected",
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
                      "Available Devices",
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
                          final isItemConnected = controller.isDeviceConnected(
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
                                          isItemConnected
                                              ? '$name (connected)'
                                              : name,
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
