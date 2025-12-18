# iOS Xcode Setup - Fix Missing Swift Files

## Problem
```
Cannot find 'BackgroundService' in scope
Cannot find 'BackendLoggingService' in scope
Cannot find 'BLEService' in scope
Cannot find 'BackgroundServiceChannel' in scope
```

## Solution: Add Swift Files to Xcode Project

### Quick Fix (Recommended)

1. **Open Xcode workspace:**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **In Xcode, right-click on "Runner" folder** (in the left sidebar)

3. **Select: "Add Files to Runner..."**

4. **Navigate to the `Runner` folder and select these files:**
   - ✅ `BackgroundService.swift`
   - ✅ `BackendLoggingService.swift`
   - ✅ `BLEService.swift`
   - ✅ `BackgroundServiceChannel.swift`

5. **IMPORTANT: Make sure these options are checked:**
   - ✅ "Copy items if needed" (UNCHECK this - files are already there)
   - ✅ "Create groups" (SELECT this)
   - ✅ "Add to targets: Runner" (CHECK this!)

6. **Click "Add"**

7. **Clean and rebuild:**
   - Menu: Product → Clean Build Folder (Cmd+Shift+K)
   - Menu: Product → Build (Cmd+B)

### Alternative: Remove and Re-add Files

If files are already in the project but still showing errors:

1. **In Xcode left sidebar, find each Swift file**

2. **Right-click each file → Delete**
   - Select "Remove Reference" (NOT "Move to Trash")

3. **Follow steps above to add them back**

4. **Verify in "Build Phases":**
   - Click on "Runner" target
   - Go to "Build Phases" tab
   - Expand "Compile Sources"
   - Make sure all 4 Swift files are listed:
     ```
     BackgroundService.swift
     BackendLoggingService.swift
     BLEService.swift
     BackgroundServiceChannel.swift
     AppDelegate.swift
     ```

### Verify Files are Added

After adding, you should see in Xcode:

```
Runner/
├── Runner/
│   ├── AppDelegate.swift
│   ├── BackgroundService.swift           ✅ Added
│   ├── BackendLoggingService.swift      ✅ Added
│   ├── BLEService.swift                 ✅ Added
│   ├── BackgroundServiceChannel.swift   ✅ Added
│   └── Assets.xcassets/
```

### If Still Not Working

1. **Check Swift Compiler settings:**
   - Select "Runner" target
   - Build Settings tab
   - Search for "Swift Compiler"
   - Make sure "Swift Language Version" is set (Swift 5.0)

2. **Check target membership:**
   - Select each Swift file
   - In right sidebar, check "Target Membership"
   - Make sure "Runner" is checked ✅

3. **Clean derived data:**
   ```bash
   cd ios
   rm -rf ~/Library/Developer/Xcode/DerivedData
   pod deintegrate
   pod install
   ```

4. **Rebuild:**
   - Open Runner.xcworkspace
   - Product → Clean Build Folder
   - Product → Build

## Expected Result

After adding files correctly, no more errors:
```
✅ BackgroundService.shared
✅ BackendLoggingService.shared
✅ BLEService.shared
✅ BackgroundServiceChannel()
```

## Quick Command Line Alternative

If you prefer command line, you can try regenerating the project:

```bash
cd ios
rm -rf Pods Podfile.lock
pod install

# Then open in Xcode and add the files manually
open Runner.xcworkspace
```

## Troubleshooting

### Error: "Module compiled with Swift X cannot be imported by Swift Y"
- Clean build folder
- Delete derived data
- Rebuild

### Error: "No such module 'Flutter'"
- Make sure you opened `Runner.xcworkspace` NOT `Runner.xcodeproj`
- Run `pod install` first

### Files show up gray/dimmed in Xcode
- They're not added to the target
- Follow the "Add Files to Runner" steps above

## Summary

**The Swift files exist on disk but aren't registered in the Xcode project.**

You must open Xcode and manually add them to the "Runner" target. This is a one-time setup required for the iOS native services to work.

Once added, the iOS app will compile and run successfully! 🎉

