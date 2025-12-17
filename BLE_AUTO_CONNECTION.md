# iOS BLE Auto-Connection ✅

## Overview

Complete auto-connection implementation that automatically reconnects to the last connected device on app startup or after unexpected disconnections.

## Key Features

✅ **Saves Last Connected Device** - Stores device ID and name locally (UserDefaults)  
✅ **Auto-Connect on App Startup** - Automatically connects when app launches  
✅ **Auto-Reconnect on Disconnect** - Reconnects after unexpected disconnections  
✅ **Unlimited Reconnect Attempts** - Keeps trying until connected  
✅ **Fixed 10-Second Delay** - Consistent timing between attempts (battery friendly)  
✅ **Enable/Disable Toggle** - User can turn auto-connect on/off (stops reconnection)  
✅ **Persistent Settings** - Auto-connect preference saved locally  
✅ **Smart Detection** - Only reconnects on unexpected disconnects (not user-initiated) using explicit flag tracking  

## How It Works

### 1. Save on Connection
```swift
// When connection succeeds
func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // Save device info to UserDefaults
    saveLastConnectedDevice(deviceId: deviceId, deviceName: deviceName)
}
```

### 2. Auto-Connect on Startup
```swift
func start() {
    // Load preference from UserDefaults
    loadAutoConnectPreference()
    
    // Try auto-connect if enabled
    if autoConnectEnabled && bluetoothState == .poweredOn {
        attemptAutoConnect()
    }
}
```

### 3. Auto-Reconnect on Disconnect
```swift
func centralManager(_ central: CBCentralManager, 
                   didDisconnectPeripheral peripheral: CBPeripheral, 
                   error: Error?) {
    if let error = error {
        // Unexpected disconnect - attempt reconnect
        if autoConnectEnabled {
            attemptReconnect()  // 3 attempts with 2s delays
        }
    } else {
        // User-initiated - don't reconnect
    }
}
```

## What Was Implemented

### iOS Native (Swift)

#### BLEService.swift (Added 150+ lines)

**Auto-Connection State:**
```swift
private var autoConnectEnabled = true
private var reconnectAttempts = 0  // Counter (unlimited)
private let reconnectDelay: TimeInterval = 10.0  // Fixed 10s delay
private var reconnectTimer: Timer?
private var isReconnecting = false
```

**UserDefaults Keys:**
```swift
private let lastDeviceIdKey = "LastConnectedDeviceId"
private let lastDeviceNameKey = "LastConnectedDeviceName"
private let autoConnectEnabledKey = "AutoConnectEnabled"
```

**Auto-Connection Methods:**
```swift
setAutoConnectEnabled(_ enabled: Bool)
isAutoConnectEnabled() -> Bool
getLastConnectedDeviceId() -> String?
getLastConnectedDeviceName() -> String?
clearLastConnectedDevice()
private attemptAutoConnect()
private attemptReconnect()
```

**Key Logic:**
- Saves device info on successful connection
- Loads and attempts auto-connect on app start
- Detects unexpected vs user-initiated disconnects
- Attempts reconnection 3 times with 2-second delays
- Resets attempts counter on successful connection

### Flutter/Dart Integration

#### ios_ble_scanner.dart (Added Methods)

```dart
static Future<bool> setAutoConnectEnabled(bool enabled)
static Future<bool> isAutoConnectEnabled()
static Future<Map<String, String>?> getLastConnectedDevice()
static Future<bool> clearLastConnectedDevice()
static Future<int> getReconnectAttemptCount()
static Future<bool> isReconnecting()
```

#### ble_scanner_example.dart (Updated UI)

**New Features:**
- Auto-connect toggle button in app bar
- Last connected device info card
- Auto-connect status indicator
- Clear last device button

## Usage Examples

### Enable/Disable Auto-Connect

```dart
// Enable auto-connect
await IOSBLEScanner.setAutoConnectEnabled(true);

// Disable auto-connect
await IOSBLEScanner.setAutoConnectEnabled(false);

// Check if enabled
bool enabled = await IOSBLEScanner.isAutoConnectEnabled();
```

### Get Last Connected Device

```dart
final lastDevice = await IOSBLEScanner.getLastConnectedDevice();

if (lastDevice != null) {
  print('Last device: ${lastDevice['name']}');
  print('Device ID: ${lastDevice['id']}');
} else {
  print('No previously connected device');
}
```

### Clear Last Device

```dart
// Clear saved device (stops auto-connect)
await IOSBLEScanner.clearLastConnectedDevice();
```

### Check Auto-Connect Status

```dart
// Check if auto-connect will happen
bool enabled = await IOSBLEScanner.isAutoConnectEnabled();
final lastDevice = await IOSBLEScanner.getLastConnectedDevice();

if (enabled && lastDevice != null) {
  print('Will auto-connect to: ${lastDevice['name']}');
} else {
  print('Auto-connect disabled or no device saved');
}
```

## Auto-Connection Flow

### On App Startup

```
App Launches
    ↓
BLE Service starts
    ↓
Load auto-connect preference ✅
    ↓
Check if enabled? → No → Done
    ↓ Yes
Check Bluetooth ON? → No → Wait for BT ON
    ↓ Yes
Get last device ID
    ↓
Attempt connection
    ↓
Success: Connected!
Fail: Log error, don't retry
```

### On Unexpected Disconnect

```
Device Disconnects
    ↓
Error present? → No (user disconnect) → Done
    ↓ Yes (unexpected)
Auto-connect enabled? → No → Done
    ↓ Yes
Start Reconnect Attempt #1
    Wait 10 seconds
    ↓
Attempt connection
    ↓
Success? → Yes → Done (reset attempts)
    ↓ No
Attempt #2... → Wait 10s → Try again
    ↓
Success? → Yes → Done
    ↓ No
Attempt #3, #4, #5... → Wait 10s → Keeps trying FOREVER
    ↓
Until: Connected, Auto-connect disabled, or Bluetooth OFF
```

## Reconnection Behavior

### User-Initiated Disconnect
```
User taps "Disconnect" button
    ↓
disconnect() called
    ↓
No error in didDisconnect
    ↓
Auto-reconnect: ❌ NOT triggered
```

### Unexpected Disconnect
```
Device goes out of range
    ↓
Bluetooth connection lost
    ↓
Error in didDisconnect
    ↓
Auto-reconnect: ✅ TRIGGERED
    ↓
3 attempts with 2s delays
```

### Bluetooth Turned Off
```
User disables Bluetooth
    ↓
centralManagerDidUpdateState: poweredOff
    ↓
Auto-reconnect: ❌ NOT triggered
    ↓
When Bluetooth ON:
    ↓
Auto-connect: ✅ TRIGGERED (if enabled)
```

## Console Logs

### App Startup with Auto-Connect
```
[BackendLogging] BLE Service started
[BackendLogging] Auto-connect preference loaded: true
[BackendLogging] Attempting auto-connect to last device: Leo Usb-ABC123
[BackendLogging] Auto-connecting to 12345678-1234-...
[BackendLogging] Connected to Leo Usb-ABC123
```

### Unexpected Disconnect & Reconnect
```
[BackendLogging] Disconnected from Leo Usb-ABC123: Connection timeout
[BackendLogging] Unexpected disconnect, attempting reconnect...
[BackendLogging] Reconnect attempt 1/3 to 12345678-1234-...
[BackendLogging] Attempt 1 to 12345678-1234-...
// Wait 2 seconds...
[BackendLogging] Auto-connecting to 12345678-1234-...
[BackendLogging] Connected to Leo Usb-ABC123
```

### Fixed 10-Second Delay Attempts
```
[BackendLogging] Reconnect attempt #1 to Leo Usb-ABC123 (waiting 10s)
// Wait 10 seconds...
[BackendLogging] Reconnect attempt #1 failed: Connection timeout

[BackendLogging] Reconnect attempt #2 to Leo Usb-ABC123 (waiting 10s)
// Wait 10 seconds...
[BackendLogging] Reconnect attempt #2 failed: Connection timeout

[BackendLogging] Reconnect attempt #3 to Leo Usb-ABC123 (waiting 10s)
// Wait 10 seconds...
[BackendLogging] Connected to Leo Usb-ABC123 ✅
```

### Stopping Reconnection
```
// User disables auto-connect
[BackendLogging] Auto-connect disabled
[BackendLogging] Stopped all reconnection attempts

// OR Bluetooth turned off
[BackendLogging] Cannot reconnect: Bluetooth is POWERED_OFF

// OR Connection succeeds
[BackendLogging] Connected to Leo Usb-ABC123
[BackendLogging] Already connected, stopping reconnection
```

## Configuration

### Adjust Reconnect Delay
```swift
// In BLEService.swift
private let reconnectDelay: TimeInterval = 15.0  // Change from 10s to 15s
```

### Change Default Auto-Connect State
```swift
// In BLEService.swift
private var autoConnectEnabled = false  // Disabled by default
```

## UI Features

### App Bar Toggle Button
- Tap autorenew icon to toggle auto-connect
- Icon changes: 🔄 (enabled) ↔️ 🚫 (disabled)
- Tooltip shows current state

### Auto-Connect Info Card
Appears when auto-connect is enabled and device is saved:

```
┌─────────────────────────────────────┐
│ 🔄 Auto-connect enabled             │
│    Last device: Leo Usb-ABC123   ✕  │
└─────────────────────────────────────┘
```

- Shows last connected device name
- Tap ✕ to clear last device

## Best Practices

### 1. Let Users Control Auto-Connect
```dart
// Give users a toggle in settings
Widget buildAutoConnectSetting() {
  return SwitchListTile(
    title: Text('Auto-connect'),
    subtitle: Text('Automatically reconnect to last device'),
    value: _autoConnectEnabled,
    onChanged: (value) async {
      await IOSBLEScanner.setAutoConnectEnabled(value);
      setState(() => _autoConnectEnabled = value);
    },
  );
}
```

### 2. Show Last Device Info
```dart
final lastDevice = await IOSBLEScanner.getLastConnectedDevice();
if (lastDevice != null) {
  print('Will auto-connect to: ${lastDevice['name']}');
}
```

### 3. Clear on Logout/Reset
```dart
Future<void> logout() async {
  // Clear all saved data including last device
  await IOSBLEScanner.clearLastConnectedDevice();
  await IOSBLEScanner.disconnectFromDevice();
}
```

### 4. Handle Connection Failures Gracefully
```dart
// Auto-connect may fail, handle it
final connected = await IOSBLEScanner.isConnected();
if (!connected) {
  showMessage('Auto-connect failed. Please connect manually.');
}
```

## Error Scenarios

### Device Not in Range
```
Auto-connect attempts → Timeout after 10s
Reconnect attempt #1 → Timeout after 10s, wait 2s
Reconnect attempt #2 → Timeout after 10s, wait 2s
Reconnect attempt #3 → Timeout after 10s, wait 2s
Reconnect attempt #4... → Continues indefinitely
Device comes in range → Connected!
```

### Bluetooth Disabled
```
Auto-connect attempts → Error: Bluetooth is POWERED_OFF
Does not retry → Waits for Bluetooth to be enabled
```

### Device No Longer Exists
```
Auto-connect attempts → Error: Device not found
Does not retry → User must scan again
```

## Testing

### Test Auto-Connect on Startup
1. Connect to a device
2. Close app completely
3. Reopen app
4. Watch Xcode console for auto-connect attempts
5. Should automatically reconnect

### Test Reconnect on Disconnect
1. Connect to a device
2. Turn off the device or move out of range
3. Watch Xcode console for reconnect attempts
4. Should attempt 3 times with 2-second delays

### Test User Disconnect (No Reconnect)
1. Connect to a device
2. Tap "Disconnect" button
3. Watch Xcode console
4. Should NOT attempt to reconnect

### Test Toggle Auto-Connect
1. Disable auto-connect in UI
2. Close and reopen app
3. Should NOT auto-connect
4. Enable auto-connect
5. Should auto-connect on next startup

## Files Modified

### Updated
```
ios/Runner/BLEService.swift                (+150 lines)
ios/Runner/BackgroundServiceChannel.swift  (+4 auto-connect methods)
lib/services/ios_ble_scanner.dart          (+auto-connect methods)
lib/services/ble_scanner_example.dart      (+auto-connect UI)
```

### Created
```
BLE_AUTO_CONNECTION.md                     (this file)
```

## API Reference

### IOSBLEScanner Auto-Connect Methods

| Method | Return Type | Description |
|--------|------------|-------------|
| `setAutoConnectEnabled(enabled)` | `Future<bool>` | Enable/disable auto-connect |
| `isAutoConnectEnabled()` | `Future<bool>` | Check if auto-connect is enabled |
| `getLastConnectedDevice()` | `Future<Map<String, String>?>` | Get last device info |
| `clearLastConnectedDevice()` | `Future<bool>` | Clear saved device |

### UserDefaults Keys

| Key | Type | Description |
|-----|------|-------------|
| `LastConnectedDeviceId` | `String` | UUID of last device |
| `LastConnectedDeviceName` | `String` | Name of last device |
| `AutoConnectEnabled` | `Bool` | Auto-connect preference |

## Summary

✅ **Auto-Connection Complete**
- Saves last connected device ✅
- Auto-connects on app startup ✅
- Auto-reconnects after unexpected disconnect ✅
- **UNLIMITED reconnect attempts** with fixed 10-second delays ✅
- Enable/disable toggle (stops reconnection) ✅
- Persistent settings (UserDefaults) ✅
- Smart disconnect detection ✅
- Reconnection status tracking ✅
- Flutter integration ✅
- UI controls ✅
- Comprehensive logging ✅

**User Experience:**
- Connect once → Auto-connects forever
- Unexpected disconnect → Automatically reconnects
- User disconnect → Stays disconnected
- Toggle off → No auto-connect
- Clear device → Forgets device

**Ready for production use!** 🚀

