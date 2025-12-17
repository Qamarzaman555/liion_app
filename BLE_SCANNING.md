# iOS BLE Scanning - "Leo Usb" Device Filter ✅

## Overview

Complete BLE scanning implementation with automatic filtering for devices containing "Leo Usb" in their name.

## What Was Implemented

### iOS Native (Swift)

#### 1. **BLEService.swift** (Updated)
Added comprehensive scanning functionality:

**Features:**
- ✅ Start/Stop BLE scanning
- ✅ Automatic filtering for "Leo Usb" devices (case-insensitive)
- ✅ Device list management (discovered devices stored)
- ✅ RSSI (signal strength) tracking
- ✅ Duplicate prevention (same device only added once)
- ✅ Timestamp tracking (when device was discovered)
- ✅ Complete logging integration

**Scanning Methods:**
```swift
startScan() -> [String: Any]           // Start scanning
stopScan() -> [String: Any]            // Stop scanning
isScanningDevices() -> Bool            // Check if scanning
getDiscoveredDevices() -> [[String: Any]]  // Get filtered device list
clearDiscoveredDevices()               // Clear the list
```

**Device Filter:**
```swift
private let deviceNameFilter = "Leo Usb"

private func shouldIncludeDevice(name: String?) -> Bool {
    guard let deviceName = name else { return false }
    return deviceName.lowercased().contains(deviceNameFilter.lowercased())
}
```

#### 2. **BackgroundServiceChannel.swift** (Updated)
Added scanning methods to Flutter bridge:
- `startBLEScan` - Start scanning
- `stopBLEScan` - Stop scanning
- `isScanning` - Check scan status
- `getDiscoveredDevices` - Get device list
- `clearDiscoveredDevices` - Clear list

### Flutter/Dart Integration

#### 1. **ios_ble_scanner.dart** (New File - 180 lines)
Complete Dart wrapper for BLE scanning:

**IOSBLEScanner Class:**
```dart
static Future<Map<String, dynamic>> startScan()
static Future<Map<String, dynamic>> stopScan()
static Future<bool> isScanning()
static Future<List<BLEDevice>> getDiscoveredDevices()
static Future<bool> clearDiscoveredDevices()
```

**BLEDevice Model:**
```dart
class BLEDevice {
  final String id;        // UUID
  final String name;      // Device name
  final int rssi;         // Signal strength (-100 to 0)
  final double timestamp; // Discovery time
  
  // Helper properties
  String get signalStrength    // "Excellent", "Good", etc.
  String get signalStrengthColor // Color indicator
  int get signalBars           // 0-4 bars
  String get timeSinceDiscovery // "5s ago", "2m ago"
}
```

#### 2. **ble_scanner_example.dart** (New File - 360+ lines)
Complete UI example with:
- Real-time device list (refreshes every 1 second)
- Start/Stop scan buttons
- Signal strength indicators (color-coded)
- Device details (ID, RSSI, time)
- Bluetooth state warnings
- Empty state UI
- Loading indicators

## Usage Examples

### Simple Scan in Flutter

```dart
import 'package:liion_app/services/ios_ble_scanner.dart';

// Start scanning for Leo Usb devices
final result = await IOSBLEScanner.startScan();

if (result['success'] == true) {
  print('Scanning started!');
  
  // Wait a few seconds for devices to be discovered
  await Future.delayed(Duration(seconds: 5));
  
  // Get discovered devices
  List<BLEDevice> devices = await IOSBLEScanner.getDiscoveredDevices();
  
  for (var device in devices) {
    print('Found: ${device.name}');
    print('  Signal: ${device.rssi} dB (${device.signalStrength})');
    print('  ID: ${device.id}');
  }
  
  // Stop scanning
  await IOSBLEScanner.stopScan();
} else {
  print('Failed to start scan: ${result['message']}');
}
```

### Continuous Scanning with UI Updates

```dart
import 'dart:async';

class MyBLEScanner extends StatefulWidget {
  @override
  _MyBLEScannerState createState() => _MyBLEScannerState();
}

class _MyBLEScannerState extends State<MyBLEScanner> {
  List<BLEDevice> devices = [];
  Timer? timer;
  
  @override
  void initState() {
    super.initState();
    startScanning();
  }
  
  @override
  void dispose() {
    timer?.cancel();
    IOSBLEScanner.stopScan();
    super.dispose();
  }
  
  void startScanning() async {
    // Start scan
    await IOSBLEScanner.startScan();
    
    // Refresh device list every second
    timer = Timer.periodic(Duration(seconds: 1), (_) async {
      final discoveredDevices = await IOSBLEScanner.getDiscoveredDevices();
      setState(() {
        devices = discoveredDevices;
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return ListTile(
          title: Text(device.name),
          subtitle: Text('Signal: ${device.signalStrength}'),
          trailing: Text('${device.rssi} dB'),
          onTap: () {
            // Connect to device
            connectToDevice(device);
          },
        );
      },
    );
  }
}
```

### Check Before Scanning

```dart
import 'package:liion_app/services/ios_ble_service.dart';

// Always check Bluetooth state before scanning
final isEnabled = await IOSBLEService.isBluetoothEnabled();

if (!isEnabled) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Bluetooth Disabled'),
      content: Text('Please enable Bluetooth to scan for devices.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
      ],
    ),
  );
  return;
}

// Bluetooth is on, start scanning
await IOSBLEScanner.startScan();
```

### Get Specific Device by Name

```dart
Future<BLEDevice?> findLeoUsbDevice(String searchName) async {
  await IOSBLEScanner.startScan();
  
  // Wait for devices to be discovered
  await Future.delayed(Duration(seconds: 5));
  
  final devices = await IOSBLEScanner.getDiscoveredDevices();
  await IOSBLEScanner.stopScan();
  
  // Find specific device
  return devices.firstWhere(
    (device) => device.name.contains(searchName),
    orElse: () => null,
  );
}

// Usage
final myDevice = await findLeoUsbDevice('Leo Usb-ABC');
if (myDevice != null) {
  print('Found device: ${myDevice.name}');
}
```

## How It Works

### 1. Scanning Process

```
User Action              Native iOS                   Flutter
-----------              ----------                   -------
Tap "Start Scan"    →    startScan() called      →   Updates UI
                         CBCentralManager             
                         scanForPeripherals()         
                         ↓                            
Device Found        →    didDiscover peripheral  →   (stored internally)
"Leo Usb-123"           Check filter: ✅             
                         Add to list                  
                         Log discovery                
                         ↓                            
Flutter polls       ←    getDiscoveredDevices()  ←   Timer (1s)
every 1 second          Return device list      →   Update UI list
```

### 2. Filtering Logic

Only devices with "Leo Usb" in their name are included:

```swift
// iOS Native
func centralManager(_ central: CBCentralManager, 
                   didDiscover peripheral: CBPeripheral,
                   advertisementData: [String : Any],
                   rssi RSSI: NSNumber) {
    let deviceName = peripheral.name ?? "Unknown"
    
    // Filter check
    guard shouldIncludeDevice(name: peripheral.name) else {
        return  // Device filtered out
    }
    
    // Device passed filter, add to list
    logger.logScan("Discovered Leo Usb device: \(deviceName)")
    // ... add to discoveredDevices dictionary
}
```

### 3. Duplicate Prevention

Each device is stored by UUID, so same device is only added once:

```swift
private var discoveredDevices: [String: [String: Any]] = [:]

// When device is discovered
let deviceId = peripheral.identifier.uuidString
discoveredDevices[deviceId] = deviceInfo  // Updates if already exists
```

## Device Information

Each discovered device includes:

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | UUID (unique identifier) |
| `name` | String | Device name (e.g., "Leo Usb-123") |
| `rssi` | Int | Signal strength in dB (-100 to 0) |
| `timestamp` | Double | Unix timestamp of discovery |

### RSSI (Signal Strength) Guide

| RSSI Value | Strength | Bars | Description |
|------------|----------|------|-------------|
| -50 or higher | Excellent | 4/4 | Very close, strong signal |
| -50 to -60 | Good | 3/4 | Close proximity |
| -60 to -70 | Fair | 2/4 | Medium range |
| -70 to -80 | Weak | 1/4 | Far away |
| -80 or lower | Very Weak | 0/4 | Very far, poor signal |

## Example UI

The `ble_scanner_example.dart` provides a complete UI with:

```
┌─────────────────────────────────────┐
│  Leo Usb Device Scanner         ✕   │
├─────────────────────────────────────┤
│  🔄 Scanning for Leo Usb devices... │
│     Found 3 device(s)               │
├─────────────────────────────────────┤
│  ┌─────────────────────────────────┐│
│  │ 📶 Leo Usb-ABC123               ││
│  │    ID: 12345678...              ││
│  │    Signal: -55 dB (Good)        ││
│  │    Discovered: 5s ago       3/4 ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 📶 Leo Usb-XYZ789               ││
│  │    ID: 87654321...              ││
│  │    Signal: -65 dB (Fair)        ││
│  │    Discovered: 12s ago      2/4 ││
│  └─────────────────────────────────┘│
│  ┌─────────────────────────────────┐│
│  │ 📶 Leo Usb-DEF456               ││
│  │    ID: 45612378...              ││
│  │    Signal: -48 dB (Excellent)   ││
│  │    Discovered: 3s ago       4/4 ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│  [▶ Start Scan]  [⏹ Stop Scan]     │
└─────────────────────────────────────┘
```

## Console Logs

When scanning, you'll see logs like:

```
[BackendLogging] Started BLE scan for devices containing 'Leo Usb'
[BackendLogging] Discovered Leo Usb device: Leo Usb-ABC123, RSSI: -55 dB
[BackendLogging] Discovered Leo Usb device: Leo Usb-XYZ789, RSSI: -65 dB
[BackendLogging] Discovered Leo Usb device: Leo Usb-DEF456, RSSI: -48 dB
[BackendLogging] Stopped BLE scan
[BackendLogging] Returning 3 discovered Leo Usb devices
```

## Files Created/Modified

### Created
```
ios/Runner/BLEService.swift                (updated - added scanning)
lib/services/ios_ble_scanner.dart          (180 lines - NEW)
lib/services/ble_scanner_example.dart      (360 lines - NEW)
BLE_SCANNING.md                            (this file)
```

### Modified
```
ios/Runner/BLEService.swift                (added 100+ lines of scanning code)
ios/Runner/BackgroundServiceChannel.swift  (added 5 scanning methods)
```

## API Reference

### IOSBLEScanner

| Method | Return Type | Description |
|--------|------------|-------------|
| `startScan()` | `Future<Map<String, dynamic>>` | Start scanning for Leo Usb devices |
| `stopScan()` | `Future<Map<String, dynamic>>` | Stop scanning |
| `isScanning()` | `Future<bool>` | Check if currently scanning |
| `getDiscoveredDevices()` | `Future<List<BLEDevice>>` | Get list of discovered devices |
| `clearDiscoveredDevices()` | `Future<bool>` | Clear the device list |

### BLEDevice Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Device UUID |
| `name` | `String` | Device name |
| `rssi` | `int` | Signal strength |
| `timestamp` | `double` | Discovery timestamp |
| `signalStrength` | `String` | "Excellent", "Good", etc. |
| `signalStrengthColor` | `String` | Color name for UI |
| `signalBars` | `int` | 0-4 bars |
| `timeSinceDiscovery` | `String` | Human-readable time |

## Testing

### 1. Run the App
```bash
flutter run -d <your-iphone-device-id>
```

### 2. Navigate to Scanner
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => BLEScannerExample()),
);
```

### 3. Test Scanning
1. Tap "Start Scan" button
2. Watch for Leo Usb devices to appear
3. Check signal strength indicators
4. Tap "Stop Scan" when done

### 4. Check Console
```
[BackendLogging] Started BLE scan for devices containing 'Leo Usb'
[BackendLogging] Discovered Leo Usb device: Leo Usb-123, RSSI: -55 dB
```

## Best Practices

### 1. Always Check Bluetooth State
```dart
if (!await IOSBLEService.isBluetoothEnabled()) {
  // Show error message
  return;
}
await IOSBLEScanner.startScan();
```

### 2. Stop Scanning When Done
```dart
@override
void dispose() {
  IOSBLEScanner.stopScan();  // Always stop
  super.dispose();
}
```

### 3. Refresh Device List Regularly
```dart
Timer.periodic(Duration(seconds: 1), (_) async {
  final devices = await IOSBLEScanner.getDiscoveredDevices();
  // Update UI
});
```

### 4. Handle Empty Results
```dart
final devices = await IOSBLEScanner.getDiscoveredDevices();

if (devices.isEmpty) {
  showMessage('No Leo Usb devices found. Make sure device is nearby and powered on.');
}
```

## Filter Customization

To change the device filter, edit `BLEService.swift`:

```swift
// Current filter
private let deviceNameFilter = "Leo Usb"

// Example: Change to filter different devices
private let deviceNameFilter = "My Device"

// Example: Multiple filters (requires code change)
private func shouldIncludeDevice(name: String?) -> Bool {
    guard let deviceName = name else { return false }
    let filters = ["Leo Usb", "Leo Battery", "Liion"]
    return filters.contains { deviceName.lowercased().contains($0.lowercased()) }
}
```

## Summary

✅ **BLE Scanning Complete**
- Scans for BLE devices ✅
- Filters "Leo Usb" devices (case-insensitive) ✅
- Tracks signal strength (RSSI) ✅
- Prevents duplicates ✅
- Real-time device list ✅
- Flutter integration ready ✅
- Example UI provided ✅
- Comprehensive logging ✅

**Ready for next step:** BLE connection and communication! 🚀

