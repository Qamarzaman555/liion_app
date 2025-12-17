# iOS Background Service Implementation

## Overview
This implementation provides iOS native services to keep your app alive in the background, similar to Android's foreground services.

## Components

### 1. BackgroundService.swift
Main service that keeps the app alive using multiple strategies:
- **Location Services** (Primary method - most reliable)
- **Background Tasks**
- **Silent Audio** (Optional - use with caution)

### 2. BackendLoggingService.swift
Handles logging to backend and console:
- Logs app state changes
- Logs background task execution
- Timestamp formatting
- Ready for backend API integration

### 3. Updated Files
- **Info.plist**: Added background modes and location permissions
- **AppDelegate.swift**: Integrated services on app launch

## Background Modes Enabled

In `Info.plist`, the following background modes are enabled:
- `location` - For continuous location updates
- `fetch` - For background fetch
- `processing` - For background processing tasks
- `audio` - For silent audio (optional)

## How It Works

### Location-Based Background Execution
The service uses **location updates** to keep the app alive:
- Uses significant location changes (battery efficient)
- Low accuracy (kCLLocationAccuracyKilometer) to save battery
- Updates every 500 meters
- Works during deep sleep

### Key Features
1. **Always Running**: Configured to run continuously in background
2. **Battery Efficient**: Uses low-accuracy location updates
3. **Deep Sleep Compatible**: Works even when device is in deep sleep
4. **Logging**: Comprehensive logging of all app states
5. **Backend Ready**: Placeholder for backend API integration

## Usage

The services start automatically when the app launches (configured in AppDelegate).

### Manual Control (if needed)
```swift
// Start services
BackgroundService.shared.start()
BackendLoggingService.shared.start()

// Stop services
BackgroundService.shared.stop()
BackendLoggingService.shared.stop()

// Check status
let status = BackgroundService.shared.getServiceStatus()
print(status)

// Log messages
BackendLoggingService.shared.log("Your message", level: .info)
```

## Important Notes

### Location Permissions
Users will be prompted for location permissions. The app needs **"Always Allow"** location access to work in background.

### Battery Impact
Location-based background execution does consume battery, but the implementation is optimized:
- Low accuracy (kCLLocationAccuracyKilometer)
- Significant location changes only
- 500-meter distance filter

### App Store Compliance

⚠️ **IMPORTANT**: When submitting to App Store:
1. You **must** have a valid reason for background location
2. Apple will review your use case
3. Be prepared to explain why your app needs to run continuously
4. The silent audio method (currently commented out) may be rejected if not justified

### Silent Audio (Optional)
The `BackgroundService` includes a silent audio method (currently disabled):
- Uncomment `setupSilentAudio()` in the `start()` method to enable
- Requires a silent audio file named `silence.mp3` in the app bundle
- ⚠️ May be rejected by App Store if not justified

## Testing

### Test Background Execution
1. Run the app on a physical device (simulators have limitations)
2. Grant "Always Allow" location permissions
3. Put app in background
4. Wait several minutes
5. Check console logs or backend logs to verify service is running

### Monitor in Xcode
- Use Xcode's Debug Navigator to monitor:
  - CPU usage
  - Memory usage
  - Energy impact
  - Location updates

## Troubleshooting

### App Gets Killed
- Ensure location permissions are set to "Always Allow"
- Check that background modes are enabled in capabilities
- Verify device has location services enabled
- Physical device required for accurate testing

### High Battery Usage
- Adjust `distanceFilter` in BackgroundService (increase value)
- Change `desiredAccuracy` to lower accuracy
- Consider using significant location changes only

### Location Permission Denied
- App will not work properly without location permissions
- Consider showing a custom permission request UI
- Explain to users why location is needed

## Backend Integration

To integrate with your backend API:

1. Open `BackendLoggingService.swift`
2. Find the `sendToBackend` method
3. Implement your API call:

```swift
private func sendToBackend(message: String, level: LogLevel) {
    let url = URL(string: "https://your-api.com/logs")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload: [String: Any] = [
        "message": message,
        "level": level.rawValue,
        "timestamp": Date().timeIntervalSince1970,
        "device": UIDevice.current.model
    ]
    
    request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
    
    URLSession.shared.dataTask(with: request).resume()
}
```

## Configuration Options

### Adjust Location Updates
In `BackgroundService.swift`, modify:

```swift
// Update frequency (meters)
locationManager?.distanceFilter = 500

// Accuracy level
locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer

// Show blue bar indicator
locationManager?.showsBackgroundLocationIndicator = true
```

### Adjust Logging
In `BackendLoggingService.swift`, modify:

```swift
// Enable/disable logging
private var loggingEnabled: Bool = true

// Change date format
dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
```

## License Compliance

When using background location, ensure your app's privacy policy clearly states:
- Why location data is collected
- How it's used
- That it runs in background
- Data retention policies

## Next Steps

1. ✅ Services are configured and ready
2. ⏳ Test on physical device with "Always Allow" location permission
3. ⏳ Implement backend API in `BackendLoggingService.sendToBackend()`
4. ⏳ Monitor battery usage and optimize if needed
5. ⏳ Prepare App Store review explanation for background location usage

## Contact & Support

For issues or questions, refer to Apple's documentation:
- [Background Execution](https://developer.apple.com/documentation/backgroundtasks)
- [Core Location](https://developer.apple.com/documentation/corelocation)
- [Location and Maps Programming Guide](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/LocationAwarenessPG/)

