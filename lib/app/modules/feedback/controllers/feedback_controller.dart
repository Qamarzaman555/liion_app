import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liion_app/app/core/utils/snackbar_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:liion_app/app/modules/leo_empty/controllers/leo_home_controller.dart';
import 'package:liion_app/app/services/ble_scan_service.dart';
import '../views/widgets/feedback_thanks_dialog.dart';

class FeedbackController extends GetxController {
  final feedbackText = ''.obs;
  final emailController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final loading = false.obs;
  StreamSubscription? _dataReceivedSubscription;

  @override
  void onInit() async {
    super.onInit();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    emailController.text = prefs.getString('userEmail') ?? '';

    // Store any existing device information in the history
    await storeExistingDeviceInHistory();

    // Listen for serial number responses
    _listenToSerialResponses();
  }

  void _listenToSerialResponses() {
    _dataReceivedSubscription = BleScanService.dataReceivedStream.listen((
      data,
    ) {
      _parseSerialNumber(data);
    });
  }

  void _parseSerialNumber(String data) {
    try {
      List<String> parts = data.split(' ');

      // Parse serial number response (similar to swversion parsing)
      if (parts.length >= 2 && parts[1].toLowerCase() == 'serial') {
        String serialNumber = parts.length > 2
            ? parts[2].trim()
            : parts[0].trim();
        if (serialNumber.isNotEmpty && serialNumber != 'OK') {
          // Store serial number in SharedPreferences
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString('leo_serial_number', serialNumber);
            print('Serial number stored: $serialNumber');
          });
        }
      }
    } catch (e) {
      print('Error parsing serial number: $e');
    }
  }

  @override
  void onClose() {
    _dataReceivedSubscription?.cancel();
    emailController.dispose();
    super.onClose();
  }

  void setFeedback(String text) {
    feedbackText.value = text;
  }

  Future<void> handleFeedbackSubmission(BuildContext context) async {
    if (formKey.currentState?.validate() ?? false) {
      loading.value = true;

      try {
        // Save user email
        await saveUserEmail(emailController.text.trim());

        // Ensure we have the latest device information before sending feedback
        final leoHomeController = Get.find<LeoHomeController>();
        final isConnected = await BleScanService.isConnected();

        // If device is connected, refresh device information and store it
        if (isConnected) {
          await leoHomeController.sendCommand('serial');
          await leoHomeController.sendCommand('swversion');
          // Wait a bit for the commands to be processed
          await Future.delayed(const Duration(milliseconds: 500));

          // Get serial number from stored preferences or try to get from controller
          String? serialNumber = await _getSerialNumber();
          String firmwareVersion = leoHomeController.binFileFromLeoName.value
              .trim();

          // Store the device information locally
          if (serialNumber != null &&
              serialNumber.isNotEmpty &&
              firmwareVersion.isNotEmpty) {
            await storeLeoDeviceInfo(serialNumber, firmwareVersion);
          }
        }

        await sendEmail(context);
        loading.value = false;
        showFeedbackThanksDialog(context);
      } catch (e) {
        loading.value = false;
        if (context.mounted) {
          AppSnackbars.showSuccess(
            title: 'Error',
            message: 'Error sending feedback: $e',
          );
        }
      }
    } else {
      if (context.mounted) {
        AppSnackbars.showSuccess(
          title: 'Error',
          message: 'Error sending feedback: Please fill in all required fields',
        );
      }
    }
  }

  Future<String?> _getSerialNumber() async {
    // Try to get from SharedPreferences first
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? serialNumber = prefs.getString('leo_serial_number');

    // If not found, try to get from device response (would need to parse from received data)
    // For now, return from preferences or null
    return serialNumber;
  }

  Future<void> sendEmail(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final leoHomeController = Get.find<LeoHomeController>();

      // Email configuration
      const String username = 'app.liionpower@gmail.com';
      // String username = 'qamarzk12345@gmail.com'; //My Email
      const String password = 'ecoc rfit mwza rtnb';
      // String password = 'bjdd hnva wbfd jfsb';
      final smtpServer = gmail(username, password);

      // Get device information - try current values first, then fallback to stored values
      String serialNumber = 'N/A';
      String firmwareVersion = 'N/A';

      // Try to get from controller first
      final isConnected = await BleScanService.isConnected();
      if (isConnected) {
        serialNumber = await _getSerialNumber() ?? 'N/A';
        firmwareVersion =
            leoHomeController.binFileFromLeoName.value.trim().isNotEmpty
            ? leoHomeController.binFileFromLeoName.value.trim()
            : 'N/A';
      }

      // If not available from controller, try stored values
      if (serialNumber == 'N/A' || firmwareVersion == 'N/A') {
        final storedInfo = await getLeoDeviceInfo();
        if (serialNumber == 'N/A') {
          serialNumber = storedInfo['serial_number'] ?? 'N/A';
        }
        if (firmwareVersion == 'N/A') {
          firmwareVersion = storedInfo['firmware_version'] ?? 'N/A';
        }
      }

      // Get all devices that have been used with this app
      List<Map<String, String>> allDevices = await getAllDeviceHistory();
      Map<String, dynamic> deviceStats = await getDeviceStatistics();

      // Build device history text
      String deviceHistoryText = '';
      if (allDevices.isNotEmpty) {
        deviceHistoryText = '\n\nDevice Statistics:';
        deviceHistoryText +=
            '\n- Total device combinations: ${deviceStats['total_devices']}';
        deviceHistoryText +=
            '\n- Unique serial numbers: ${deviceStats['unique_serial_numbers']}';
        deviceHistoryText +=
            '\n- Unique firmware versions: ${deviceStats['unique_firmware_versions']}';
        deviceHistoryText +=
            '\n- Most common firmware: ${deviceStats['most_common_firmware']}';

        deviceHistoryText += '\n\nAll Leo Devices Used with this App:';
        for (int i = 0; i < allDevices.length; i++) {
          var device = allDevices[i];
          deviceHistoryText +=
              '\n${i + 1}. Serial: ${device['serial_number']} | Firmware: ${device['firmware_version']}';
        }
      }

      // Create email message
      final message = Message()
        ..from = Address(username, 'Liion Power App')
        ..recipients.add('app@liionpower.tech')
        // ..recipients.add('qamarzk12345@gmail.com')
        ..subject = 'Feedback from Liion App'
        ..text =
            '''
Email: ${emailController.text.isNotEmpty ? emailController.text : 'Email not provided'}
Feedback Message: ${feedbackText.value}
App Version: ${packageInfo.version}+${packageInfo.buildNumber}
Current Leo Serial Number: $serialNumber
Current Leo Firmware Version: $firmwareVersion
OS: ${Platform.isAndroid ? 'Android' : 'iOS'}$deviceHistoryText
''';

      final sendReport = await send(message, smtpServer);
      print('Message sent: $sendReport');

      if (context.mounted) {
        AppSnackbars.showSuccess(
          title: 'Success',
          message: 'Feedback sent successfully',
        );
      }
    } on MailerException catch (e) {
      print('Message not sent: ${e.message}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      rethrow;
    }
  }

  void showFeedbackThanksDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const FeedbackThanksDialog(),
    );
  }

  // Store existing device information in history if not already there
  Future<void> storeExistingDeviceInHistory() async {
    try {
      String? existingSerial = await SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('leo_serial_number'),
      );
      String? existingFirmware = await SharedPreferences.getInstance().then(
        (prefs) => prefs.getString('leo_firmware_version'),
      );

      if (existingSerial != null &&
          existingFirmware != null &&
          existingSerial.isNotEmpty &&
          existingFirmware.isNotEmpty) {
        await addToDeviceHistory(existingSerial, existingFirmware);
      }
    } catch (e) {
      print('Error storing existing device in history: $e');
    }
  }

  // Store Leo device information locally
  Future<void> storeLeoDeviceInfo(
    String serialNumber,
    String firmwareVersion,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('leo_serial_number', serialNumber);
    await prefs.setString('leo_firmware_version', firmwareVersion);

    // Also store in the list of all devices used
    await addToDeviceHistory(serialNumber, firmwareVersion);
  }

  // Add device to history (avoiding duplicates)
  Future<void> addToDeviceHistory(
    String serialNumber,
    String firmwareVersion,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get existing device history
    List<String> deviceHistory =
        prefs.getStringList('leo_device_history') ?? [];

    // Create a unique identifier for this device combination
    String deviceKey = '$serialNumber|$firmwareVersion';

    // Only add if not already in the list
    if (!deviceHistory.contains(deviceKey)) {
      deviceHistory.add(deviceKey);
      await prefs.setStringList('leo_device_history', deviceHistory);
      print('Added new device to history: $deviceKey');
    }
  }

  // Get all devices that have been used with this app
  Future<List<Map<String, String>>> getAllDeviceHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> deviceHistory =
        prefs.getStringList('leo_device_history') ?? [];

    List<Map<String, String>> devices = [];
    for (String deviceKey in deviceHistory) {
      List<String> parts = deviceKey.split('|');
      if (parts.length == 2) {
        devices.add({'serial_number': parts[0], 'firmware_version': parts[1]});
      }
    }

    return devices;
  }

  // Get the most recently used device
  Future<Map<String, String>> getMostRecentDevice() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> deviceHistory =
        prefs.getStringList('leo_device_history') ?? [];

    if (deviceHistory.isNotEmpty) {
      String lastDeviceKey = deviceHistory.last;
      List<String> parts = lastDeviceKey.split('|');
      if (parts.length == 2) {
        return {'serial_number': parts[0], 'firmware_version': parts[1]};
      }
    }

    return {
      'serial_number': 'Not available',
      'firmware_version': 'Not available',
    };
  }

  // Clear device history (for testing or privacy)
  Future<void> clearDeviceHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('leo_device_history');
  }

  // Get device statistics
  Future<Map<String, dynamic>> getDeviceStatistics() async {
    List<Map<String, String>> allDevices = await getAllDeviceHistory();

    // Count unique serial numbers
    Set<String> uniqueSerials = allDevices
        .map((device) => device['serial_number']!)
        .toSet();

    // Count unique firmware versions
    Set<String> uniqueFirmwares = allDevices
        .map((device) => device['firmware_version']!)
        .toSet();

    // Find most common firmware version
    Map<String, int> firmwareCount = {};
    for (var device in allDevices) {
      String firmware = device['firmware_version']!;
      firmwareCount[firmware] = (firmwareCount[firmware] ?? 0) + 1;
    }

    String mostCommonFirmware = firmwareCount.isEmpty
        ? 'None'
        : firmwareCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return {
      'total_devices': allDevices.length,
      'unique_serial_numbers': uniqueSerials.length,
      'unique_firmware_versions': uniqueFirmwares.length,
      'most_common_firmware': mostCommonFirmware,
      'device_list': allDevices,
    };
  }

  // Export device history as JSON string for debugging/support
  Future<String> exportDeviceHistory() async {
    Map<String, dynamic> exportData = {
      'export_timestamp': DateTime.now().toIso8601String(),
      'app_version': (await PackageInfo.fromPlatform()).version,
      'device_statistics': await getDeviceStatistics(),
      'all_devices': await getAllDeviceHistory(),
    };

    return jsonEncode(exportData);
  }

  // Retrieve Leo device information from local storage
  Future<Map<String, String>> getLeoDeviceInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      'serial_number': prefs.getString('leo_serial_number') ?? 'Not available',
      'firmware_version':
          prefs.getString('leo_firmware_version') ?? 'Not available',
    };
  }

  // Save user email
  Future<void> saveUserEmail(String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('userEmail', emailController.text.trim());
  }
}
