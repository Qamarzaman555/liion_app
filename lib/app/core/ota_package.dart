// ignore_for_file: annotate_overrides, avoid_print, prefer_const_constructors

// Import necessary libraries
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

// Abstract class defining the structure of an OTA package
abstract class OtaPackage {
  // Method to update firmware
  Future<void> updateFirmware(
    BluetoothDevice device,
    int firmwareType,
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID, {
    String? binFilePath,
    String? url,
  });

  // Property to track firmware update status
  bool firmwareupdate = false;

  // Stream to provide progress percentage
  Stream<int> get percentageStream;
}

// Class responsible for handling BLE repository operations
class BleRepository {
  // Write data to a Bluetooth characteristic
  Future<void> writeDataCharacteristic(
    BluetoothCharacteristic characteristic,
    Uint8List data,
  ) async {
    await characteristic.write(data);
  }

  // Read data from a Bluetooth characteristic
  Future<List<int>> readCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    return await characteristic.read();
  }

  // Request a specific MTU size from a Bluetooth device
  Future<void> requestMtu(BluetoothDevice device, int mtuSize) async {
    await device.requestMtu(mtuSize);
  }
}

// Implementation of OTA package for ESP32
class Esp32OtaPackage implements OtaPackage {
  final BluetoothCharacteristic dataCharacteristic;
  final BluetoothCharacteristic controlCharacteristic;
  bool firmwareupdate = false;

  final StreamController<int> _percentageController =
      StreamController<int>.broadcast();
  @override
  Stream<int> get percentageStream => _percentageController.stream;

  Esp32OtaPackage(this.dataCharacteristic, this.controlCharacteristic);

  @override
  Future<void> updateFirmware(
    BluetoothDevice device,
    int firmwareType,
    BluetoothService service,
    BluetoothCharacteristic dataUUID,
    BluetoothCharacteristic controlUUID, {
    String? binFilePath,
    String? url,
  }) async {
    final bleRepo = BleRepository();

    // Get MTU size from the device
    int mtuSize = await device.mtu.first;
    print("MTU size f current device $mtuSize");

    // Prepare a byte list to write MTU size to controlCharacteristic
    Uint8List byteList = Uint8List(2);

    byteList[0] = 250 & 0xFF;
    byteList[1] = (250 >> 8) & 0xFF;

    List<Uint8List> binaryChunks;

    // Choose firmware source based on firmwareType
    if (firmwareType == 1 && binFilePath != null) {
      binaryChunks = await getFirmware(
        firmwareType,
        mtuSize,
        binFilePath: binFilePath,
      );
    } else if (firmwareType == 2) {
      binaryChunks = await _getFirmwareFromPicker(250);
      print("Binary chunks are $binaryChunks");
    } else if (firmwareType == 3 && url != null && url.isNotEmpty) {
      binaryChunks = await _getFirmwareFromUrl(url, mtuSize);
    } else {
      binaryChunks = [];
    }

    // Write x01 to the controlCharacteristic and check if it returns value of 0x02
    await bleRepo.writeDataCharacteristic(dataCharacteristic, byteList);
    print("Write mtusize on Data characteristic $byteList");
    await bleRepo.writeDataCharacteristic(
      controlCharacteristic,
      Uint8List.fromList([1]),
    );
    print("write 1 on control characteristic");

    // Read value from controlCharacteristic
    List<int> value = await bleRepo
        .readCharacteristic(controlCharacteristic)
        .timeout(Duration(seconds: 10));
    print('value returned is this ------- ${value[0]}');
    print("Response obtained from device is ${value[0]}");

    int packageNumber = 0;
    if (value[0] == 2) {
      for (Uint8List chunk in binaryChunks) {
        //print("Chunk size is ${chunk.length}");
        print("Number of packets to send are ${binaryChunks.length}");

        //print("Chunk is $chunk");
        // Write firmware chunks to dataCharacteristic
        try {
          await bleRepo.writeDataCharacteristic(dataCharacteristic, chunk);
        } catch (e) {
          print("error in writing and exception is $e");
          break;
        }

        print("Packet $packageNumber write to device successful");
        packageNumber++;

        double progress = (packageNumber / binaryChunks.length) * 100;
        int roundedProgress = progress.round(); // Rounded off progress value
        print(
          'Writing package number $packageNumber of ${binaryChunks.length} to ESP32',
        );
        print('Progress: $roundedProgress%');
        _percentageController.add(roundedProgress);
      }

      // Check if all packets were sent successfully
      if (packageNumber == binaryChunks.length) {
        print('All packets sent successfully');
      } else {
        print('Error sending packets');
        return;
      }

      // Write x04 to the controlCharacteristic to finish the update process
      await bleRepo.writeDataCharacteristic(
        controlCharacteristic,
        Uint8List.fromList([4]),
      );
      print("Sent 4 to device for ota complete ack");
      // Check if controlCharacteristic reads 0x05, indicating OTA update finished
      value = await bleRepo
          .readCharacteristic(controlCharacteristic)
          .timeout(Duration(seconds: 600));
      print('value returned is this ------- ${value[0]}');
      print("Ack received from the device and value is ${value[0]}");

      if (value[0] == 5) {
        print('OTA update finished');
        firmwareupdate = true; // Firmware update was successful
      } else {
        print('OTA update failed');
        firmwareupdate = false; // Firmware update failed
        // Show OTA failure dialog
        _showOtaFailureDialog();
      }
    } else {
      print(
        "Did not received ack and Response obtained from device is ${value[0]}",
      );
      print('OTA update failed');
      _showOtaFailureDialog();
      firmwareupdate = false; // Firmware update failed
    }
  }

  // Convert Uint8List to List<int>
  List<int> uint8ListToIntList(Uint8List uint8List) {
    return uint8List.toList();
  }

  // Read binary file and split it into chunks
  /*Future<List<Uint8List>> _readBinaryFile(String filePath, int mtuSize) async {

    // Create a File object from the path of the PlatformFile
  File file = File(filePath.path!);

    // Read the file as bytes
    final byte = await file.readAsBytes();
    //final ByteData data = ByteData.sublistView(Uint8List.fromList(bytes1)); //await rootBundle.load(filePath);
  final List<int> bytes = byte.buffer.asUint8List();
    final int chunkSize = mtuSize-3;
    List<Uint8List> chunks = [];
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = i + chunkSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
      chunks.add(chunk);
    }
    return chunks;
  }*/

  /*Future<List<Uint8List>> _readBinaryFile(String filePath,  int mtuSize) async {    // this is the function that reads the binary file and divides it into chunks of 253 bytes
    print("In binary file read and path is $filePath");
    ByteData fileData = await rootBundle.load(filePath);  // rootBundle opens the file in binary mode
    List<int> bytes = fileData.buffer.asUint8List();
    int chunkSize = 200;//mtuSize-3;                                // this is the packet size, change this value according to the MTU size of device
    print("Chunk size is $chunkSize");
    List<Uint8List> binaryChunks = [];                    // create an empty list of Uint8List type
    for (int i = 0; i < bytes.length; i += chunkSize) {
      int end = i + chunkSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
      binaryChunks.add(chunk);
    }
    return binaryChunks;
  }*/
  Future<List<Uint8List>> _readBinaryFile(String filePath, int mtuSize) async {
    // this is the function that reads the binary file and divides it into chunks of 253 bytes
    print("In binary file read and path is $filePath");
    File file = File(filePath);

    if (await file.exists()) {
      List<int> bytes = await file.readAsBytes();
      print("File exists, and bytes are ${bytes.length}");

      int chunkSize =
          250; //mtuSize - 3; // Adjust according to your requirements
      print("Chunk size is $chunkSize");
      List<Uint8List> binaryChunks = [];
      for (int i = 0; i < bytes.length; i += chunkSize) {
        int end = i + chunkSize;
        if (end > bytes.length) {
          end = bytes.length;
        }
        Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
        binaryChunks.add(chunk);
      }
      print("Binary chunks are ${binaryChunks.length}");
      return binaryChunks;
    } else {
      print('File does not exist.');
      return [];
    }
  }

  // Get firmware based on firmwareType
  Future<List<Uint8List>> getFirmware(
    int firmwareType,
    int mtuSize, {
    String? binFilePath,
  }) {
    if (firmwareType == 2) {
      print("in package mtu size is ${mtuSize}");
      return _getFirmwareFromPicker(mtuSize - 3);
    } else if (firmwareType == 1 && binFilePath != null) {
      return _readBinaryFile(binFilePath, mtuSize);
    } else {
      return Future.value([]);
    }
  }

  // Get firmware chunks from file picker
  Future<List<Uint8List>> _getFirmwareFromPicker(int mtuSize) async {
    print("MtU size in fie picker is ${mtuSize}");
    mtuSize = mtuSize;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      //allowedExtensions: ['bin'],
    );

    if (result == null || result.files.isEmpty) {
      print("File was empty");
      return []; // Return an empty list when no file is picked
    }

    final file = result.files.first;
    print("Read the file :$file");
    try {
      final firmwareData = await _openFileAndGetFirmwareData(file, mtuSize);

      if (firmwareData.isEmpty) {
        throw 'Empty firmware data. Please select a valid firmware file.';
      }

      return firmwareData;
    } catch (e) {
      throw 'Error getting firmware data: $e';
    }
  }

  // Open file, read bytes, and split into chunks
  Future<List<Uint8List>> _openFileAndGetFirmwareData(
    PlatformFile file,
    int mtuSize,
  ) async {
    final bytes = await File(file.path!).readAsBytes();
    List<Uint8List> firmwareData = [];

    for (int i = 0; i < bytes.length; i += mtuSize) {
      int end = i + mtuSize;
      if (end > bytes.length) {
        end = bytes.length;
      }
      firmwareData.add(Uint8List.fromList(bytes.sublist(i, end)));
    }
    return firmwareData;
  }

  // Fetch firmware chunks from a URL
  Future<List<Uint8List>> _getFirmwareFromUrl(String url, int mtuSize) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: 10));

      // Check if the HTTP request was successful (status code 200)
      if (response.statusCode == 200) {
        final List<int> bytes = response.bodyBytes;
        final int chunkSize = mtuSize - 3;
        List<Uint8List> chunks = [];
        for (int i = 0; i < bytes.length; i += chunkSize) {
          int end = i + chunkSize;
          if (end > bytes.length) {
            end = bytes.length;
          }
          Uint8List chunk = Uint8List.fromList(bytes.sublist(i, end));
          chunks.add(chunk);
        }
        return chunks;
      } else {
        // Handle HTTP error (e.g., status code is not 200)
        throw 'HTTP Error: ${response.statusCode} - ${response.reasonPhrase}';
      }
    } catch (e) {
      // Handle other errors (e.g., timeout, network connectivity issues)
      throw 'Error fetching firmware from URL: $e';
    }
  }

  // Show OTA failure dialog
  void _showOtaFailureDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('OTA Update Failed'),
        content: const Text(
          'The OTA update has failed. Please try again.',
          style: TextStyle(color: Color(0xFF666666), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text(
              "OK",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}
