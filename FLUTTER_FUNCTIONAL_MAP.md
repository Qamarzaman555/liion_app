# Flutter/Dart Functional Map — Liion Power App

This document maps every major feature on the Flutter side to the code that supports it: controllers (streams, method channels, timers, UI), services, core, routes, and graph/OTA/Hive usage.

---

## 1. Application entry and core

### `lib/main.dart`
- **Firebase**: `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
- **Hive**: `Hive.initFlutter()` and `Hive.registerAdapter(GraphValuesDataHiveAdapter())` for graph persistence.
- **Android**: `_requestPermissionsAndStartService()` — requests BLE (bluetoothScan, bluetoothConnect, notification; location only for API ≤30), then `BleScanService.startService()`, then `_checkBatteryOptimization()` (delay 2s, then `BleScanService.isBatteryOptimizationDisabled()` / `requestDisableBatteryOptimization()`).
- **Routing**: `GetMaterialApp(initialRoute: AppPages.initial, getPages: AppPages.routes)`.

### `lib/app/core/`
- **ota_package.dart**: `OtaPackage` abstract class and `Esp32OtaPackage` — BLE-based OTA (write MTU, control/data characteristics, chunked firmware from file/URL/picker). Used for in-app OTA logic; actual OTA from UI goes through Kotlin service via `BleScanService`.
- **constants**: `AppAssets` (SVG/PNG paths), `AppColors`, `AppTexts` (feedback text, first-time thank-you note).
- **utils/snackbar_utils.dart**: `AppSnackbars.showSuccess(title, message)`.
- **widgets**: `CustomButton`, `CustomSwitch`.

---

## 2. BLE service (Dart wrapper) — `lib/app/services/ble_scan_service.dart`

Single bridge to the Kotlin BLE foreground service via **MethodChannel** `com.liion_app/ble_service` and multiple **EventChannels** for streams.

### Method channel calls (when used)
- **Service**: `startService`, `stopService`, `rescan`, `isBluetoothEnabled`, `getAdapterState`, `requestEnableBluetooth`.
- **Connection**: `connect`, `disconnect`, `isConnected`, `getConnectionState`, `getConnectedDeviceAddress`.
- **Commands**: `sendCommand`.
- **LED**: `getLedTimeout`, `requestLedTimeout`, `setLedTimeout`.
- **Advanced modes**: `getAdvancedModes`, `setGhostMode`, `setSilentMode`, `setHigherChargeLimit`, `requestAdvancedModes`.
- **Phone battery**: `getPhoneBattery`.
- **Charge limit**: `setChargeLimit`, `getChargeLimit`, `setChargeLimitEnabled`.
- **Battery optimization**: `isBatteryOptimizationDisabled`, `requestDisableBatteryOptimization`.
- **Battery health**: `getBatteryHealthInfo`, `startBatteryHealthCalculation`, `stopBatteryHealthCalculation`, `resetBatteryHealthReadings`.
- **Battery sessions**: `getBatterySessionHistory`, `clearBatterySessionHistory`.
- **OTA**: `startOtaUpdate`, `cancelOtaUpdate`, `getOtaProgress`, `isOtaUpdateInProgress`.
- **Devices**: `getScannedDevices`, `isServiceRunning`.
- **App**: `minimizeApp`.
- **Permissions**: no method channel; uses Dart `Permission` + `checkPermissionsAndStartService`, `requestPermissionsIfNeeded`, `arePermissionsGranted`.

### Event channels and streams
- `com.liion_app/ble_devices` → **deviceStream** (scanned devices).
- `com.liion_app/ble_connection` → **connectionStream** (state + address).
- `com.liion_app/adapter_state` → **adapterStateStream** (int).
- `com.liion_app/data_received` → **dataReceivedStream** (String — UART from Leo).
- `com.liion_app/phone_battery` → **phoneBatteryStream** (`PhoneBatteryInfo`).
- `com.liion_app/charge_limit` → **chargeLimitStream** (`ChargeLimitInfo`).
- `com.liion_app/led_timeout` → **ledTimeoutStream** (int seconds).
- `com.liion_app/advanced_modes` → **advancedModesStream** (`AdvancedModes`: ghost, silent, higherChargeLimit).
- `com.liion_app/battery_health` → **batteryHealthStream** (`BatteryHealthInfo`).
- `com.liion_app/measure_data` → **measureDataStream** (`MeasureData`: voltage, current).
- `com.liion_app/battery_metrics` → **batteryMetricsStream** (`BatteryMetrics`: current, voltage, temperature, accumulatedMah, chargingTimeSeconds, dischargingTimeSeconds).
- `com.liion_app/ota_progress` → **otaProgressStream** (progress %, inProgress, message).

### Data classes
- `BleConnectionState`, `BleAdapterState`, `PhoneBatteryInfo`, `ChargeLimitInfo`, `AdvancedModes`, `BatteryHealthInfo`, `MeasureData`, `BatteryMetrics`.

---

## 3. Routes and navigation

### `lib/app/routes/app_routes.dart`
- `splash`, `navBarView`, `setChargeLimitView`, `feedbackView`, `aboutView`, `advanceSettings`, `leoTroubleshoot`, `leoManual`, `batteryHistoryView`, `ledTimeout`.

### `lib/app/routes/app_pages.dart`
- **Initial**: `AppRoutes.splash` → `SplashView` + `SplashBinding`.
- **Main shell**: `AppRoutes.navBarView` → `BottomNavBarView` + `BottomNavBarBinding` (injects BottomNavBar, LedTimeout, LeoHome, Battery, Settings, ChargeLimit).
- **Other pages**: ChargeLimit, Feedback, About, AdvancedSettings, LeoTroubleshoot, Manual, BatteryHistory; each with its binding.
- **Note**: `ledTimeout` is defined in `AppRoutes` but has no `GetPage` in the list; LED timeout UI is reached from Settings/Advanced settings, not as a top-level route.

---

## 4. Controllers (streams, method channel usage, timers, UI, features)

### SplashController (`lib/app/modules/splash/controllers/splash_controller.dart`)
- **Streams**: None.
- **Method channel**: None (no direct BLE calls).
- **Timers**: `Future.delayed(3 seconds)` then `Get.offAllNamed(AppRoutes.navBarView)`.
- **UI**: Splash view with 2s animation (AnimationController + Tween).
- **Features**: App startup splash and automatic navigation to bottom nav.

---

### LeoHomeController (`lib/app/modules/leo_empty/controllers/leo_home_controller.dart`)
- **Streams**:
  - **adapterStateStream**: adapter on/off; on “on” calls `_loadDevices()`; on “off” clears `scannedDevices`.
  - **deviceStream**: new devices appended to `scannedDevices`.
  - **connectionStream**: updates `connectionState`, `connectedDeviceAddress`, `connectingDeviceAddress`; on connect: sets `hasConnectedOnce`, dismisses thank-you note, and after 5s delay calls `requestLeoFirmwareVersion()`; runs `_scheduleInitialRequests()` (LED timeout, mwh, firmware version, chmode).
  - **dataReceivedStream**: raw UART → `lastReceivedData`, `receivedDataLog`; parsed for mwh, swversion, measure (voltage/current/power, charging mode, graph sample), chmode.
  - **measureDataStream**: voltage/current strings → `voltageValue`, `currentValue`, `_updatePower`, and (in parsing) graph sample.
  - **advancedModesStream**: ghost/silent/higherChargeLimit → `advancedGhostModeEnabled`, etc.
- **Method channel (via BleScanService)**: `getAdapterState`, `getConnectionState`, `getConnectedDeviceAddress`, `getAdvancedModes`, `requestEnableBluetooth`, `getScannedDevices`, `isServiceRunning`, `sendCommand` (mwh, measure, swversion, chmode, serial, advanced modes, LED timeout), `connect`, `disconnect`, `rescan`.
- **Timers**: `_graphInactivityTimer` (declared but not started in the read code; used in `finalizeCurrentGraphSession`). Serialized command chain via `_commandSerial` with delays (300–400 ms) between BLE requests.
- **UI**: Leo home tab: connection buttons, thank-you note, metrics summary (current/voltage/power, mode, reset, current charge graph). Drives `LeoMetricsSummary`, `ChargeGraphWidget`, connection dialogs, firmware update entry.
- **Features**: Connection and scan, device list, connect/disconnect, data parsing (mWh, firmware version, measure/chmode), live graph from measure data, graph persistence (Hive), charging mode display/update, advanced modes sync, LED timeout request on connect, firmware version check at start (Firebase download in `downloadFirmwareAtStart()`).

---

### LeoOtaController (`lib/app/modules/leo_empty/controllers/leo_ota_controller.dart`)
- **Streams**:
  - **otaProgressStream**: progress %, inProgress, message → `otaProgress`, `isOtaInProgress`, `otaMessage`, packet numbers; at 100% calls `startInstallTimer()`; on failure message calls `_handleOtaFailure`.
  - **connectionStream**: detects reconnection after OTA; when reconnected and `_wasOtaCompleted` (and timer/wait state), cancels timer and sets `shouldShowDoneDialog`.
- **Method channel**: `getConnectionState`, `getOtaProgress`, `isOtaUpdateInProgress`, `startOtaUpdate`, `cancelOtaUpdate`.
- **Timers**: `_installTimer`: 60s countdown after OTA 100%; when it hits 0 or on reconnection, closes wait dialog and shows done dialog. `_progressPollingTimer`: 500 ms backup polling for progress and 100% completion.
- **UI**: OTA progress dialog, wait-for-install dialog, done dialog (triggered by `shouldShowDoneDialog`).
- **Features**: OTA from file path (cloud or local), progress display, wake lock, install timer, reconnection detection and done dialog.

---

### LeoEmptyController (`lib/app/modules/leo_empty/controllers/leo_empty_controller.dart`)
- **Empty**: File is effectively empty; no streams, channels, or timers. Leo home logic lives in `LeoHomeController`.

---

### BatteryController (`lib/app/modules/battery/controllers/battery_controller.dart`)
- **Streams**:
  - **phoneBatteryStream**: level and isCharging → `phoneBatteryLevel`, `isPhoneCharging`; on charging state change resets `accumulatedMah`.
  - **batteryHealthStream**: → `_updateHealthInfo` (designedCapacityMah, estimatedCapacityMah, batteryHealthPercent, calculationInProgress, etc.).
  - **batteryMetricsStream**: current, voltage, temperature, accumulatedMah, chargingTimeSeconds, dischargingTimeSeconds.
- **Method channel**: `getPhoneBattery`, `getBatteryHealthInfo`, `startBatteryHealthCalculation`, `stopBatteryHealthCalculation`, `resetBatteryHealthReadings`.
- **Timers**: None.
- **UI**: Battery tab: header (phone battery), Set Charge Limit button, `BatteryMetricsCard`, View Battery History button.
- **Features**: Phone battery level/charging, live battery metrics, battery health and health calculation control.

---

### ChargeLimitController (`lib/app/modules/battery/charge_limit/controllers/charge_limit_controller.dart`)
- **Streams**:
  - **chargeLimitStream**: limit, enabled, confirmed → `chargeLimit`, `chargeLimitEnabled`, `chargeLimitConfirmed`.
  - **connectionStream**: connection state → `isConnected`.
- **Method channel**: `getChargeLimit`, `getConnectionState`, `setChargeLimit`, `setChargeLimitEnabled`.
- **Timers**: None.
- **UI**: Charge limit screen: slider, text field, enable toggle, save. Used from Battery tab “Set Charge Limit”.
- **Features**: Charge limit in foreground/background/deep sleep is enforced by the Kotlin service; this controller only reflects and updates limit/enabled/confirmed via BLE and stream.

---

### LeoOtaController (see above)
- **Features**: OTA from cloud (Firebase) and from local file; progress and done/wait dialogs.

---

### FeedbackController (`lib/app/modules/feedback/controllers/feedback_controller.dart`)
- **Streams**: **dataReceivedStream**: parses “serial” response and stores serial in SharedPreferences.
- **Method channel**: None directly; uses `LeoHomeController.sendCommand('serial')`, `sendCommand('swversion')`, and `BleScanService.isConnected()` when submitting feedback.
- **Timers**: `Future.delayed(500)` after serial/swversion before sending email.
- **UI**: Feedback form (text + email), submit, thanks dialog.
- **Features**: Anonymous feedback; sends email (Gmail SMTP) with app version, Leo serial/firmware, device history from SharedPreferences; stores serial and device history for support.

---

### ManualController (`lib/app/modules/manual/controllers/manual_controller.dart`)
- **Streams**: None.
- **Method channel**: None.
- **Timers**: None.
- **UI**: Manual view with PDF viewer; shows cached path or downloads from `https://liionpower.nl/manual.pdf` (Dio), uses temp file then rename.
- **Features**: PDF manual with offline cache and online refresh.

---

### SplashController (see above)
- **Features**: Startup animation and navigate to main app.

---

### BottomNavBarController (`lib/app/modules/bottom_nav_bar/controllers/bottom_nav_bar_controller.dart`)
- **Streams**: None.
- **Method channel**: None (back press uses `BleScanService.minimizeApp()` from view).
- **UI**: Bottom nav (Leo, Phone, Settings); body is `LeoHomeView`, `BatteryView`, or `SettingsView`.
- **Features**: Tab switching; back on non-Leo tab goes to Leo, on Leo tab minimizes app.

---

### AdvancedSettingsController (`lib/app/modules/advanced_settings/controllers/advanced_settings_controller.dart`)
- **Streams**: None (reads/writes LeoHomeController observables and uses one-off BLE request).
- **Method channel**: `requestAdvancedModes` on init; `setGhostMode`, `setSilentMode`, `setHigherChargeLimit` on toggle.
- **UI**: Advanced settings screen: Ghost mode, Silent mode, Higher charge limit toggles; may host LED timeout (separate widget).
- **Features**: Ghost / Silent / Higher charge limit toggles; depends on `LeoHomeController` and BLE service.

---

### LedTimeoutController (`lib/app/modules/led_timeout/controllers/led_timeout_controller.dart`)
- **Streams**: None (no subscription to `ledTimeoutStream`; only method channel get/set).
- **Method channel**: `getLedTimeout`, `requestLedTimeout`, `setLedTimeout`.
- **Timers**: None.
- **UI**: LED timeout view: text field + validation (0–99999 s), load/save from service.
- **Features**: Read/write LED timeout (seconds) to device via BLE service; used from Settings/Advanced settings (no dedicated route in `AppPages`).

---

### AboutController (`lib/app/modules/about/controllers/about_controller.dart`)
- **Streams**: None.
- **Method channel**: `isConnected`; reads `LeoHomeController.binFileFromLeoName` when connected.
- **UI**: About view: app name, package, version, build; connection status and Leo firmware version.
- **Features**: App and Leo version info.

---

### SettingsController (`lib/app/modules/settings/controllers/settings_controller.dart`)
- **Streams**: None.
- **Method channel**: None.
- **UI**: Settings view: FAQ link (url_launcher), update from Play Store link.
- **Features**: Open FAQ URL, open Play Store.

---

### LeoTroubleshootController (`lib/app/modules/leo_troubleshoot/controllers/leo_troubleshoot_controller.dart`)
- **Streams**: None.
- **Method channel**: `sendCommand("reboot")` for reset; uses `LeoOtaController` for “update from file” (file picker → OTA).
- **UI**: Troubleshoot screen: reset Leo, FAQ, update from file (.bin); shows wait or progress dialog when OTA/timer is active.
- **Features**: Reboot Leo, open FAQ, OTA from local .bin file.

---

### BatteryHistoryController (`lib/app/modules/battery/history/controllers/battery_history_controller.dart`)
- **Streams**: None.
- **Method channel**: `getBatterySessionHistory`, `clearBatterySessionHistory`.
- **UI**: Battery history view: list of sessions (from `BatterySession.fromMap`), clear.
- **Features**: Display and clear battery session history (data from Kotlin service).

---

## 5. Graph and Hive

### Graph data flow
- **Source**: `BleScanService.measureDataStream` and parsing in `LeoHomeController._parseReceivedData` (measure/chmode and fallback) → `_addGraphSample(current)`.
- **Storage**: `GraphHiveStorageService.appendCurrentSample(seconds, current)` on each sample; two Hive boxes: `currentChargeGraphData`, `pastChargeGraphData`.
- **Restore**: `LeoHomeController._restoreGraphFromHive()` in `onReady()`: load past → `lastChargeGraphPoints`; load current, run `checkDataConditions` (duration > 4 min and at least one point ≥ 0.1 A); if ok, promote current to last and persist; else clear current.
- **Finalize**: `finalizeCurrentGraphSession()`: if duration ≥ 240 s and not all tiny currents, copy current → last and clear current; otherwise clear current.
- **Widget**: `ChargeGraphWidget` (fl_chart): uses `LeoHomeController.currentGraphPoints` / `lastChargeGraphPoints` and axis limits/intervals for “current” vs “last” charge graph in `LeoMetricsSummary`.

### Models
- **GraphPoint**: `seconds`, `current`.
- **GraphValuesDataHive** (Hive typeId 10): `dataKey` (seconds), `value` (current).
- **ChargingMode** enum: smart, ghost, safe.

---

## 6. OTA package/helper (Flutter side)

- **lib/app/core/ota_package.dart**: `Esp32OtaPackage` implements BLE OTA (MTU, control/data characteristics, file/URL/picker chunks). Not used by the main OTA UX; that path uses `BleScanService.startOtaUpdate(filePath)` (Kotlin). So this is legacy/alternative OTA path.
- **LeoOtaController**: Coordinates OTA from cloud (Firebase) or file: progress stream, backup polling, install timer, reconnection and done dialog.
- **LeoTroubleshootController**: “Update from file” → file picker (.bin) → `LeoOtaController.startOtaUpdate(path)`.
- **LeoHomeView**: “Update Leo” → `LeoFirmwareUpdateDialog` (can auto-download from cloud); first-run firmware download at start via `downloadFirmwareAtStart()` (Firebase “Internal fw”).

---

## 7. Hive storage

- **Graph**: `GraphValuesDataHive`, boxes `currentChargeGraphData` and `pastChargeGraphData` (see Graph and Hive above).
- **Feedback / device history**: SharedPreferences only (`leo_serial_number`, `leo_firmware_version`, `leo_device_history`, `userEmail`, `first_time_thank_you_seen`); no Hive.

---

## 8. Bottom navigation and shell

- **Route**: `AppRoutes.navBarView` → `BottomNavBarView` + `BottomNavBarBinding`.
- **Binding**: Injects `BottomNavBarController`, `LedTimeoutController`, `LeoHomeController`, `BatteryController`, `SettingsController`, `ChargeLimitController`.
- **Tabs**: 0 = Leo (`LeoHomeView`), 1 = Phone (`BatteryView`), 2 = Settings (`SettingsView`).
- **Back**: Not on Leo → go to Leo; on Leo → `BleScanService.minimizeApp()`.

---

## 9. Feature → code summary

| Feature | Primary controller / service | Streams | Method channel | Timers / other |
|--------|------------------------------|--------|----------------|----------------|
| App startup, splash | SplashController | — | — | 3s delay → nav |
| BLE scan, connect, disconnect | LeoHomeController, BleScanService | adapter, device, connection | startService, rescan, connect, disconnect, getScannedDevices, etc. | Command serial chain with delays |
| Leo data (mWh, version, measure, chmode) | LeoHomeController | connection, dataReceived, measureData, advancedModes | sendCommand, get* | 5s delay after connect for firmware request |
| Live graph (current/last) | LeoHomeController, ChargeGraphWidget, GraphHiveStorageService | measureData, dataReceived | — | _graphInactivityTimer (in finalize) |
| OTA (cloud + file) | LeoOtaController, BleScanService | otaProgress, connection | startOtaUpdate, cancelOtaUpdate, getOtaProgress, isOtaUpdateInProgress | 60s install timer, 500ms progress polling |
| Phone battery & metrics | BatteryController | phoneBattery, batteryHealth, batteryMetrics | getPhoneBattery, getBatteryHealthInfo, start/stop/reset health | — |
| Charge limit | ChargeLimitController | chargeLimit, connection | getChargeLimit, setChargeLimit, setChargeLimitEnabled | — |
| Feedback (email + serial) | FeedbackController | dataReceived | — (uses LeoHome sendCommand, isConnected) | 500ms after serial/swversion |
| Manual PDF | ManualController | — | — | — |
| Advanced settings (ghost/silent/higher) | AdvancedSettingsController | — | getAdvancedModes, setGhostMode, setSilentMode, setHigherChargeLimit | — |
| LED timeout | LedTimeoutController | — | getLedTimeout, requestLedTimeout, setLedTimeout | — |
| About / app & Leo version | AboutController | — | isConnected | — |
| Settings (FAQ, Play Store) | SettingsController | — | — | — |
| Troubleshoot (reboot, OTA file) | LeoTroubleshootController | — | sendCommand(reboot), LeoOtaController.startOtaUpdate | — |
| Battery history | BatteryHistoryController | — | getBatterySessionHistory, clearBatterySessionHistory | — |
| Bottom nav + minimize | BottomNavBarController, BottomNavBarView | — | minimizeApp (from view) | — |

This is the complete functional map of the Flutter side: every listed feature is tied to the controllers, streams, method channel usage, timers, and UI described above.
