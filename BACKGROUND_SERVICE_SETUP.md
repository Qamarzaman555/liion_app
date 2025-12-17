# iOS Background Service - Setup Complete! ✅

## What Was Created

### iOS Native Side (Swift)

1. **BackgroundService.swift** - Main service to keep app alive
   - Uses location services for continuous background execution
   - Handles background tasks
   - Optional silent audio mode
   - Designed to work during deep sleep

2. **BackendLoggingService.swift** - Logging service
   - Logs all app state changes
   - Timestamps all events
   - Ready for backend API integration
   - Console logging enabled

3. **BackgroundServiceChannel.swift** - Flutter bridge
   - Method channel for Flutter ↔ iOS communication
   - Exposes service controls to Flutter/Dart

4. **Updated AppDelegate.swift**
   - Automatically starts services on app launch
   - Integrates method channel
   - Handles app lifecycle events

5. **Updated Info.plist**
   - Added background modes: location, fetch, processing, audio
   - Added location permission descriptions
   - Configured for background execution

### Flutter/Dart Side

1. **ios_background_service.dart** - Dart service wrapper
   - Easy-to-use API for controlling iOS service from Flutter
   - Methods for start, stop, status check, and logging

2. **background_service_example.dart** - Example UI widget
   - Complete example showing how to use the service
   - Status display
   - Control buttons
   - Test logging functionality

## Quick Start

### From Flutter/Dart Code

```dart
import 'package:liion_app/services/ios_background_service.dart';

// Start the background service
await IOSBackgroundService.startBackgroundService();

// Check if running
bool isRunning = await IOSBackgroundService.isServiceRunning();

// Get detailed status
Map<String, dynamic> status = await IOSBackgroundService.getServiceStatus();

// Send logs to native service
await IOSBackgroundService.logInfo('App event happened');
await IOSBackgroundService.logError('Something went wrong');

// Stop the service
await IOSBackgroundService.stopBackgroundService();
```

### Automatic Start

The service **automatically starts** when the app launches (configured in AppDelegate).

No manual initialization needed unless you want to stop/restart it.

## How It Works

### 🎯 Primary Method: Location Services

The service uses iOS location services to stay alive:

- **Low accuracy** (kCLLocationAccuracyKilometer) - saves battery
- **Significant location changes** - updates every ~500 meters
- **Always allow permission required** - user must grant "Always Allow"
- **Works during deep sleep** - iOS maintains location services even when device sleeps

### 📝 Logging

All app events are logged:
- App state changes (foreground/background)
- Service start/stop events
- Location updates
- Custom logs from your Flutter code

### 🔋 Battery Optimization

Configured for minimal battery impact:
- Low accuracy location
- Significant change monitoring (not continuous)
- Efficient background task management

## Testing Steps

### 1. Build and Run on Physical Device

```bash
cd /Users/qamarzaman/StudioProjects/liion_app
flutter run -d <your-iphone-device-id>
```

⚠️ **Physical device required** - iOS simulators don't accurately simulate background behavior.

### 2. Grant Location Permission

When prompted:
- Choose **"Allow While Using App"** first
- Then go to Settings → Your App → Location
- Change to **"Always"**

### 3. Test Background Execution

1. Open the app
2. Check Xcode console for logs like:
   ```
   [2024-12-18 10:30:00.123] [INFO] BackgroundService started
   [2024-12-18 10:30:00.456] [INFO] Location updates started
   ```
3. Put app in background (home button/swipe up)
4. Wait 5-10 minutes
5. Check Xcode console for continued logging
6. Verify location updates appearing

### 4. Test Deep Sleep

1. Lock device screen
2. Wait 30+ minutes
3. Unlock and check Xcode console
4. Should see continuous location updates

## App Store Submission

### ⚠️ Important for Review

When submitting to App Store, Apple will ask:

**"Why does your app need background location?"**

You MUST have a valid reason:
- ✅ Fitness/health tracking
- ✅ Delivery/transportation services
- ✅ Real-time location sharing
- ✅ Navigation applications
- ❌ Generic "to keep app alive" - WILL BE REJECTED

### Privacy Policy Requirements

Your app must include:
1. Clear explanation of location usage
2. What data is collected
3. How it's used
4. Data retention policy
5. User control options

### Background Mode Justification

In App Store Connect, you'll need to explain:
- **Location**: "Tracks user location for [your specific purpose]"
- **Audio**: Only if you enable silent audio (not recommended without justification)
- **Fetch**: "Updates data in background for [your specific purpose]"

## Configuration & Customization

### Adjust Location Update Frequency

Edit `BackgroundService.swift`:

```swift
// Update every 1km instead of 500m (more battery efficient)
locationManager?.distanceFilter = 1000

// Use even lower accuracy (better battery)
locationManager?.desiredAccuracy = kCLLocationAccuracyThreeKilometers
```

### Enable Silent Audio (Use with Caution)

In `BackgroundService.swift`, uncomment in `start()` method:

```swift
// Uncomment this line:
setupSilentAudio()
```

⚠️ Requires `silence.mp3` file in app bundle
⚠️ May be rejected by App Store without valid justification

### Add Backend API Integration

Edit `BackendLoggingService.swift`, implement `sendToBackend`:

```swift
private func sendToBackend(message: String, level: LogLevel) {
    let url = URL(string: "https://your-api.com/api/logs")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload: [String: Any] = [
        "message": message,
        "level": level.rawValue,
        "timestamp": Date().timeIntervalSince1970
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Backend log failed: \(error)")
        }
    }.resume()
}
```

## Monitoring & Debugging

### View Logs in Xcode

1. Run app from Xcode
2. Open Debug Navigator (⌘+7)
3. View console output
4. Filter by "[INFO]", "[ERROR]", etc.

### Monitor Battery Usage

1. Xcode → Debug Navigator → Energy
2. Watch for spikes in location usage
3. Optimize if needed

### Check Background Time Remaining

The status includes `backgroundTimeRemaining`:
- Usually ~30 seconds for normal background tasks
- Unlimited with location services active
- Monitor this value to ensure service is working

## Troubleshooting

### App Gets Killed in Background

**Solution:**
- Ensure location permission is "Always"
- Verify background modes in Info.plist
- Check device location services are enabled
- Test on physical device, not simulator

### High Battery Drain

**Solution:**
- Increase `distanceFilter` value
- Use lower accuracy setting
- Consider using only significant location changes

### Location Permission Denied

**Solution:**
- Show custom permission request UI
- Explain why location is needed
- Direct user to Settings to change permission

### Service Not Starting

**Solution:**
- Check Xcode console for errors
- Verify `GeneratedPluginRegistrant.register` is called
- Ensure physical device is used for testing

## Files Created

```
ios/Runner/
├── BackgroundService.swift          (Main service)
├── BackendLoggingService.swift      (Logging service)
├── BackgroundServiceChannel.swift   (Flutter bridge)
├── AppDelegate.swift                (Updated)
├── Info.plist                       (Updated)
└── BackgroundServiceReadme.md       (Detailed documentation)

lib/services/
├── ios_background_service.dart      (Dart wrapper)
└── background_service_example.dart  (Example UI)
```

## Next Steps

- [ ] Test on physical iOS device
- [ ] Grant "Always Allow" location permission
- [ ] Verify background execution (leave running for 1+ hour)
- [ ] Implement backend API in `BackendLoggingService`
- [ ] Test battery impact over 24 hours
- [ ] Prepare App Store review justification
- [ ] Update privacy policy with location usage explanation
- [ ] Add user-facing UI to control service (optional)

## Support & Documentation

For detailed information, see:
- `ios/Runner/BackgroundServiceReadme.md` - Complete iOS documentation
- Apple's [Background Execution Guide](https://developer.apple.com/documentation/backgroundtasks)
- Apple's [Core Location Guide](https://developer.apple.com/documentation/corelocation)

---

**Status:** ✅ Ready to test on physical device

**Auto-Start:** ✅ Enabled in AppDelegate

**Location Permission:** ⚠️ Requires user to grant "Always Allow"

**Flutter Integration:** ✅ Method channel bridge ready

**Backend Logging:** 🔧 Ready for your API implementation

