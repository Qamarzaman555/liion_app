# BleScanService.kt — Complete Functional Map

This document describes every major feature of `BleScanService.kt`, including behavior, timers, dependencies, and impact of changes. The file is ~4570 lines.

---

## 1. BLE scanning

### What it does
- Discovers BLE devices whose name contains **"Leo Usb"** (constant `DEVICE_FILTER`).
- Populates `scannedDevices` (address → name) and notifies Flutter via `MainActivity.sendDeviceUpdate`.
- When a **new** device is found and `shouldAutoReconnect` is true and state is `STATE_DISCONNECTED`, triggers `attemptAutoConnect()`.

### Timers / intervals
- No periodic scan interval; scan runs continuously once started until stopped.
- After Bluetooth turns ON: `attemptAutoConnect` is delayed by **1000 ms** (in `bluetoothStateReceiver`).
- On `onStartCommand`: auto-connect attempt delayed by **500 ms** if BT enabled and disconnected.

### Dependencies
- `bluetoothAdapter`, `bluetoothLeScanner` (from `BluetoothManager`).
- `scanCallback` (reports results / scan failure).
- `prefs` for `KEY_LAST_DEVICE_ADDRESS` (auto-reconnect target).
- Flutter: `MainActivity.sendDeviceUpdate`, `MainActivity.sendAdapterStateUpdate`.

### What would break if changed
- Changing `DEVICE_FILTER` would stop discovering Leo devices or discover wrong devices.
- Stopping scan when not connected would prevent device list updates and auto-reconnect.
- Removing the “new device” check before auto-connect could cause repeated connect attempts on every scan result.

---

## 2. Connection management (connect, disconnect, auto-reconnect, deep sleep, background)

### Connect
- **Entry:** `connectToDevice(address, userInitiated)` (from companion `connect(address)` with `userInitiated = true`).
- If user-initiated: sets `shouldAutoReconnect = true`, `reconnectAttempts = 0`, logs.
- Cancels any pending reconnect, closes existing GATT (disconnect + close), **100 ms** `Thread.sleep` to let stack reset, then `device.connectGatt(..., false, gattCallback, TRANSPORT_LE)`.
- State set to `STATE_CONNECTING`, `pendingConnectAddress = address`; Flutter notified.

### Disconnect
- **Entry:** `disconnectDevice(userInitiated)` (from companion `disconnect()` with `userInitiated = true`).
- Cancels reconnect, stops charge limit timer, time tracking, measure timer.
- If user-initiated: sets `shouldAutoReconnect = false`, `reconnectAttempts = 0`, `clearSavedDevice()`.
- Clears UART/file-streaming state, stops file streaming and recovery, then `gatt.disconnect()` (does not close GATT here; `closeGatt()` is called from `onConnectionStateChange(STATE_DISCONNECTED)`).

### GATT lifecycle
- **onConnectionStateChange(STATE_CONNECTED):**  
  State → `STATE_CONNECTED`, `connectedDeviceAddress` set, `reconnectAttempts = 0`, `pendingConnectAddress = null`, `shouldAutoReconnect = true`, last device saved, then `requestMtu(512)`.
- **onConnectionStateChange(STATE_DISCONNECTED):**  
  UART/OTA/file-streaming state reset, `stopFileStreaming()`, `stopFileStreamingRecovery()`, `stopChargeLimitTimer()`, `stopMeasureTimer()`, `closeGatt()`.  
  If `shouldAutoReconnect` and BT on and previous address known: `scheduleReconnect(previousAddress)`.

### Auto-reconnect
- **scheduleReconnect(address):**  
  Delay = `RECONNECT_DELAY_MS + (reconnectAttempts * RECONNECT_BACKOFF_MS)` (first delay 2 s, then backoff).  
  After **MAX_RECONNECT_ATTEMPTS (10)** failures: resets attempts, **restartScan()**, then **30 s** delay before next try.
- **attemptAutoConnect():**  
  Only if disconnected, BT on, `shouldAutoReconnect`; uses `KEY_LAST_DEVICE_ADDRESS` and calls `connectToDevice(savedAddress, userInitiated = false)` (with or without device in `scannedDevices`).

### Deep sleep / background
- Service is **foreground** (notification), so it continues in background.
- **Wake lock:** `PARTIAL_WAKE_LOCK` ("LiionApp::BleServiceWakeLock") acquired in `onCreate`, re-acquired in keep-alive and `onTaskRemoved`.
- **OnePlus:** Shorter keep-alive interval and AlarmManager-based “restart” intent so the service is restarted if killed (see Keep-alive section).
- No explicit “deep sleep” mode; charge limit is sent on a timer and on battery changes regardless of app state.

### Timers
- Reconnect: **RECONNECT_DELAY_MS = 2000**, **RECONNECT_BACKOFF_MS = 1000**, max attempts **10**, then **30 s** cooldown.
- Connect flow: **100 ms** sleep after closing GATT before new connect.

### Dependencies
- `prefs`: `KEY_LAST_DEVICE_ADDRESS`, `KEY_LAST_DEVICE_NAME`, `KEY_AUTO_RECONNECT`.
- `reconnectRunnable`, `reconnectAttempts`, `pendingConnectAddress`, `bluetoothGatt`, `gattCallback`.

### What would break if changed
- Closing GATT too late or not waiting 100 ms can cause status 133 / connection failures.
- Disabling `shouldAutoReconnect` on disconnect (e.g. in error path) would stop auto-reconnect.
- Changing backoff or max attempts affects how quickly and how often reconnects are tried after failures.

---

## 3. Measure command (Leo device voltage/current)

### What it does
- Sends the text command **"measure"** over UART (TX characteristic) so the Leo device reports current voltage and current.
- Response format: **"OK measure &lt;voltage&gt; &lt;current&gt;"** (parsed in `handleReceivedData`).
- Parsed values are formatted and sent to Flutter via `MainActivity.sendMeasureData(voltageStr, currentStr)`.

### Timers
- **MEASURE_INTERVAL_MS = 1000** (1 s).
- **MEASURE_INITIAL_DELAY_MS = 1000** (first measure 1 s after UART ready).
- Started in `onDescriptorWrite` (when UART notifications are enabled); stopped on disconnect and during OTA.

### Dependencies
- `measureRunnable`, `txCharacteristic`, command queue, `handleReceivedData` (RX path), `MainActivity.sendMeasureData`.

### What would break if changed
- Changing interval could overload the device or make UI updates sluggish.
- Stopping the timer on disconnect is required to avoid sending commands when disconnected; stopping during OTA avoids mixing measure with OTA traffic.

---

## 4. File streaming (end-to-end)

### Flow
1. **get_files**  
   - Commands: `app_msg get_files` then **300 ms** later `py_msg`.  
   - Response: **"OK py_msg get_files &lt;startFile&gt; &lt;endFile&gt;"**.  
   - Sets `leoFirstFile`, `leoLastFile`, `currentFile = leoFirstFile`, then calls `startFileStreaming()`.
2. **Per-file stream**  
   - Send `app_msg stream_file &lt;currentFile&gt;` then **250 ms** later `py_msg`.  
   - Response can come on **RX_CHAR** or **DATA_TRANSMIT_CHAR**: **"OK py_msg stream_file &lt;fileCheck&gt;"** (1 = exists, -1 = missing) or **"ERROR py_msg"** (within 3 s of stream_file treated as “file missing”).
3. **Data path**  
   - File data arrives on **DATA_TRANSMIT_CHAR** (and possibly RX).  
   - **STX** (`\u0002`) = start of file payload; **ETX** (`\u0003`) = end.  
   - `processFileStreamingData()` parses CSV rows (timestamp;session;current;volt;soc;...) into `ChargeData`, maintains `chargeDataList`, `rawFileDataAccumulator`, and `rawFileData` (for CSV upload).
4. **After ETX**  
   - Data stored (Firebase or local), then **scheduleNextFileStreamCommand()** with **FILE_STREAMING_DELAY_MS = 7000** (7 s) before requesting next file or stopping.
5. **File missing / error**  
   - On fileCheck == -1 or ERROR (within 3 s): **scheduleNextFileAfterDelay()** (same 7 s delay), increment `currentFile`, then `requestNextFile()`.
6. **Recovery**  
   - **FILE_STREAMING_RECOVERY_INTERVAL_MS = 10000** (10 s).  
   - If connected, UART ready, valid file range, not streaming and not waiting for response, calls `requestNextFile()` to resume.
7. **Stream-file timeout**  
   - **STREAM_FILE_TIMEOUT_MS = 10000** (10 s) after sending stream_file; if no response, advance to next file or retry last.

### Timers
- **FILE_STREAMING_DELAY_MS = 7000** (after ETX or “file missing” before next file).
- **FILE_STREAMING_RECOVERY_INTERVAL_MS = 10000** (recovery check).
- **STREAM_FILE_TIMEOUT_MS = 10000** (stream_file response timeout).
- get_files reminder: **2000 ms** (single nudge with `py_msg` if range still pending).
- Delays between commands: 250 ms (py_msg after app_msg), 300 ms (py_msg after get_files), 500 ms (before starting stream_file timeout after py_msg).

### Dependencies
- DATA_TRANSFER_SERVICE_UUID, DATA_TRANSMIT_CHAR_UUID; file streaming characteristic and notifications.
- UART (command queue) for app_msg/py_msg.
- `processFileStreamingData`, `storeDataToFirebase`, `saveToLocalStorage`, `uploadToFirebase`, `syncPendingUploads`.
- SharedPreferences: `sentSessions_<address>`, pending upload keys, serial, app version, etc.

### What would break if changed
- Shorter than 7 s delay between files could stress BLE/Leo stack; longer delays slow down full sync.
- Recovery must not run while waiting for response or while actively streaming (would duplicate requests).
- STX/ETX and “OK py_msg stream_file” / “ERROR py_msg” handling must stay in sync with device firmware.

---

## 5. Charge limit (foreground, background, deep sleep)

### What it does
- Sends **"app_msg limit &lt;limitValue&gt; &lt;phoneBatteryLevel&gt; &lt;chargingFlag&gt; &lt;timeValue&gt;"** to the Leo device.  
  - `limitValue`: charge limit % if `chargeLimitEnabled`, else 0.  
  - `chargingFlag`: 1 if phone charging, 0 otherwise.  
  - `timeValue`: `chargingTimeSeconds` or `dischargingTimeSeconds`.
- Device responds with **"OK py_msg charge_limit &lt;numeric&gt;"** (1 = confirmed); `chargeLimitConfirmed` and Flutter updated via `MainActivity.sendChargeLimitConfirmed`.

### When it’s sent
- **On connection (UART ready):** `startChargeLimitTimer()` plus a single **500 ms** delayed `sendChargeLimitCommand()`.
- **Periodically:** charge limit timer every **CHARGE_LIMIT_INTERVAL_MS = 30000** (30 s).
- **On battery change:** if level or charging state changed and connected and UART ready, `sendChargeLimitCommand()` from `batteryReceiver`.

### Timers
- **CHARGE_LIMIT_INTERVAL_MS = 30000** (30 s).
- Initial send: **500 ms** after descriptor write.

### Dependencies
- `chargeLimit`, `chargeLimitEnabled` (from prefs), `chargingTimeSeconds` / `dischargingTimeSeconds` (from `timeTrackingRunnable`), `phoneBatteryLevel`, `isPhoneCharging` (from `batteryReceiver`).
- Command queue, `handleReceivedData` (charge_limit response), `MainActivity.sendChargeLimitUpdate`, `sendChargeLimitConfirmed`, notification.

### What would break if changed
- Turning off the 30 s timer would rely only on battery events (might miss updates if BATTERY_CHANGED is delayed).
- Changing the command format or parameters would break Leo firmware expectations.

---

## 6. Battery health calculation

### What it does
- Estimates phone battery capacity and health % by measuring charge accumulated over a **60%** range (**HEALTH_CALCULATION_RANGE = 60**).
- **Designed capacity:** from `BatteryManager` / PowerProfile (reflection); stored in `designedCapacityMah`.
- **Current sampling:** `getCurrentNowMicroAmps()` (with mA vs µA detection: if |raw| < 10000 assume mA and convert to µA).
- **Accumulation:** `sampleBatteryCurrent()` every **HEALTH_SAMPLE_INTERVAL_MS = 1000** (1 s); `accumulatedCurrentMah` += (|current| × elapsed time) in mAh.
- **Completion:** When `phoneBatteryLevel - healthCalculationStartPercent >= 60`, `calculateBatteryHealth()`:  
  - Estimated capacity = (accumulatedCurrentMah / percentCharged) × 100.  
  - Health % = (estimated / designed) × 100 (capped at 100).  
  - New reading added to `healthReadings` (max **MAX_HEALTH_READINGS = 5**); averaged into `estimatedCapacityMah` and `batteryHealthPercent`.
- **Auto-start:** On plug-in, if level ≤ (100 - 60), `startHealthCalculation()` is called.  
- **Stop/reset:** On unplug, `stopHealthCalculation()` and `resetHealthCalculation()`.

### Timers
- **HEALTH_SAMPLE_INTERVAL_MS = 1000** (1 s sampling).
- Progress checked on every battery level change in `batteryReceiver` via `checkHealthCalculationProgress()`.

### Dependencies
- `batteryReceiver`, `getDesignedCapacity()`, `getCurrentNowMicroAmps()`, `healthReadings`, prefs (designed_capacity_mah, estimated_capacity_mah, battery_health_percent, health_readings_*), `MainActivity.sendBatteryHealthUpdate`, `loadHealthReadings`, `saveHealthReadings`, `calculateAveragedHealth`.

### What would break if changed
- Changing HEALTH_CALCULATION_RANGE changes accuracy and how much charge is needed.
- Wrong current unit (mA vs µA) would skew capacity and health; the 10000 threshold is device-specific.
- Clearing or not persisting health readings would lose history and averages.

---

## 7. Session history / tracking

### What it does
- Tracks **phone** charge/discharge sessions: start/end time, initial/final level, charging flag, duration, accumulated mAh.
- **Current session:** `currentSessionStartTime`, `currentSessionInitialLevel`, `currentSessionIsCharging`, `currentSessionAccumulatedMah`. mAh comes from `sampleBatteryMetrics()` (same current integration as metrics).
- **Session end:** When charging state changes, `endCurrentSession()` is called (from `batteryReceiver`). Session is stored only if duration ≥ 1 s and accumulatedMah ≥ 1.0.
- **Persistence:** Last **MAX_SESSIONS = 300** sessions in SharedPreferences; in-progress session saved in `saveCurrentSessionState()` (and on periodic save every 10 mAh or 5 minutes in `sampleBatteryMetrics`).
- **Restore:** On `onCreate`, `loadCurrentSessionState()` restores in-progress session if < 7 days old; if charging state no longer matches, old session is ended and a new one started.
- **OnePlus onDestroy:** If service is “not intentionally stopping”, session state is preserved so it can resume after restart.

### Timers
- **Time tracking:** 1 s runnable (`timeTrackingRunnable`) for `chargingTimeSeconds` / `dischargingTimeSeconds` (used in limit command and UI).
- Session state save: every **10 mAh** accumulated or **5 minutes** in `sampleBatteryMetrics`.

### Dependencies
- `batteryReceiver` (charging state change), `sampleBatteryMetrics` (mAh accumulation and periodic save), `loadSessions`, `saveSessions`, `getSessionHistory`, `clearSessionHistory`, prefs keys `session_*`, `current_session_*`, `battery_sessions_count`.

### What would break if changed
- Not ending the session on charging state change would merge charge/discharge into one session.
- Thresholds (1 s, 1 mAh) prevent noise; lowering them could create many tiny sessions.

---

## 8. Charge mode (chmode)

### What it does
- **chmode** is only referenced as a **critical command** in the command queue: when a command starts with "chmode" (or "mwh", "serial", "swversion", "measure") or contains "py_msg", the queue waits for a response and uses **RESPONSE_TIMEOUT_MS = 2000** so the next command is not sent until response or timeout.
- There is **no** dedicated parsing of a "chmode" response in `handleReceivedData`; the effect is purely serialization so that chmode (and similar) commands get a clear response window before the next write.

### Timers
- **RESPONSE_TIMEOUT_MS = 2000** (shared with other critical commands).
- **COMMAND_GAP_MS = 250** between any two command sends.

### Dependencies
- Command queue (`processCommandQueue`), `waitingForResponse`, `lastCommandSent`, `cancelResponseTimeout` / `startResponseTimeout`.

### What would break if changed
- Removing chmode from critical commands could allow another command to be sent before the device replies, leading to corrupted or missed responses.

---

## 9. LED timeout

### What it does
- Reads/writes Leo LED dim timeout (seconds).  
  - **Get:** `app_msg led_time_before_dim` then **250 ms** later `py_msg`.  
  - **Set:** `app_msg led_time_before_dim &lt;seconds&gt;` then **250 ms** later `py_msg`.
- Response: **"OK py_msg led_time_before_dim &lt;seconds&gt;"**; parsed and stored in `ledTimeoutSeconds` and prefs `KEY_LED_TIMEOUT`, then `MainActivity.sendLedTimeoutUpdate(ledTimeoutSeconds)`.

### Timers
- **250 ms** between app_msg and py_msg for led_time_before_dim.
- **700 ms** after UART ready: `requestLedTimeoutFromDevice()`.

### Dependencies
- `updateLedTimeout(seconds)`, `requestLedTimeoutFromDevice()`, prefs, `MainActivity.sendLedTimeoutUpdate`, validation (0–99999).

### What would break if changed
- Wrong delay or missing py_msg could result in device not returning or applying the value.

---

## 10. Ghost mode, silent mode, higher charge limit modes

### What it does
- **Ghost mode:** `app_msg ghost_mode 0|1` + **200 ms** later refresh with `app_msg ghost_mode` + **250 ms** later `py_msg`. Response **"OK py_msg ghost_mode &lt;0|1&gt;"** → `updateAdvancedModeState(ghost = ...)`.
- **Silent (quiet) mode:** Same pattern with `quiet_mode`. Response **"OK py_msg quiet_mode &lt;0|1&gt;"**.
- **Higher charge limit:** Same with `charge_limit` (device-side limit flag). Response **"OK py_msg charge_limit &lt;0|1&gt;"** (same response as limit confirmation; handled in `handleAdvancedModeResponse("charge_limit", numeric)` for higherCharge).
- State stored in prefs (`KEY_GHOST_MODE`, `KEY_SILENT_MODE`, `KEY_HIGHER_CHARGE_LIMIT`) and sent to Flutter via `MainActivity.sendAdvancedModesUpdate`.

### Request all modes (on connect)
- **requestAdvancedModesFromDevice():** Throttled (min **1500 ms** since last request, `advancedRequestInProgress`). Sends `app_msg ghost_mode` + 300 ms → `py_msg`, then **450 ms** later `app_msg quiet_mode` + 300 ms → `py_msg`, then **450 ms** later `app_msg charge_limit` + 300 ms → `py_msg`. Called **1100 ms** after UART ready.

### Timers
- **200 ms** before refresh after set; **250 ms** (or 300 ms in batch) before py_msg.
- **450 ms** between each mode in batch request; **1100 ms** after UART ready for initial request; **1500 ms** throttle between requests.

### Dependencies
- `handleReceivedData` (ghost_mode, quiet_mode, charge_limit), `updateAdvancedModeState`, `scheduleAdvancedRefresh`, prefs, `MainActivity.sendAdvancedModesUpdate`.

### What would break if changed
- Shorter throttle could overwhelm the device; changing order or delays could mix responses with other commands.

---

## 11. OTA firmware update

### What it does
- Uses **OTA_SERVICE_UUID** and characteristics **OTA_DATA_CHAR_UUID**, **OTA_CONTROL_CHAR_UUID**.
- Before OTA: stops measure and charge limit timers.
- **Flow:**  
  - Write chunk size (250) to data char; write **0x01** to control char; read control (expect **0x02** = ready).  
  - Send firmware in chunks of **min(250, MTU-3)** with **10 ms** sleep between packets; retries (3 per packet, exponential backoff 50/100/200 ms), max 5 consecutive failures then abort.  
  - Write **0x04** to control to finish; optionally read **0x05** ack.  
  - Disconnect after all packets is treated as success (device rebooting).
- After OTA: if still connected and UART ready, restarts measure and charge limit timers.
- Progress reported via `MainActivity.sendOtaProgress(progress, inProgress, message)`.

### Timers
- **10 ms** between packet writes.
- **200 ms** after start control write before first read; **500 ms** after finish write before final read.
- Read timeout **2000 ms**; write completion wait **3000 ms** in `writeOtaCharacteristic`.

### Dependencies
- `otaDataCharacteristic`, `otaControlCharacteristic`, `writeOtaCharacteristic`, `readOtaCharacteristicSync`, `performOtaUpdate` (background thread), OTA write/read locks, `MainActivity.sendOtaProgress`, measure/charge limit timers (stopped/restarted).

### What would break if changed
- Smaller chunk size or shorter delays could cause BLE stack/device errors; larger chunks may exceed MTU.
- Not stopping UART timers during OTA can interleave commands with OTA and break the update.

---

## 12. Keep-alive and wake lock

### What it does
- **Wake lock:** `PowerManager.PARTIAL_WAKE_LOCK` "LiionApp::BleServiceWakeLock" acquired in `onCreate`, re-acquired in keep-alive runnable and in `onTaskRemoved`.
- **Keep-alive runnable:** Runs periodically; updates notification (`updateNotificationWithBattery()`), re-acquires wake lock if needed, and (on OnePlus) calls `setupServiceRestart()` to schedule an AlarmManager intent. Then schedules itself again after `getKeepAliveInterval()`.
- **OnePlus:** **KEEP_ALIVE_INTERVAL_ONEPLUS_MS = 120000** (2 min); **AlarmManager** with **RESTART_ACTION** and `setAndAllowWhileIdle` (or `set` on older API) so that if the process is killed, the service is restarted. On normal `onDestroy` with `isServiceStopping`, `cancelServiceRestart()` is called; otherwise `setupServiceRestart()` is left so the alarm can bring the service back.
- **Non-OnePlus:** **KEEP_ALIVE_INTERVAL_MS = 300000** (5 min); no AlarmManager restart.

### Timers
- **KEEP_ALIVE_INTERVAL_MS = 300000** (5 min) or **KEEP_ALIVE_INTERVAL_ONEPLUS_MS = 120000** (2 min) on OnePlus.
- Alarm trigger time = now + same interval.

### Dependencies
- `PowerManager`, `AlarmManager` (OnePlus), `restartPendingIntent`, `isOnePlus()`, `createNotification` / `updateNotificationWithBattery`, `releaseWakeLock` in `onDestroy`.

### What would break if changed
- Releasing wake lock too early could let the device sleep and drop BLE or stop timers.
- On OnePlus, longer interval or removing AlarmManager could lead to the service staying dead after kill.

---

## 13. Firebase uploads

### What it does
- After each file stream **ETX**, `storeDataToFirebase()` is called with parsed `ChargeData` list and raw CSV.
- **Deduplication:** `sentSessions_<address>` in prefs; if session already in set, upload is skipped.
- **Online:** Builds JSON (model, serial_number, firmware, sw, device, session, mode, flags, timestamp, DateTime, data); uploads to **COLLECTION_NAME** and, if raw CSV present, to **CSV_COLLECTION_NAME** (different doc same ID). On success: add session to sent set, remove pending keys, send **rm_file &lt;fileNumber&gt;** to device after **500 ms**.
- **Offline:** `saveToLocalStorage()` stores pending upload (metadata + optional JSON + raw CSV in prefs). **syncPendingUploads()** runs when network is available (connectivity callback) or **4 s** after UART ready; it replays pending uploads via `uploadToFirebase`.
- **Connectivity:** Network callback registers for INTERNET + VALIDATED; on available/capabilities changed, `syncPendingUploads()` is posted. Online check uses `ping -c 1 8.8.8.8` (500 ms timeout).

### Timers
- **500 ms** after successful upload before `rm_file` command.
- **4000 ms** after UART ready to call `syncPendingUploads()`.

### Dependencies
- `firestore`, `COLLECTION_NAME`, `CSV_COLLECTION_NAME`, `serialNumber`, `firmwareVersion`, prefs (appVersion, appBuildNumber, sentSessions_*, pending_upload_*), `connectivityManager`, `networkCallback`, `convertMapToJsonObject`, `jsonObjectToMap`.

### What would break if changed
- Changing collection names or document ID format would break backend or create duplicates.
- Not saving pending uploads when offline would lose data; not syncing on connectivity restore would leave data only on device.

---

## 14. All timers and exact purposes (summary)

| Constant / location              | Value        | Purpose |
|----------------------------------|-------------|---------|
| RECONNECT_DELAY_MS               | 2000        | First reconnect delay after disconnect |
| RECONNECT_BACKOFF_MS             | 1000        | Extra delay per attempt (backoff) |
| Max reconnect then cooldown      | 30000       | After 10 failures, wait 30 s and restart scan |
| CHARGE_LIMIT_INTERVAL_MS        | 30000       | Periodic charge limit command to Leo |
| KEEP_ALIVE_INTERVAL_MS          | 300000      | Keep-alive / notification update (non-OnePlus) |
| KEEP_ALIVE_INTERVAL_ONEPLUS_MS  | 120000      | Keep-alive + AlarmManager (OnePlus) |
| MEASURE_INTERVAL_MS             | 1000        | Measure command interval |
| MEASURE_INITIAL_DELAY_MS         | 1000        | First measure after UART ready |
| BATTERY_METRICS_INTERVAL_MS     | 1000        | Battery metrics (current, voltage, temp, mAh) |
| HEALTH_SAMPLE_INTERVAL_MS       | 1000        | Battery health current sampling |
| COMMAND_GAP_MS                  | 250         | Gap between command queue sends |
| RESPONSE_TIMEOUT_MS             | 2000        | Timeout for critical command response |
| FILE_STREAMING_DELAY_MS         | 7000        | Delay after ETX or “file missing” before next file |
| FILE_STREAMING_RECOVERY_INTERVAL_MS | 10000   | File streaming recovery check interval |
| STREAM_FILE_TIMEOUT_MS          | 10000       | Timeout for stream_file response |
| get_files reminder              | 2000        | Single py_msg nudge if get_files range pending |
| handler.postDelayed(500)        | 500         | Initial charge limit after UART ready |
| handler.postDelayed(700)        | 700         | Request LED timeout after UART ready |
| handler.postDelayed(1100)       | 1100        | Request advanced modes after UART ready |
| handler.postDelayed(1700)       | 1700        | Request serial after UART ready |
| handler.postDelayed(3000)       | 3000        | get_files after UART ready (last) |
| handler.postDelayed(4000)       | 4000        | syncPendingUploads after UART ready |
| timeTrackingRunnable             | 1000        | chargingTimeSeconds / dischargingTimeSeconds tick |
| Session save trigger            | 10 mAh or 5 min | Save in-progress session state |
| OTA: between packets            | 10          | ms sleep between OTA packet writes |
| OTA: write completion timeout   | 3000        | ms wait for write callback |
| OTA: read timeout                | 2000        | ms wait for OTA control read |
| Connect after GATT close        | 100         | ms Thread.sleep before new connect |
| Bluetooth ON → auto-connect      | 1000        | ms delay |
| onStartCommand → auto-connect   | 500         | ms delay |
| py_msg after app_msg (general)  | 250–300     | ms |
| advanced mode set → refresh     | 200         | ms |
| advanced modes batch spacing    | 450         | ms between modes |
| advanced request throttle       | 1500        | ms between requestAdvancedModesFromDevice |
| rm_file after Firebase success  | 500         | ms |

---

## 15. Code locations (by feature)

- **BLE scan:** `startBleScan`, `stopBleScan`, `restartScan`, `scanCallback`, `bluetoothStateReceiver` (STATE_ON).
- **Connection:** `connectToDevice`, `disconnectDevice`, `gattCallback` (onConnectionStateChange, onMtuChanged, onServicesDiscovered, onDescriptorWrite), `closeGatt`, `attemptAutoConnect`, `scheduleReconnect`, `cancelReconnect`.
- **Measure:** `startMeasureTimer`, `stopMeasureTimer`, `measureRunnable`, `handleReceivedData` (measure response).
- **File streaming:** `requestGetFiles`, `startFileStreaming`, `requestNextFile`, `processFileStreamingData`, `scheduleNextFileStreamCommand`, `scheduleNextFileAfterDelay`, `startStreamFileTimeout`, `cancelStreamFileTimeout`, `startFileStreamingRecovery`, `stopFileStreamingRecovery`, `storeDataToFirebase`, `uploadToFirebase`, `saveToLocalStorage`, `syncPendingUploads`; gattCallback for DATA_TRANSMIT_CHAR_UUID and stream_file/ERROR handling.
- **Charge limit:** `sendChargeLimitCommand`, `startChargeLimitTimer`, `stopChargeLimitTimer`, `updateChargeLimit`, `updateChargeLimitEnabled`, `batteryReceiver` (send on level/charging change), `handleReceivedData` (charge_limit response).
- **Battery health:** `startHealthCalculation`, `stopHealthCalculation`, `resetHealthCalculation`, `startHealthSampling`, `sampleBatteryCurrent`, `checkHealthCalculationProgress`, `calculateBatteryHealth`, `addHealthReading`, `calculateAveragedHealth`, `saveHealthReadings`, `loadHealthReadings`, `resetHealthReadings`, `getDesignedCapacity`, `getCurrentNowMicroAmps`; `batteryReceiver` (auto-start on plug, stop on unplug).
- **Session tracking:** `startNewSession`, `endCurrentSession`, `saveCurrentSessionState`, `loadCurrentSessionState`, `clearCurrentSessionState`, `saveSessions`, `loadSessions`, `getSessionHistory`, `clearSessionHistory`; `batteryReceiver` (state change), `sampleBatteryMetrics` (mAh and periodic save), `onCreate` (restore), `onDestroy` (OnePlus preserve).
- **Charge mode (chmode):** Only in `processCommandQueue` critical-command list; no dedicated response handler.
- **LED timeout:** `updateLedTimeout`, `requestLedTimeoutFromDevice`, `handleReceivedData` (led_time_before_dim).
- **Advanced modes:** `updateGhostMode`, `updateSilentMode`, `updateHigherChargeLimit`, `requestAdvancedModesFromDevice`, `scheduleAdvancedRefresh`, `handleAdvancedModeResponse`, `updateAdvancedModeState`.
- **OTA:** `startOtaUpdate`, `performOtaUpdate`, `readOtaCharacteristicSync`, `writeOtaCharacteristic`, `cancelOtaUpdate`, `setupOtaService`; gattCallback (onCharacteristicWrite, onCharacteristicRead).
- **Keep-alive / wake lock:** `acquireWakeLock`, `releaseWakeLock`, `startKeepAlive`, `stopKeepAlive`, `getKeepAliveInterval`, `setupServiceRestart`, `cancelServiceRestart`, `isOnePlus`; `onTaskRemoved` (re-acquire wake lock).
- **Firebase:** `storeDataToFirebase`, `uploadToFirebase`, `saveToLocalStorage`, `syncPendingUploads`, `networkCallback`, `convertMapToJsonObject`, `jsonObjectToMap`.
- **Command queue:** `enqueueCommand`, `processCommandQueue`, `writeCommandImmediate`, `startResponseTimeout`, `cancelResponseTimeout`; `handleReceivedData` (clearing waitingForResponse for matching response).
- **Time tracking:** `startTimeTracking`, `stopTimeTracking`, `timeTrackingRunnable` (chargingTimeSeconds, dischargingTimeSeconds).
- **Battery metrics:** `startBatteryMetricsPolling`, `stopBatteryMetricsPolling`, `sampleBatteryMetrics` (current, voltage, temp, mAh accumulation, session mAh, MainActivity.sendBatteryMetricsUpdate).

This map covers the entire BleScanService behavior, timers, dependencies, and risks as derived from the full file read.
