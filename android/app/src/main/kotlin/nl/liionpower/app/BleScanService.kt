package nl.liionpower.app

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import org.json.JSONObject
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.*
import java.util.UUID
import java.util.concurrent.TimeUnit

class BleScanService : Service() {

    companion object {
        const val CHANNEL_ID = "BLE_SCAN_CHANNEL"
        const val NOTIFICATION_ID = 1
        const val DEVICE_FILTER = "Leo Usb"
        const val PREFS_NAME = "ble_prefs"
        const val KEY_LAST_DEVICE_ADDRESS = "last_device_address"
        const val KEY_LAST_DEVICE_NAME = "last_device_name"
        const val KEY_AUTO_RECONNECT = "auto_reconnect"
        const val KEY_CHARGE_LIMIT = "charge_limit"
        const val KEY_CHARGE_LIMIT_ENABLED = "charge_limit_enabled"
        const val KEY_LED_TIMEOUT = "led_timeout_seconds"
        const val KEY_GHOST_MODE = "ghost_mode_enabled"
        const val KEY_SILENT_MODE = "silent_mode_enabled"
        const val KEY_HIGHER_CHARGE_LIMIT = "higher_charge_limit_enabled"
        const val KEY_SERIAL_NUMBER = "deviceSerialNumber"
        
        // Nordic UART Service UUIDs
        val SERVICE_UUID: UUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        val TX_CHAR_UUID: UUID = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
        val RX_CHAR_UUID: UUID = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        
        // OTA Service UUIDs
        val OTA_SERVICE_UUID: UUID = UUID.fromString("d6f1d96d-594c-4c53-b1c6-144a1dfde6d8")
        val OTA_DATA_CHAR_UUID: UUID = UUID.fromString("23408888-1f40-4cd8-9b89-ca8d45f8a5b0")
        val OTA_CONTROL_CHAR_UUID: UUID = UUID.fromString("7ad671aa-21c0-46a4-b722-270e3ae3d830")
        
        // Data Transfer Service UUIDs (File Streaming)
        val DATA_TRANSFER_SERVICE_UUID: UUID = UUID.fromString("41e2b910-d0e0-4880-8988-5d4a761b9dc7")
        val DATA_TRANSMIT_CHAR_UUID: UUID = UUID.fromString("94d2c6e0-89b3-4133-92a5-15cced3ee729")
        
        // Connection states
        const val STATE_DISCONNECTED = 0
        const val STATE_CONNECTING = 1
        const val STATE_CONNECTED = 2
        
        // Reconnect settings
        const val RECONNECT_DELAY_MS = 2000L
        const val MAX_RECONNECT_ATTEMPTS = 10
        const val RECONNECT_BACKOFF_MS = 1000L
        
        // Charge limit timer
        const val CHARGE_LIMIT_INTERVAL_MS = 30000L // 30 seconds
        
        // Keep-alive intervals (shorter on OnePlus to avoid kills)
        const val KEEP_ALIVE_INTERVAL_MS = 300000L
        const val KEEP_ALIVE_INTERVAL_ONEPLUS_MS = 120000L
        const val RESTART_ACTION = "nl.liionpower.app.RESTART_BLE_SERVICE"
        
        val scannedDevices = mutableMapOf<String, String>()
        var isScanning = false
        var connectionState = STATE_DISCONNECTED
        var connectedDeviceAddress: String? = null
        
        // Battery state
        var phoneBatteryLevel: Int = -1
        var isPhoneCharging: Boolean = false
        var currentNowMicroAmps: Int = 0
        
        // Battery metrics (updated every second)
        var batteryCurrentMa: Double = 0.0
        var batteryVoltageV: Double = 0.0
        var batteryTemperatureC: Double = 0.0
        var metricsAccumulatedMah: Double = 0.0 // Resets on charging state change
        
        // Battery health calculation
        var designedCapacityMah: Int = 0
        var estimatedCapacityMah: Double = 0.0
        var batteryHealthPercent: Double = -1.0
        var healthCalculationInProgress: Boolean = false
        var healthCalculationWasActive: Boolean = false  // Track if calculation was interrupted
        var healthCalculationStartPercent: Int = -1
        var healthCalculationEndPercent: Int = -1
        var accumulatedCurrentMah: Double = 0.0
        const val HEALTH_CALCULATION_RANGE = 60 // Need 60% charge increase

        
        // Health readings history (last 5 readings)
        data class HealthReading(
            val estimatedCapacityMah: Double,
            val batteryHealthPercent: Double,
            val timestamp: Long
        )
        const val MAX_HEALTH_READINGS = 5
        
        // Charge limit state
        var chargeLimit: Int = 90
        var chargeLimitEnabled: Boolean = false
        var chargeLimitConfirmed: Boolean = false
        var chargingTimeSeconds: Long = 0
        var dischargingTimeSeconds: Long = 0
        var firmwareVersion: String = ""
        var ledTimeoutSeconds: Int = 300
        var ghostModeEnabled: Boolean = false
        var silentModeEnabled: Boolean = false
        var higherChargeLimitEnabled: Boolean = false
        
        // Battery session history
        data class BatterySession(
            val startTime: Long,
            val endTime: Long,
            val initialLevel: Int,
            val finalLevel: Int,
            val isCharging: Boolean,
            val durationSeconds: Long,
            val accumulatedMah: Double
        )
        const val MAX_SESSIONS = 300 // Keep last 300 sessions
        
        fun getBatterySessionHistory(): List<Map<String, Any>> {
            return instance?.getSessionHistory() ?: emptyList()
        }
        
        fun clearBatterySessionHistory(): Boolean {
            return instance?.clearSessionHistory() ?: false
        }
        
        private var instance: BleScanService? = null
        fun markServiceStopping() {
            instance?.isServiceStopping = true
        }
        
        fun rescan() {
            scannedDevices.clear()
            instance?.restartScan()
        }
        
        fun connect(address: String): Boolean {
            return instance?.connectToDevice(address, userInitiated = true) ?: false
        }
        
        fun disconnect() {
            instance?.disconnectDevice(userInitiated = true)
        }
        
        fun sendCommand(command: String): Boolean {
            return instance?.enqueueCommand(command) ?: false
        }
        
        fun startFileStreaming(): Boolean {
            return instance?.requestGetFiles() ?: false
        }
        
        fun setLedTimeout(seconds: Int): Boolean {
            return instance?.updateLedTimeout(seconds) ?: false
        }
        
        fun requestLedTimeout(): Boolean {
            return instance?.requestLedTimeoutFromDevice() ?: false
        }
        
        fun startOtaUpdate(filePath: String): Boolean {
            return instance?.startOtaUpdate(filePath) ?: false
        }
        
        fun cancelOtaUpdate() {
            instance?.cancelOtaUpdate()
        }
        
        fun getOtaProgress(): Int {
            return instance?.getOtaProgress() ?: 0
        }
        
        fun isOtaUpdateInProgress(): Boolean {
            return instance?.isOtaUpdateInProgress() ?: false
        }
        
        fun getPhoneBatteryInfo(): Map<String, Any> {
            return mapOf(
                "level" to phoneBatteryLevel,
                "isCharging" to isPhoneCharging,
                "currentMicroAmps" to currentNowMicroAmps
            )
        }
        
        fun getBatteryHealthInfo(): Map<String, Any> {
            val readingsCount = instance?.healthReadings?.size ?: 0
            val totalEstimated = instance?.healthReadings?.sumOf { it.estimatedCapacityMah } ?: 0.0
            
            return mapOf(
                "designedCapacityMah" to designedCapacityMah,
                "estimatedCapacityMah" to estimatedCapacityMah,
                "batteryHealthPercent" to batteryHealthPercent,
                "calculationInProgress" to healthCalculationInProgress,
                "calculationStartPercent" to healthCalculationStartPercent,
                "calculationProgress" to if (healthCalculationInProgress && healthCalculationStartPercent >= 0) {
                    ((phoneBatteryLevel - healthCalculationStartPercent).coerceAtLeast(0) * 100 / HEALTH_CALCULATION_RANGE)
                } else 0,
                "healthReadingsCount" to readingsCount,
                "totalEstimatedValues" to totalEstimated
            )
        }
        
        fun startBatteryHealthCalculation(): Boolean {
            return instance?.startHealthCalculation() ?: false
        }
        
        fun stopBatteryHealthCalculation() {
            instance?.stopHealthCalculation()
        }
        
        fun resetBatteryHealthReadings(): Boolean {
            return instance?.resetHealthReadings() ?: false
        }
        
        fun setChargeLimit(limit: Int, enabled: Boolean): Boolean {
            return instance?.updateChargeLimit(limit, enabled) ?: false
        }
        
        fun setChargeLimitEnabled(enabled: Boolean): Boolean {
            return instance?.updateChargeLimitEnabled(enabled) ?: false
        }
        
        fun getAdvancedModes(): Map<String, Boolean> {
            return mapOf(
                "ghostMode" to ghostModeEnabled,
                "silentMode" to silentModeEnabled,
                "higherChargeLimit" to higherChargeLimitEnabled
            )
        }
        
        fun setGhostMode(enabled: Boolean): Boolean {
            return instance?.updateGhostMode(enabled) ?: false
        }
        
        fun setSilentMode(enabled: Boolean): Boolean {
            return instance?.updateSilentMode(enabled) ?: false
        }
        
        fun setHigherChargeLimit(enabled: Boolean): Boolean {
            return instance?.updateHigherChargeLimit(enabled) ?: false
        }
        
        fun requestAdvancedModes(): Boolean {
            return instance?.requestAdvancedModesFromDevice() ?: false
        }
        
        fun getChargeLimitInfo(): Map<String, Any> {
            return mapOf(
                "limit" to chargeLimit,
                "enabled" to chargeLimitEnabled,
                "confirmed" to chargeLimitConfirmed,
                "chargingTime" to chargingTimeSeconds,
                "dischargingTime" to dischargingTimeSeconds
            )
        }
    }

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var prefs: SharedPreferences? = null
    private val handler = Handler(Looper.getMainLooper())
    
    // UART characteristics
    private var txCharacteristic: BluetoothGattCharacteristic? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null
    private var isUartReady = false
    
    // MTU tracking
    private var currentMtu = 23 // Default BLE MTU
    
    // OTA characteristics
    private var otaDataCharacteristic: BluetoothGattCharacteristic? = null
    private var otaControlCharacteristic: BluetoothGattCharacteristic? = null
    private var isOtaInProgress = false
    
    // File streaming characteristics
    private var fileStreamingCharacteristic: BluetoothGattCharacteristic? = null
    
    // File streaming state
    private var fileStreamingAccumulatedData = StringBuilder()
    private var isFileStreamingActive = false
    private var fileStreamingNextFileRunnable: Runnable? = null
    private val FILE_STREAMING_DELAY_MS = 5000L // 5 seconds delay after ETX
    private var fileStreamingRequested = false
    private var getFilesRangePending = false
    private var getFilesRetryDone = false
    private var getFilesTimeoutRunnable: Runnable? = null
    private var serialRequested = false
    
    // File streaming data processing
    data class ChargeData(
        val timestamp: Double,
        val session: Int? = null,
        val current: Double? = null,
        val volt: Double? = null,
        val soc: Int? = null,
        val wh: Int? = null,
        val mode: Int? = null,
        val chargePhase: Int? = null,
        val chargeTime: Int? = null,
        val temperature: Double? = null,
        val faultFlags: Int? = null,
        val flags: Int? = null,
        val chargeLimit: Int? = null,
        val startupCount: Int? = null,
        val chargeProfile: Int? = null
    )
    
    private val chargeDataList = mutableListOf<ChargeData>()
    private var previousChargeData: ChargeData? = null
    private val processedDataPoints = mutableSetOf<String>()
    private var hasUnwantedCharacters = false
    private var serialNumber: String = ""
    private var currentSession = 0
    private var currentMode = 0
    private var currentChargeLimit = 0
    
    // File streaming file management
    private var leoFirstFile = 0
    private var leoLastFile = 0
    private var currentFile = 0
    private var fileCheck = 0
    private var streamFileResponseReceived = false
    private var streamFileTimeoutRunnable: Runnable? = null
    private val STREAM_FILE_TIMEOUT_MS = 10000L // 10 seconds timeout
    
    // Firebase storage
    private val firestore = FirebaseFirestore.getInstance()
    private val COLLECTION_NAME = "Beta Build 1.5.0 (122)"
    
    private var otaCancelRequested = false
    private var otaProgress = 0
    private var otaTotalPackets = 0
    private var otaCurrentPacket = 0
    private val otaReadLock = Object()
    private var lastReadValue: ByteArray? = null
    private val otaWriteLock = Object()
    private var otaWriteCompleted = false
    
    // Reconnection state
    private var reconnectRunnable: Runnable? = null
    private var reconnectAttempts = 0
    private var shouldAutoReconnect: Boolean
        get() = prefs?.getBoolean(KEY_AUTO_RECONNECT, false) ?: false
        set(value) { prefs?.edit()?.putBoolean(KEY_AUTO_RECONNECT, value)?.apply() }
    
    private var pendingConnectAddress: String? = null
    
    // Charge limit timer
    private var chargeLimitRunnable: Runnable? = null
    private var timeTrackingRunnable: Runnable? = null
    private var lastChargingState: Boolean? = null
    
    // Wake lock and keep-alive
    private var wakeLock: PowerManager.WakeLock? = null
    private var keepAliveRunnable: Runnable? = null
    private var alarmManager: AlarmManager? = null
    private var restartPendingIntent: PendingIntent? = null
    private var isServiceStopping = false
    
    // Measure command timer
    private var measureRunnable: Runnable? = null
    private val MEASURE_INTERVAL_MS = 30000L // Send measure command every 30 seconds
    private val MEASURE_INITIAL_DELAY_MS = 25000L // Initial delay before first measure command
    
    // Battery metrics timer (1 second polling)
    private var batteryMetricsRunnable: Runnable? = null
    private val BATTERY_METRICS_INTERVAL_MS = 1000L
    private var lastMetricsChargingState: Boolean? = null
    private var lastMetricsSampleTime: Long = 0
    
    // Command queue to serialize BLE writes
    private val commandQueue: ArrayDeque<String> = ArrayDeque()
    private var commandProcessing = false
    private val COMMAND_GAP_MS = 250L
    
    // Advanced modes request throttling
    private var advancedRequestInProgress = false
    private var lastAdvancedRequestMs: Long = 0
    
    // Health readings history (last 5 readings)
    private val healthReadings = mutableListOf<Companion.HealthReading>()
    
    // Battery health calculation
    private var healthCalculationRunnable: Runnable? = null
    private var lastHealthSampleTime: Long = 0
    private val HEALTH_SAMPLE_INTERVAL_MS = 1000L // Sample every 1 second
    
    // Battery session tracking
    private var currentSessionStartTime: Long = 0
    private var currentSessionInitialLevel: Int = -1
    private var currentSessionIsCharging: Boolean = false
    private var currentSessionAccumulatedMah: Double = 0.0
    private val batterySessions = mutableListOf<Companion.BatterySession>()
    
    // Backend logging
    private val logger: BackendLoggingService by lazy { BackendLoggingService.getInstance() }

    // Network connectivity monitoring
    private var connectivityManager: ConnectivityManager? = null
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            handler.post {
                android.util.Log.i("BleScanService", "[FileStream] Network connectivity restored - syncing pending uploads")
                syncPendingUploads()
            }
        }
        
        override fun onCapabilitiesChanged(network: Network, networkCapabilities: NetworkCapabilities) {
            val hasInternet = networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                             networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            if (hasInternet) {
                handler.post {
                    android.util.Log.i("BleScanService", "[FileStream] Internet connectivity validated - syncing pending uploads")
                    syncPendingUploads()
                }
            }
        }
    }

    // Battery monitoring
    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_BATTERY_CHANGED) {
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
                val status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                
                val batteryPct = (level * 100 / scale.toFloat()).toInt()
                val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL
                
                val levelChanged = phoneBatteryLevel != batteryPct
                val chargingStateChanged = isPhoneCharging != isCharging
                
                if (levelChanged || chargingStateChanged) {
                    // Reset time counters if charging state changed
                    if (chargingStateChanged) {
                        // End current session if one exists (before updating battery level)
                        if (currentSessionInitialLevel >= 0) {
                            endCurrentSession()
                        }
                        
                        // Update battery state
                        phoneBatteryLevel = batteryPct
                        isPhoneCharging = isCharging
                        
                        // Start new session
                        startNewSession(batteryPct, isCharging)
                        
                        if (isCharging) {
                            chargingTimeSeconds = 0
                            // Auto-start fresh health calculation when charger is connected
                            resetHealthCalculation()
                            if (phoneBatteryLevel <= (100 - HEALTH_CALCULATION_RANGE)) {
                                startHealthCalculation()
                                logger.logInfo("Battery health calculation auto-started - charger connected")
                            }
                        } else {
                            dischargingTimeSeconds = 0
                            // Stop and reset health calculation if unplugged
                            if (healthCalculationInProgress) {
                                stopHealthCalculation()
                                resetHealthCalculation()
                                logger.logInfo("Battery health calculation stopped and reset - charger disconnected")
                            }
                        }
                        lastChargingState = isCharging
                    } else {
                        // Just update level if no state change
                        phoneBatteryLevel = batteryPct
                    }
                    
                    // Check if health calculation is complete
                    if (healthCalculationInProgress && levelChanged) {
                        checkHealthCalculationProgress()
                    }
                    
                    // Notify Flutter about battery change
                    MainActivity.sendBatteryUpdate(phoneBatteryLevel, isPhoneCharging)
                    
                    // Update notification with battery info
                    updateNotificationWithBattery()
                    
                    // Send charge limit command on battery change
                    if (levelChanged && isUartReady && connectionState == STATE_CONNECTED) {
                        sendChargeLimitCommand()
                    }
                }
            }
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceName = device.name ?: return
            
            if (deviceName.contains(DEVICE_FILTER, ignoreCase = true)) {
                val isNew = !scannedDevices.containsKey(device.address)
                scannedDevices[device.address] = deviceName
                MainActivity.sendDeviceUpdate(device.address, deviceName)
                
                if (isNew) {
                    logger.logScan("Found device: $deviceName (${device.address})")
                    if (shouldAutoReconnect && connectionState == STATE_DISCONNECTED) {
                        attemptAutoConnect()
                    }
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            isScanning = false
            logger.logError("Scan failed with error code: $errorCode")
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            handler.post {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        connectionState = STATE_CONNECTED
                        connectedDeviceAddress = gatt.device.address
                        reconnectAttempts = 0
                        pendingConnectAddress = null
                        
                        val deviceName = gatt.device.name ?: "Leo Usb"
                        saveLastDevice(gatt.device.address, deviceName)
                        shouldAutoReconnect = true
                        
                        logger.logConnected(gatt.device.address, deviceName)
                        
                        updateNotificationWithBattery()
                        MainActivity.sendConnectionUpdate(STATE_CONNECTED, connectedDeviceAddress)
                        
                        try {
                            gatt.requestMtu(512)
                        } catch (e: SecurityException) {
                            e.printStackTrace()
                        }
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        val wasConnected = connectionState == STATE_CONNECTED
                        val previousAddress = connectedDeviceAddress ?: pendingConnectAddress
                        
                        logger.logDisconnect("Disconnected (status: $status, wasConnected: $wasConnected)")
                        
                        connectionState = STATE_DISCONNECTED
                        connectedDeviceAddress = null
                        isUartReady = false
                        txCharacteristic = null
                        rxCharacteristic = null
                        otaDataCharacteristic = null
                        otaControlCharacteristic = null
                        isOtaInProgress = false
                        otaCancelRequested = false
                        chargeLimitConfirmed = false
                        
                        // Stop charge limit timer
                        stopChargeLimitTimer()
                        stopMeasureTimer()
                        
                        closeGatt()
                        
                        if (shouldAutoReconnect && bluetoothAdapter?.isEnabled == true && previousAddress != null) {
                            if (status != BluetoothGatt.GATT_SUCCESS || wasConnected) {
                                updateNotificationWithBattery()
                                scheduleReconnect(previousAddress)
                            }
                        } else {
                            updateNotificationWithBattery()
                        }
                        
                        MainActivity.sendConnectionUpdate(STATE_DISCONNECTED, null)
                    }
                }
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    instance?.currentMtu = mtu
                    try {
                        gatt.discoverServices()
                    } catch (e: SecurityException) {
                        e.printStackTrace()
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    logger.logInfo("Services discovered")
                    setupUartService(gatt)
                    MainActivity.sendServicesDiscovered(gatt.services.map { it.uuid.toString() })
                }
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray
        ) {
            handler.post {
                if (characteristic.uuid == RX_CHAR_UUID) {
                    val receivedData = String(value, Charsets.UTF_8).trim()
                    logger.logCommandResponse(receivedData)
                    handleReceivedData(receivedData)
                    MainActivity.sendDataReceived(receivedData)
                } else if (characteristic.uuid == DATA_TRANSMIT_CHAR_UUID) {
                    // Handle file streaming data
                    processFileStreamingData(value)
                }
            }
        }

        @Deprecated("Deprecated in API 33")
        override fun onCharacteristicChanged(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic
        ) {
            handler.post {
                if (characteristic.uuid == RX_CHAR_UUID) {
                    val receivedData = String(characteristic.value, Charsets.UTF_8).trim()
                    logger.logCommandResponse(receivedData)
                    handleReceivedData(receivedData)
                    MainActivity.sendDataReceived(receivedData)
                } else if (characteristic.uuid == DATA_TRANSMIT_CHAR_UUID) {
                    // Handle file streaming data
                    characteristic.value?.let { value ->
                        processFileStreamingData(value)
                    }
                }
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    // Write successful
                    if (isOtaInProgress && 
                        (characteristic.uuid == OTA_DATA_CHAR_UUID || 
                         characteristic.uuid == OTA_CONTROL_CHAR_UUID)) {
                        // OTA write completed - notify waiting thread
                        synchronized(otaWriteLock) {
                            otaWriteCompleted = true
                            otaWriteLock.notify()
                        }
                    }
                } else {
                    // Write failed
                    if (isOtaInProgress) {
                        synchronized(otaWriteLock) {
                            otaWriteCompleted = true
                            otaWriteLock.notify()
                        }
                        MainActivity.sendOtaProgress(0, false, "Write failed: status $status")
                        isOtaInProgress = false
                    }
                }
            }
        }
        
        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS && isOtaInProgress) {
                    val value = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        characteristic.value
                    } else {
                        @Suppress("DEPRECATION")
                        characteristic.value
                    }
                    if (value != null && value.isNotEmpty() && characteristic.uuid == OTA_CONTROL_CHAR_UUID) {
                        // Handle OTA control response
                        synchronized(otaReadLock) {
                            lastReadValue = value
                            otaReadLock.notify()
                        }
                    }
                }
            }
        }

        override fun onDescriptorWrite(
            gatt: BluetoothGatt,
            descriptor: BluetoothGattDescriptor,
            status: Int
        ) {
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS && descriptor.uuid == CCCD_UUID) {
                    isUartReady = true
                    MainActivity.sendUartReady(true)
                    
                    // Start charge limit timer and send initial command
                    startChargeLimitTimer()
                    startTimeTracking()
                    startMeasureTimer()
                    
                    // Send initial charge limit command
                    handler.postDelayed({
                        sendChargeLimitCommand()
                    }, 500)
                    
                    // Fetch LED timeout value after UART is ready
                    handler.postDelayed({
                        requestLedTimeoutFromDevice()
                    }, 700)
                    
                    // Fetch advanced modes state after initial setup
                    handler.postDelayed({
                        requestAdvancedModesFromDevice()
                    }, 1100)

                    // Request serial (one-shot, no py_msg needed)
                    handler.postDelayed({
                        if (!serialRequested &&
                            connectionState == STATE_CONNECTED &&
                            isUartReady
                        ) {
                            serialRequested = enqueueCommand("serial")
                            android.util.Log.i("BleScanService", "[FileStream] serial requested (no py_msg): $serialRequested")
                        }
                    }, 1700)
                    
                    // Sync pending uploads when UART is ready (in case connectivity was restored)
                    handler.postDelayed({
                        syncPendingUploads()
                    }, 4000)

                    // Start file listing once UART is ready and all initial commands are queued (send last)
                    handler.postDelayed({
                        if (!fileStreamingRequested &&
                            connectionState == STATE_CONNECTED &&
                            fileStreamingCharacteristic != null
                        ) {
                            getFilesRangePending = false
                            getFilesRetryDone = false
                            fileStreamingRequested = requestGetFiles()
                            android.util.Log.i("BleScanService", "[FileStream] get_files requested after UART ready (sent last): $fileStreamingRequested")
                        }
                    }, 3000)
                }
            }
        }
    }

    private fun handleReceivedData(data: String) {
        val parts = data.split(" ")
        
        // Handle charge_limit response
        if (parts.size >= 4 && parts[2] == "charge_limit") {
            val numeric = parts[3].filter { it.isDigit() }.toIntOrNull()
            if (numeric != null) {
                chargeLimitConfirmed = numeric == 1
                MainActivity.sendChargeLimitConfirmed(chargeLimitConfirmed)
                handleAdvancedModeResponse("charge_limit", numeric)
            }
        }
        
        // Handle ghost_mode response
        if (parts.size >= 4 && parts[2] == "ghost_mode") {
            val numeric = parts[3].filter { it.isDigit() }.toIntOrNull()
            if (numeric != null) {
                handleAdvancedModeResponse("ghost_mode", numeric)
            }
        }
        
        // Handle quiet_mode response
        if (parts.size >= 4 && parts[2] == "quiet_mode") {
            val numeric = parts[3].filter { it.isDigit() }.toIntOrNull()
            if (numeric != null) {
                handleAdvancedModeResponse("quiet_mode", numeric)
            }
        }
        
        // Handle LED timeout response: OK py_msg led_time_before_dim <seconds>
        if (parts.size >= 4 && parts.getOrNull(2) == "led_time_before_dim") {
            val rawValue = parts[3].trim()
            val numericOnly = rawValue.filter { it.isDigit() }
            val parsed = numericOnly.toIntOrNull()
            if (parsed != null) {
                ledTimeoutSeconds = parsed
                prefs?.edit()?.putInt(KEY_LED_TIMEOUT, parsed)?.apply()
                MainActivity.sendLedTimeoutUpdate(ledTimeoutSeconds)
            }
        }
        
        // Handle measure response: "OK measure voltage current"
        // parts[1] == "measure", parts[2] is voltage, parts[3] is current
        if (parts.size >= 4 && parts.getOrNull(1) == "measure") {
            try {
                val voltage = parts[2].toDoubleOrNull()
                val current = parts[3].toDoubleOrNull()
                
                if (voltage != null && current != null) {
                    val voltageStr = String.format("%.3f", voltage)
                    val currentStr = String.format("%.3f", kotlin.math.abs(current))
                    MainActivity.sendMeasureData(voltageStr, currentStr)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        
        // Handle swversion response
        if (parts.size >= 3 && parts.getOrNull(1)?.equals("swversion", ignoreCase = true) == true) {
            val versionValue = parts[2].trim()
            if (versionValue.isNotEmpty()) {
                firmwareVersion = versionValue
            }
        }

        // Handle serial response (command: "serial" without py_msg)
        if (parts.size >= 3 && parts.getOrNull(1)?.equals("serial", ignoreCase = true) == true) {
                val serialValue = parts.getOrNull(2)?.trim()
                if (!serialValue.isNullOrEmpty()) {
                    serialNumber = serialValue
                    prefs?.edit()?.putString(KEY_SERIAL_NUMBER, serialNumber)?.apply()
                    android.util.Log.i("BleScanService", "[FileStream] Serial received and saved: $serialNumber")
                }
        }
        
        // Handle get_files response: "OK py_msg get_files <startFile> <endFile>"
        if (parts.getOrNull(2) == "get_files") {
            android.util.Log.i("BleScanService", "[FileStream] get_files response raw parts: $parts")
            try {
                val startFile = parts.getOrNull(3)?.toIntOrNull()
                val endFile = parts.getOrNull(4)?.toIntOrNull()
                
                if (startFile != null && endFile != null) {
                    getFilesRangePending = false
                    leoFirstFile = startFile
                    leoLastFile = endFile
                    currentFile = leoFirstFile
                    
                    android.util.Log.i("BleScanService", "[FileStream] ========================================")
                    android.util.Log.i("BleScanService", "[FileStream] get_files response received")
                    android.util.Log.i("BleScanService", "[FileStream] File range: $startFile to $endFile")
                    android.util.Log.i("BleScanService", "[FileStream] Starting file streaming from file $currentFile")
                    android.util.Log.i("BleScanService", "[FileStream] ========================================")
                    
                // Start streaming from first file
                startFileStreaming()
                    getFilesRangePending = false
                    getFilesTimeoutRunnable?.let { handler.removeCallbacks(it) }
                } else if (getFilesRangePending) {
                    // One controlled retry of get_files + py_msg if range missing and not retried yet
                    if (!getFilesRetryDone) {
                        getFilesRetryDone = true
                        android.util.Log.w("BleScanService", "[FileStream] get_files response missing range; scheduling one retry")
                        handler.postDelayed({
                            if (isUartReady && connectionState == STATE_CONNECTED) {
                                enqueueCommand("app_msg get_files")
                                handler.postDelayed({
                                    if (isUartReady && connectionState == STATE_CONNECTED) {
                                        enqueueCommand("py_msg")
                                        android.util.Log.i("BleScanService", "[FileStream] py_msg sent after retry get_files")
                                    }
                                }, 300)
                            }
                        }, 1200)
                    } else {
                        android.util.Log.w("BleScanService", "[FileStream] get_files response missing range after retry, aborting file stream start")
                        getFilesRangePending = false
                        getFilesTimeoutRunnable?.let { handler.removeCallbacks(it) }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("BleScanService", "[FileStream] Error parsing get_files response: ${e.message}")
            }
        }
        
        // Handle stream_file response: "OK py_msg stream_file <fileCheck>"
        // fileCheck: 1 = file exists and streaming started, -1 = file doesn't exist
        if (parts.size >= 4 && parts.getOrNull(2) == "stream_file") {
            try {
                val fileCheckValue = parts[3].toIntOrNull()
                
                if (fileCheckValue != null) {
                    fileCheck = fileCheckValue
                    android.util.Log.i("BleScanService", "[FileStream] stream_file response: fileCheck=$fileCheck for file $currentFile")
                    
                    when (fileCheck) {
                        1 -> {
                            // File exists and is being streamed, wait for ETX
                            android.util.Log.i("BleScanService", "[FileStream] File $currentFile exists and streaming started")
                            streamFileResponseReceived = true
                            isFileStreamingActive = true
                            // Start timeout timer
                            startStreamFileTimeout()
                        }
                        -1 -> {
                            // File doesn't exist, move to next file
                            android.util.Log.w("BleScanService", "[FileStream] File $currentFile doesn't exist, moving to next")
                            cancelStreamFileTimeout()
                            
                            if (currentFile < leoLastFile) {
                                currentFile++
                                android.util.Log.i("BleScanService", "[FileStream] Moving to next file: $currentFile")
                                requestNextFile()
                            } else {
                                android.util.Log.i("BleScanService", "[FileStream] Reached last file ($leoLastFile), no more files to stream")
                                stopFileStreaming()
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("BleScanService", "[FileStream] Error parsing stream_file response: ${e.message}")
            }
        }
    }
    
    private fun requestGetFiles(): Boolean {
        if (connectionState != STATE_CONNECTED || !isUartReady) {
            android.util.Log.w("BleScanService", "[FileStream] Cannot request get_files - not connected or UART not ready")
            return false
        }
        
        android.util.Log.i("BleScanService", "[FileStream] ========================================")
        android.util.Log.i("BleScanService", "[FileStream] Starting file streaming process")
        android.util.Log.i("BleScanService", "[FileStream] Sending get_files command")
        android.util.Log.i("BleScanService", "[FileStream] ========================================")
        
        getFilesRangePending = true
        getFilesRetryDone = false
        getFilesTimeoutRunnable?.let { handler.removeCallbacks(it) }
        enqueueCommand("app_msg get_files")
        handler.postDelayed({
            if (isUartReady && connectionState == STATE_CONNECTED) {
                enqueueCommand("py_msg")
                android.util.Log.i("BleScanService", "[FileStream] py_msg sent 300ms after get_files")
            }
        }, 300)
        // One-shot timeout to nudge range if still pending
        getFilesTimeoutRunnable = Runnable {
            if (getFilesRangePending && isUartReady && connectionState == STATE_CONNECTED) {
                android.util.Log.w("BleScanService", "[FileStream] get_files range still pending; sending py_msg reminder")
                enqueueCommand("py_msg")
            }
        }
        handler.postDelayed(getFilesTimeoutRunnable!!, 2000)
        return true
    }
    
    private fun startFileStreaming() {
        if (connectionState != STATE_CONNECTED || !isUartReady) {
            android.util.Log.w("BleScanService", "[FileStream] Cannot start file streaming - not connected or UART not ready")
            return
        }
        
        isFileStreamingActive = true
        currentFile = leoFirstFile
        
        android.util.Log.i("BleScanService", "[FileStream] Requesting file $currentFile")
        enqueueCommand("app_msg stream_file $currentFile")
        handler.postDelayed({
            if (isUartReady && connectionState == STATE_CONNECTED) {
                enqueueCommand("py_msg")
            }
        }, 250)
    }
    
    private fun requestNextFile() {
        if (connectionState != STATE_CONNECTED || !isUartReady) {
            android.util.Log.w("BleScanService", "[FileStream] Cannot request next file - not connected")
            return
        }
        
        android.util.Log.i("BleScanService", "[FileStream] Requesting file $currentFile")
        enqueueCommand("app_msg stream_file $currentFile")
        handler.postDelayed({
            if (isUartReady && connectionState == STATE_CONNECTED) {
                enqueueCommand("py_msg")
            }
        }, 250)
    }
    
    private fun startStreamFileTimeout() {
        cancelStreamFileTimeout()
        
        streamFileTimeoutRunnable = Runnable {
            android.util.Log.w("BleScanService", "[FileStream] ========================================")
            android.util.Log.w("BleScanService", "[FileStream] Stream file timeout - no response received for file $currentFile")
            android.util.Log.w("BleScanService", "[FileStream] ========================================")
            
            streamFileResponseReceived = false
            isFileStreamingActive = false
            
            // Move to next file if available
            if (currentFile < leoLastFile && connectionState == STATE_CONNECTED) {
                currentFile++
                android.util.Log.i("BleScanService", "[FileStream] Moving to next file due to timeout: $currentFile")
                requestNextFile()
            } else if (currentFile == leoLastFile) {
                // Retry last file once more
                android.util.Log.i("BleScanService", "[FileStream] Retrying last file due to timeout: $currentFile")
                requestNextFile()
            } else {
                android.util.Log.i("BleScanService", "[FileStream] Timeout on file beyond last file. Stopping file streaming.")
                stopFileStreaming()
            }
        }
        
        handler.postDelayed(streamFileTimeoutRunnable!!, STREAM_FILE_TIMEOUT_MS)
    }
    
    private fun cancelStreamFileTimeout() {
        streamFileTimeoutRunnable?.let {
            handler.removeCallbacks(it)
            streamFileTimeoutRunnable = null
        }
    }
    
    private fun stopFileStreaming() {
        isFileStreamingActive = false
        streamFileResponseReceived = false
        cancelStreamFileTimeout()
        android.util.Log.i("BleScanService", "[FileStream] File streaming stopped")
    }

    private fun handleAdvancedModeResponse(mode: String, value: Int) {
        when (mode) {
            "ghost_mode" -> updateAdvancedModeState(ghost = value == 1)
            "quiet_mode" -> updateAdvancedModeState(silent = value == 1)
            "charge_limit" -> updateAdvancedModeState(higherCharge = value == 1)
        }
    }

    private fun setupUartService(gatt: BluetoothGatt) {
        val uartService = gatt.getService(SERVICE_UUID) ?: return

        txCharacteristic = uartService.getCharacteristic(TX_CHAR_UUID)
        rxCharacteristic = uartService.getCharacteristic(RX_CHAR_UUID)
        
        rxCharacteristic?.let { rxChar ->
            try {
                gatt.setCharacteristicNotification(rxChar, true)
                
                val descriptor = rxChar.getDescriptor(CCCD_UUID)
                descriptor?.let {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        gatt.writeDescriptor(it, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                    } else {
                        @Suppress("DEPRECATION")
                        it.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        gatt.writeDescriptor(it)
                    }
                }
            } catch (e: SecurityException) {
                e.printStackTrace()
            }
        }
        
        // Setup OTA service
        setupOtaService(gatt)
        
        // Setup file streaming service
        setupFileStreamingService(gatt)
    }
    
    private fun setupOtaService(gatt: BluetoothGatt) {
        val otaService = gatt.getService(OTA_SERVICE_UUID)
        
        if (otaService == null) {
            android.util.Log.w("BleScanService", "OTA service not found. UUID: $OTA_SERVICE_UUID")
            android.util.Log.d("BleScanService", "Available services: ${gatt.services.map { it.uuid }}")
            return
        }
        
        android.util.Log.d("BleScanService", "OTA service found")
        
        otaDataCharacteristic = otaService.getCharacteristic(OTA_DATA_CHAR_UUID)
        otaControlCharacteristic = otaService.getCharacteristic(OTA_CONTROL_CHAR_UUID)
        
        if (otaDataCharacteristic == null) {
            android.util.Log.w("BleScanService", "OTA data characteristic not found. UUID: $OTA_DATA_CHAR_UUID")
            android.util.Log.d("BleScanService", "Available characteristics in OTA service: ${otaService.characteristics.map { it.uuid }}")
        } else {
            android.util.Log.d("BleScanService", "OTA data characteristic found")
        }
        
        if (otaControlCharacteristic == null) {
            android.util.Log.w("BleScanService", "OTA control characteristic not found. UUID: $OTA_CONTROL_CHAR_UUID")
        } else {
            android.util.Log.d("BleScanService", "OTA control characteristic found")
        }
    }
    
    private fun setupFileStreamingService(gatt: BluetoothGatt) {
        val fileStreamingService = gatt.getService(DATA_TRANSFER_SERVICE_UUID)
        
        if (fileStreamingService == null) {
            android.util.Log.w("BleScanService", "File streaming service not found. UUID: $DATA_TRANSFER_SERVICE_UUID")
            android.util.Log.d("BleScanService", "Available services: ${gatt.services.map { it.uuid }}")
            return
        }
        
        android.util.Log.d("BleScanService", "File streaming service found")
        
        fileStreamingCharacteristic = fileStreamingService.getCharacteristic(DATA_TRANSMIT_CHAR_UUID)
        
        if (fileStreamingCharacteristic == null) {
            android.util.Log.w("BleScanService", "File streaming characteristic not found. UUID: $DATA_TRANSMIT_CHAR_UUID")
            android.util.Log.d("BleScanService", "Available characteristics in file streaming service: ${fileStreamingService.characteristics.map { it.uuid }}")
            return
        }
        
        android.util.Log.d("BleScanService", "File streaming characteristic found")
        
        // Enable notifications for file streaming
        fileStreamingCharacteristic?.let { char ->
            try {
                gatt.setCharacteristicNotification(char, true)
                
                val descriptor = char.getDescriptor(CCCD_UUID)
                descriptor?.let {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        gatt.writeDescriptor(it, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                    } else {
                        @Suppress("DEPRECATION")
                        it.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        gatt.writeDescriptor(it)
                    }
                }
                android.util.Log.d("BleScanService", "File streaming notifications enabled")

                // Kick off get_files once notifications are active
                if (!fileStreamingRequested) {
                    fileStreamingRequested = requestGetFiles()
                    android.util.Log.i("BleScanService", "[FileStream] get_files requested automatically after enable: $fileStreamingRequested")
                }
            } catch (e: SecurityException) {
                android.util.Log.e("BleScanService", "Failed to enable file streaming notifications: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    private fun processFileStreamingData(data: ByteArray) {
        try {
            val receivedString = String(data, Charsets.UTF_8)
            android.util.Log.d("BleScanService", "[FileStream] Received ${data.size} bytes")
            
            // Append incoming data to accumulatedData
            fileStreamingAccumulatedData.append(receivedString)
            android.util.Log.v("BleScanService", "[FileStream] Accumulated data length: ${fileStreamingAccumulatedData.length}")
            
            // Split the accumulated data by newline (\n) to identify potential complete data points
            val allDataPoints = fileStreamingAccumulatedData.toString().split('\n')
            
            var stxDetected = false
            var etxDetected = false
            
            // Process all complete data points except the last one
            for (i in 0 until allDataPoints.size - 1) {
                var dataPoint = allDataPoints[i]
                
                // Detect and remove STX/ETX control characters
                if (dataPoint.contains('\u0002')) {
                    stxDetected = true
                    dataPoint = dataPoint.replace("\u0002", "")
                    android.util.Log.i("BleScanService", "[FileStream] STX detected in data point")
                }
                if (dataPoint.contains('\u0003')) {
                    etxDetected = true
                    dataPoint = dataPoint.replace("\u0003", "")
                    android.util.Log.i("BleScanService", "[FileStream] ETX detected in data point")
                }
                
                dataPoint = dataPoint.trim()
                
                // Skip empty data points
                if (dataPoint.isEmpty()) continue
                
                // Split the data into columns
                val columns = dataPoint.split(';')
                
                // Backward compatibility: Only require valid timestamp (column 0)
                if (columns.isEmpty() || columns[0].isEmpty() || columns[0].trim().isEmpty()) {
                    android.util.Log.d("BleScanService", "[FileStream] Skipped data with empty timestamp: ${dataPoint.take(50)}")
                    continue
                }
                
                // Skip header rows (e.g., timestamp;session;...)
                if (columns[0].trim().lowercase() == "timestamp") {
                    android.util.Log.d("BleScanService", "[FileStream] Skipped header row")
                    continue
                }
                
                // Check for unwanted characters in the data point
                if (dataPoint.contains('/') || dataPoint.contains('M') || dataPoint.contains('m')) {
                    hasUnwantedCharacters = true
                    android.util.Log.w("BleScanService", "[FileStream] Found unwanted characters in data point")
                }
                
                // Check if the data point is already processed
                if (!processedDataPoints.contains(dataPoint)) {
                    processedDataPoints.add(dataPoint)
                    
                    // Parse the data point to ChargeData
                    try {
                        // Parse timestamp (required field) - must be valid, skip if invalid
                        val timestampValue = parseOrNull(columns[0]) { it.toDouble() }
                        
                        if (timestampValue == null) {
                            android.util.Log.d("BleScanService", "[FileStream] Skipped data with invalid timestamp: ${dataPoint.take(50)}")
                            continue
                        }
                        
                        val timestamp = timestampValue
                        
                        // Parse all fields with carry-forward logic
                        val session = getValueOrPrevious(1, columns) { it.toInt() } ?: previousChargeData?.session
                        val current = getValueOrPrevious(2, columns) { it.toDouble() } ?: previousChargeData?.current
                        val volt = getValueOrPrevious(3, columns) { it.toDouble() } ?: previousChargeData?.volt
                        val soc = getValueOrPrevious(4, columns) { it.toInt() } ?: previousChargeData?.soc
                        val wh = getValueOrPrevious(5, columns) { it.toInt() } ?: previousChargeData?.wh
                        val mode = getValueOrPrevious(6, columns) { it.toInt() } ?: previousChargeData?.mode
                        val chargePhase = getValueOrPrevious(7, columns) { it.toInt() } ?: previousChargeData?.chargePhase
                        val chargeTime = getValueOrPrevious(8, columns) { it.toInt() } ?: previousChargeData?.chargeTime
                        val temperature = getValueOrPrevious(9, columns) { it.toDouble() } ?: previousChargeData?.temperature
                        val faultFlags = getValueOrPrevious(10, columns) { it.toInt() } ?: previousChargeData?.faultFlags
                        val flags = getValueOrPrevious(11, columns) { it.toInt() } ?: previousChargeData?.flags
                        val chargeLimit = getValueOrPrevious(12, columns) { it.toInt() } ?: previousChargeData?.chargeLimit
                        val startupCount = getValueOrPrevious(13, columns) { it.toInt() } ?: previousChargeData?.startupCount
                        val chargeProfile = getValueOrPrevious(14, columns) { it.toInt() } ?: previousChargeData?.chargeProfile
                        
                        val dataEntry = ChargeData(
                            timestamp = timestamp,
                            session = session,
                            current = current,
                            volt = volt,
                            soc = soc,
                            wh = wh,
                            mode = mode,
                            chargePhase = chargePhase,
                            chargeTime = chargeTime,
                            temperature = temperature,
                            faultFlags = faultFlags,
                            flags = flags,
                            chargeLimit = chargeLimit,
                            startupCount = startupCount,
                            chargeProfile = chargeProfile
                        )
                        
                        // Update instance variables for backward compatibility
                        if (dataEntry.session != null) {
                            currentSession = dataEntry.session!!
                        }
                        if (dataEntry.mode != null) {
                            currentMode = dataEntry.mode!!
                        }
                        if (dataEntry.chargeLimit != null) {
                            currentChargeLimit = dataEntry.chargeLimit!!
                        }
                        
                        // Update previous entry for next iteration
                        previousChargeData = dataEntry
                        chargeDataList.add(dataEntry)
                        
                        android.util.Log.v("BleScanService", "[FileStream] Parsed ChargeData: session=${dataEntry.session}, timestamp=${dataEntry.timestamp}, total entries=${chargeDataList.size}")
                        
                    } catch (e: Exception) {
                        android.util.Log.e("BleScanService", "[FileStream] Error parsing data: ${e.message}")
                        // Try to create minimal entry with just timestamp
                        try {
                            val timestampValue = parseOrNull(columns[0]) { it.toDouble() }
                            if (timestampValue != null) {
                                val minimalEntry = ChargeData(
                                    timestamp = timestampValue,
                                    session = previousChargeData?.session,
                                    current = previousChargeData?.current,
                                    volt = previousChargeData?.volt,
                                    soc = previousChargeData?.soc,
                                    wh = previousChargeData?.wh,
                                    mode = previousChargeData?.mode,
                                    chargePhase = previousChargeData?.chargePhase,
                                    chargeTime = previousChargeData?.chargeTime,
                                    temperature = previousChargeData?.temperature,
                                    faultFlags = previousChargeData?.faultFlags,
                                    flags = previousChargeData?.flags,
                                    chargeLimit = previousChargeData?.chargeLimit,
                                    startupCount = previousChargeData?.startupCount,
                                    chargeProfile = previousChargeData?.chargeProfile
                                )
                                previousChargeData = minimalEntry
                                chargeDataList.add(minimalEntry)
                                android.util.Log.d("BleScanService", "[FileStream] Created minimal entry from malformed data")
                            }
                        } catch (e2: Exception) {
                            android.util.Log.e("BleScanService", "[FileStream] Could not create minimal entry: ${e2.message}")
                        }
                    }
                }
            }
            
            // Retain the last (possibly incomplete) data point
            if (allDataPoints.isNotEmpty()) {
                var lastDataPoint = allDataPoints.last()
                if (lastDataPoint.contains('\u0002')) {
                    stxDetected = true
                    lastDataPoint = lastDataPoint.replace("\u0002", "")
                }
                if (lastDataPoint.contains('\u0003')) {
                    etxDetected = true
                    lastDataPoint = lastDataPoint.replace("\u0003", "")
                }
                fileStreamingAccumulatedData.clear()
                fileStreamingAccumulatedData.append(lastDataPoint.trim())
            } else {
                fileStreamingAccumulatedData.clear()
            }
            
            // Handle start (STX) and end (ETX) indicators
            if (stxDetected || fileStreamingAccumulatedData.toString().contains('\u0002')) {
                android.util.Log.i("BleScanService", "[FileStream] ========================================")
                android.util.Log.i("BleScanService", "[FileStream] STX detected - Stream start for file $currentFile")
                android.util.Log.i("BleScanService", "[FileStream] ========================================")
                isFileStreamingActive = true
                streamFileResponseReceived = true
                previousChargeData = null // Reset previous data for new stream
                chargeDataList.clear()
                processedDataPoints.clear()
                hasUnwantedCharacters = false
                // Cancel timeout since we received STX
                cancelStreamFileTimeout()
            }
            
            if (etxDetected || fileStreamingAccumulatedData.toString().contains('\u0003')) {
                android.util.Log.i("BleScanService", "[FileStream] ========================================")
                android.util.Log.i("BleScanService", "[FileStream] ETX detected - Stream end for file $currentFile")
                android.util.Log.i("BleScanService", "[FileStream] Processed ${chargeDataList.size} data entries")
                android.util.Log.i("BleScanService", "[FileStream] Session: $currentSession, Mode: $currentMode, ChargeLimit: $currentChargeLimit")
                android.util.Log.i("BleScanService", "[FileStream] ========================================")
                
                isFileStreamingActive = false
                cancelStreamFileTimeout()
                
                // Store data to Firebase/local storage using snapshot of current list
                val dataSnapshot = chargeDataList.toList()
                val fileNumberToDelete = currentFile // Capture current file number for deletion after upload
                if (!hasUnwantedCharacters) {
                    storeDataToFirebase(dataSnapshot, fileNumberToDelete)
                } else {
                    android.util.Log.w("BleScanService", "[FileStream] Skipping Firebase upload due to unwanted characters in data")
                }
                
                // Reset for next file
                fileStreamingAccumulatedData.clear()
                chargeDataList.clear()
                previousChargeData = null
                processedDataPoints.clear()
                hasUnwantedCharacters = false
                streamFileResponseReceived = false
                
                // Schedule next file command after 15 seconds delay
                scheduleNextFileStreamCommand()
            }
            
        } catch (e: Exception) {
            android.util.Log.e("BleScanService", "[FileStream] Error processing file streaming data: ${e.message}")
            e.printStackTrace()
        }
    }
    
    // Helper function to parse a value or return null if empty/invalid
    private inline fun <T> parseOrNull(value: String, parser: (String) -> T): T? {
        if (value.isEmpty() || value.trim().isEmpty()) {
            return null
        }
        return try {
            parser(value.trim())
        } catch (e: Exception) {
            null
        }
    }
    
    // Helper function to get value from column or use previous value
    @Suppress("UNCHECKED_CAST")
    private inline fun <T> getValueOrPrevious(index: Int, columns: List<String>, parser: (String) -> T): T? {
        if (index < columns.size) {
            val parsed = parseOrNull(columns[index], parser)
            if (parsed != null) return parsed
        }
        // If parsing failed or column doesn't exist, use previous value
        return previousChargeData?.let {
            when (index) {
                1 -> it.session as? T
                2 -> it.current as? T
                3 -> it.volt as? T
                4 -> it.soc as? T
                5 -> it.wh as? T
                6 -> it.mode as? T
                7 -> it.chargePhase as? T
                8 -> it.chargeTime as? T
                9 -> it.temperature as? T
                10 -> it.faultFlags as? T
                11 -> it.flags as? T
                12 -> it.chargeLimit as? T
                13 -> it.startupCount as? T
                14 -> it.chargeProfile as? T
                else -> null
            }
        }
    }
    
    private fun storeDataToFirebase(dataSnapshot: List<ChargeData> = chargeDataList.toList(), fileNumber: Int = currentFile) {
        handler.post {
            try {
                android.util.Log.i("BleScanService", "[FileStream] ========================================")
                android.util.Log.i("BleScanService", "[FileStream] Starting Firebase storage process")
                android.util.Log.i("BleScanService", "[FileStream] Session: $currentSession, Entries: ${dataSnapshot.size}")
                
                if (dataSnapshot.isEmpty()) {
                    android.util.Log.w("BleScanService", "[FileStream] No data to upload, skipping")
                    return@post
                }
                
                // Get the list of sent sessions from SharedPreferences
                val sentSessions = prefs?.getStringSet("sentSessions_${connectedDeviceAddress?.replace(":", "")}", mutableSetOf()) ?: mutableSetOf()
                
                // Check if this session has already been sent
                if (sentSessions.contains(currentSession.toString())) {
                    android.util.Log.i("BleScanService", "[FileStream] Session $currentSession already sent to Firebase, skipping...")
                    return@post
                }
                
                // Get device info from SharedPreferences (set by Dart side)
                if (serialNumber.isEmpty()) {
                    serialNumber = prefs?.getString(KEY_SERIAL_NUMBER, "") ?: ""
                }
                val binFileName = firmwareVersion
                val appVersion = prefs?.getString("appVersion", "1.0.0") ?: "1.0.0"
                val appBuildNumber = prefs?.getString("appBuildNumber", "1") ?: "1"
                val osVersion = prefs?.getString("osVersion", "") ?: ""
                val deviceBrand = prefs?.getString("deviceBrand", "") ?: ""
                val deviceModel = prefs?.getString("deviceModel", "") ?: ""
                
                if (serialNumber.isEmpty()) {
                    android.util.Log.w("BleScanService", "[FileStream] Serial number not available, skipping upload")
                    return@post
                }
                
                // Prepare the data for Firebase
                val firebaseData = dataSnapshot.map { chargeData ->
                    // Convert flags to binary and extract individual boolean values
                    val flagsValue = chargeData.flags ?: 0
                    val binaryFlags = flagsValue.toString(2).padStart(8, '0')
                    val ghostMode = if (binaryFlags.length > 7) binaryFlags[7] == '1' else false
                    val higherChargeLimit = if (binaryFlags.length > 6) binaryFlags[6] == '1' else false
                    val silent = if (binaryFlags.length > 5) binaryFlags[5] == '1' else false
                    
                    mapOf(
                        "ts" to chargeData.timestamp,
                        "c" to chargeData.current,
                        "v" to chargeData.volt,
                        "soc" to chargeData.soc,
                        "mwh" to chargeData.wh,
                        "cp" to chargeData.chargePhase,
                        "ct" to chargeData.chargeTime,
                        "temp" to chargeData.temperature,
                        "ff" to chargeData.faultFlags,
                        "cl" to chargeData.chargeLimit,
                        "sc" to chargeData.startupCount,
                        "cprofile" to chargeData.chargeProfile
                    )
                }
                
                // Parse app version
                val versionParts = appVersion.split('.')
                val major = if (versionParts.isNotEmpty()) versionParts[0].toIntOrNull() ?: 0 else 0
                val minor = if (versionParts.size > 1) versionParts[1].toIntOrNull() ?: 0 else 0
                val patch = if (versionParts.size > 2) versionParts[2].toIntOrNull() ?: 0 else 0
                val build = appBuildNumber.toIntOrNull() ?: 1
                
                // Get flags from first entry (they should be consistent across entries)
                val firstFlags = dataSnapshot.firstOrNull()?.flags ?: 0
                val binaryFlags = firstFlags.toString(2).padStart(8, '0')
                val ghostMode = if (binaryFlags.length > 7) binaryFlags[7] == '1' else false
                val higherChargeLimit = if (binaryFlags.length > 6) binaryFlags[6] == '1' else false
                val silent = if (binaryFlags.length > 5) binaryFlags[5] == '1' else false
                
                // Construct the complete object to store
                val firebaseObject = mapOf(
                    "model" to "Leo",
                    "serial_number" to serialNumber.split("\\").first().trim(),
                    "firmware" to binFileName.trim(),
                    "sw" to mapOf(
                        "type" to "Release",
                        "major" to major,
                        "minor" to minor,
                        "patch" to patch,
                        "build" to build
                    ),
                    "device" to mapOf(
                        "type" to "mobile",
                        "os" to "Android",
                        "version" to (osVersion.toIntOrNull() ?: osVersion),
                        "brand" to deviceBrand,
                        "model" to deviceModel
                    ),
                    "session" to currentSession,
                    "mode" to currentMode,
                    "flags" to mapOf(
                        "charge_limit" to currentChargeLimit,
                        "ghost_mode_beta" to ghostMode,
                        "higher_charge_limit" to higherChargeLimit,
                        "silent" to silent
                    ),
                    "timestamp" to (System.currentTimeMillis() / 1000),
                    "DateTime" to SimpleDateFormat("dd-MM-yyyy HH:mm:ss", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.format(Date()),
                    "data" to firebaseData
                )
                
                // Generate a file name for Firebase
                val fileName = "${SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }.format(Date())}_${serialNumber.trim()}_$currentSession.json"
                
                android.util.Log.i("BleScanService", "[FileStream] Prepared Firebase object")
                android.util.Log.d("BleScanService", "[FileStream] File name: $fileName")
                android.util.Log.d("BleScanService", "[FileStream] Serial: $serialNumber, Session: $currentSession")
                android.util.Log.d("BleScanService", "[FileStream] Data entries: ${firebaseData.size}")
                
                // Check connectivity (simplified - in production, use proper network check)
                val isOnline = try {
                    val runtime = Runtime.getRuntime()
                    val process = runtime.exec("ping -c 1 8.8.8.8")
                    val exited = process.waitFor(500, TimeUnit.MILLISECONDS)
                    val exitCode = if (exited) process.exitValue() else -1
                    exited && exitCode == 0
                } catch (e: Exception) {
                    false
                }
                
                if (!isOnline) {
                    android.util.Log.w("BleScanService", "[FileStream] No internet connection. Saving data locally for later sync.")
                    saveToLocalStorage(serialNumber, currentSession.toString(), fileName, firebaseObject, fileNumber)
                } else {
                    android.util.Log.i("BleScanService", "[FileStream] Internet connection available. Uploading to Firebase...")
                    uploadToFirebase(fileName, firebaseObject, currentSession.toString(), serialNumber, sentSessions, fileNumber)
                }
                
            } catch (e: Exception) {
                android.util.Log.e("BleScanService", "[FileStream] Error storing data to Firebase: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    private fun uploadToFirebase(
        fileName: String,
        firebaseObject: Map<String, Any>,
        sessionId: String,
        serialNumber: String,
        sentSessions: MutableSet<String>,
        fileNumber: Int
    ) {
        try {
            val docId = fileName.split(".json").first()
            
            firestore.collection(COLLECTION_NAME)
                .document(docId)
                .set(firebaseObject, SetOptions.merge())
                .addOnSuccessListener {
                    android.util.Log.i("BleScanService", "[FileStream] ========================================")
                    android.util.Log.i("BleScanService", "[FileStream] Data successfully stored to Firebase!")
                    android.util.Log.i("BleScanService", "[FileStream] Document ID: $docId")
                    android.util.Log.i("BleScanService", "[FileStream] Session: $sessionId")
                    android.util.Log.i("BleScanService", "[FileStream] ========================================")
                    
                    // Add this session to the list of sent sessions
                    sentSessions.add(sessionId)
                    prefs?.edit()?.putStringSet("sentSessions_${connectedDeviceAddress?.replace(":", "")}", sentSessions)?.apply()
                    
                    // Remove from pending uploads if it was a retry
                    val pendingKey = "pending_upload_${serialNumber}_$sessionId"
                    prefs?.edit()?.remove(pendingKey)?.remove("${pendingKey}_data")?.apply()
                    
                    // Delete file from device after successful upload
                    if (fileNumber >= 0 && connectionState == STATE_CONNECTED && isUartReady) {
                        handler.postDelayed({
                            enqueueCommand("app_msg rm_file $fileNumber")
                            android.util.Log.i("BleScanService", "[FileStream] Sent rm_file command for file $fileNumber after successful upload")
                        }, 500) // Small delay to ensure Firebase operation completes
                    } else if (fileNumber < 0) {
                        android.util.Log.w("BleScanService", "[FileStream] Cannot delete file - invalid file number: $fileNumber")
                    } else {
                        android.util.Log.w("BleScanService", "[FileStream] Cannot delete file $fileNumber - not connected or UART not ready")
                    }
                }
                .addOnFailureListener { e ->
                    android.util.Log.e("BleScanService", "[FileStream] Firebase upload failed: ${e.message}")
                    android.util.Log.e("BleScanService", "[FileStream] Saving data locally for later sync")
                    // If upload fails, save locally for retry
                    saveToLocalStorage(serialNumber, sessionId, fileName, firebaseObject, fileNumber)
                }
        } catch (e: Exception) {
            android.util.Log.e("BleScanService", "[FileStream] Error uploading to Firebase: ${e.message}")
            e.printStackTrace()
            saveToLocalStorage(serialNumber, sessionId, fileName, firebaseObject, fileNumber)
        }
    }
    
    private fun saveToLocalStorage(
        serialNumber: String,
        sessionId: String,
        fileName: String,
        firebaseObject: Map<String, Any>,
        fileNumber: Int
    ) {
        try {
            // Store pending upload info
            val pendingKey = "pending_upload_${serialNumber}_$sessionId"
            val pendingData = mapOf(
                "sessionId" to sessionId,
                "fileName" to fileName,
                "serialNumber" to serialNumber,
                "fileNumber" to fileNumber,
                "timestamp" to System.currentTimeMillis()
            )
            
            // Save as JSON string
            val json = JSONObject(pendingData).toString()
            prefs?.edit()?.putString(pendingKey, json)?.apply()
            
            // Also save the firebase object (convert nested maps to JSONObjects)
            try {
                val firebaseJson = convertMapToJsonObject(firebaseObject).toString()
                prefs?.edit()?.putString("${pendingKey}_data", firebaseJson)?.apply()
            } catch (e: Exception) {
                android.util.Log.w("BleScanService", "[FileStream] Could not serialize firebase object, saving reference only: ${e.message}")
            }
            
            android.util.Log.i("BleScanService", "[FileStream] Data saved locally for session $sessionId. Will sync when online.")
        } catch (e: Exception) {
            android.util.Log.e("BleScanService", "[FileStream] Error saving to local storage: ${e.message}")
            e.printStackTrace()
        }
    }
    
    // Helper function to convert nested maps to JSONObject
    private fun convertMapToJsonObject(map: Map<String, Any>): JSONObject {
        val jsonObject = JSONObject()
        for ((key, value) in map) {
            when (value) {
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    jsonObject.put(key, convertMapToJsonObject(value as Map<String, Any>))
                }
                is List<*> -> {
                    val jsonArray = org.json.JSONArray()
                    for (item in value) {
                        when (item) {
                            is Map<*, *> -> {
                                @Suppress("UNCHECKED_CAST")
                                jsonArray.put(convertMapToJsonObject(item as Map<String, Any>))
                            }
                            else -> jsonArray.put(item)
                        }
                    }
                    jsonObject.put(key, jsonArray)
                }
                else -> jsonObject.put(key, value)
            }
        }
        return jsonObject
    }
    
    // Sync all pending uploads when internet is available
    fun syncPendingUploads() {
        handler.post {
            try {
                android.util.Log.i("BleScanService", "[FileStream] Syncing pending uploads...")
                
                val serialForSync = if (serialNumber.isNotEmpty()) serialNumber else prefs?.getString(KEY_SERIAL_NUMBER, "") ?: ""
                if (serialForSync.isEmpty()) {
                    android.util.Log.w("BleScanService", "[FileStream] Serial number not available, skipping sync")
                    return@post
                }
                
                // Check connectivity
                val isOnline = try {
                    val runtime = Runtime.getRuntime()
                    val process = runtime.exec("ping -c 1 8.8.8.8")
                    val exited = process.waitFor(500, TimeUnit.MILLISECONDS)
                    val exitCode = if (exited) process.exitValue() else -1
                    exited && exitCode == 0
                } catch (e: Exception) {
                    false
                }
                
                if (!isOnline) {
                    android.util.Log.w("BleScanService", "[FileStream] No internet connection. Cannot sync pending uploads.")
                    return@post
                }
                
                val sentSessions = prefs?.getStringSet("sentSessions_${connectedDeviceAddress?.replace(":", "")}", mutableSetOf()) ?: mutableSetOf()
                val allKeys = prefs?.all?.keys ?: emptySet()
                val pendingKeys = allKeys.filter { it.startsWith("pending_upload_${serialForSync}_") && it.endsWith("_data") }
                
                if (pendingKeys.isEmpty()) {
                    android.util.Log.i("BleScanService", "[FileStream] No pending uploads to sync.")
                    return@post
                }
                
                android.util.Log.i("BleScanService", "[FileStream] Found ${pendingKeys.size} pending upload(s) to sync.")
                
                var successCount = 0
                var failCount = 0
                
                for (dataKey in pendingKeys) {
                    try {
                        val sessionId = dataKey.replace("pending_upload_${serialForSync}_", "").replace("_data", "")
                        
                        // Check if already sent
                        if (sentSessions.contains(sessionId)) {
                            android.util.Log.d("BleScanService", "[FileStream] Session $sessionId already sent, removing from pending.")
                            prefs?.edit()?.remove(dataKey)?.remove("pending_upload_${serialForSync}_$sessionId")?.apply()
                            continue
                        }
                        
                        val firebaseJson = prefs?.getString(dataKey, null)
                        if (firebaseJson == null) {
                            android.util.Log.w("BleScanService", "[FileStream] No data found for key: $dataKey")
                            continue
                        }
                        
                        // Get metadata from the other key
                        val metadataKey = "pending_upload_${serialForSync}_$sessionId"
                        val metadataJson = prefs?.getString(metadataKey, null)
                        val fileName = if (metadataJson != null) {
                            try {
                                JSONObject(metadataJson).optString("fileName", "${System.currentTimeMillis()}_${serialNumber}_$sessionId.json")
                            } catch (e: Exception) {
                                "${System.currentTimeMillis()}_${serialNumber}_$sessionId.json"
                            }
                        } else {
                            "${System.currentTimeMillis()}_${serialNumber}_$sessionId.json"
                        }
                        
                        // Extract file number from metadata
                        val fileNumber = if (metadataJson != null) {
                            try {
                                JSONObject(metadataJson).optInt("fileNumber", -1)
                            } catch (e: Exception) {
                                -1
                            }
                        } else {
                            -1
                        }
                        
                        // Convert JSONObject back to Map for upload
                        val firebaseObject = JSONObject(firebaseJson)
                        val firebaseMap = jsonObjectToMap(firebaseObject)
                        
                        // Try to upload (async, so we'll check success in callback)
                        uploadToFirebase(fileName, firebaseMap, sessionId, serialNumber, sentSessions, fileNumber)
                        // Note: Success will be logged in uploadToFirebase callback
                        // For sync, we'll count it as attempted
                        successCount++
                        
                    } catch (e: Exception) {
                        failCount++
                        android.util.Log.e("BleScanService", "[FileStream] Failed to sync pending upload: ${e.message}")
                    }
                }
                
                android.util.Log.i("BleScanService", "[FileStream] Sync completed. Success: $successCount, Failed: $failCount")
                
            } catch (e: Exception) {
                android.util.Log.e("BleScanService", "[FileStream] Error syncing pending uploads: ${e.message}")
                e.printStackTrace()
            }
        }
    }
    
    // Helper to convert JSONObject back to Map
    private fun jsonObjectToMap(jsonObject: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = jsonObject.get(key)
            when (value) {
                is JSONObject -> map[key] = jsonObjectToMap(value)
                is org.json.JSONArray -> {
                    val list = mutableListOf<Any>()
                    for (i in 0 until value.length()) {
                        val item = value.get(i)
                        when (item) {
                            is JSONObject -> list.add(jsonObjectToMap(item))
                            else -> list.add(item)
                        }
                    }
                    map[key] = list
                }
                else -> map[key] = value
            }
        }
        return map
    }
    
    private fun scheduleNextFileStreamCommand() {
        // Cancel any existing scheduled command
        fileStreamingNextFileRunnable?.let {
            handler.removeCallbacks(it)
            android.util.Log.d("BleScanService", "[FileStream] Cancelled previous delay schedule")
        }
        
        val delaySeconds = FILE_STREAMING_DELAY_MS / 1000
        android.util.Log.i("BleScanService", "[FileStream] ========================================")
        android.util.Log.i("BleScanService", "[FileStream] ETX detected - File stream complete")
        android.util.Log.i("BleScanService", "[FileStream] Starting ${delaySeconds}s cooldown delay for BLE stack")
        android.util.Log.i("BleScanService", "[FileStream] Next file command will be ready after delay")
        android.util.Log.i("BleScanService", "[FileStream] ========================================")
        
        fileStreamingNextFileRunnable = Runnable {
            android.util.Log.i("BleScanService", "[FileStream] ========================================")
            android.util.Log.i("BleScanService", "[FileStream] Cooldown delay completed (${delaySeconds}s)")
            android.util.Log.i("BleScanService", "[FileStream] BLE stack is ready for next file stream")
            
            // Move to next file if available
            if (currentFile < leoLastFile && connectionState == STATE_CONNECTED && isUartReady) {
                currentFile++
                android.util.Log.i("BleScanService", "[FileStream] Streaming next file: $currentFile")
                requestNextFile()
            } else if (currentFile == leoLastFile) {
                android.util.Log.i("BleScanService", "[FileStream] Completed last file ($currentFile). All files processed.")
                stopFileStreaming()
            } else {
                android.util.Log.i("BleScanService", "[FileStream] All files processed. Current: $currentFile, Last: $leoLastFile")
                stopFileStreaming()
            }
            
            android.util.Log.i("BleScanService", "[FileStream] ========================================")
        }
        
        handler.postDelayed(fileStreamingNextFileRunnable!!, FILE_STREAMING_DELAY_MS)
    }

    private fun writeCommandImmediate(command: String): Boolean {
        if (!isUartReady || connectionState != STATE_CONNECTED) return false

        val txChar = txCharacteristic ?: return false
        val gatt = bluetoothGatt ?: return false

        logger.logCommand(command)
        
        return try {
            val commandWithLF = "$command\n"
            val bytes = commandWithLF.toByteArray(Charsets.UTF_8)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeCharacteristic(
                    txChar,
                    bytes,
                    BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                ) == BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                txChar.value = bytes
                @Suppress("DEPRECATION")
                txChar.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(txChar)
            }
        } catch (e: SecurityException) {
            logger.logError("Write command failed: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun enqueueCommand(command: String): Boolean {
        if (!isUartReady || connectionState != STATE_CONNECTED) return false
        commandQueue.add(command)
        if (!commandProcessing) {
            processCommandQueue()
        }
        return true
    }

    private fun processCommandQueue() {
        if (commandQueue.isEmpty()) {
            commandProcessing = false
            return
        }
        commandProcessing = true
        val command = commandQueue.removeFirst()
        writeCommandImmediate(command)
        handler.postDelayed({ processCommandQueue() }, COMMAND_GAP_MS)
    }

    private fun sendChargeLimitCommand() {
        if (!isUartReady || connectionState != STATE_CONNECTED) return
        
        val limitValue = if (chargeLimitEnabled) chargeLimit else 0
        val chargingFlag = if (isPhoneCharging) 1 else 0
        val timeValue = if (isPhoneCharging) chargingTimeSeconds else dischargingTimeSeconds
        
        val command = "app_msg limit $limitValue $phoneBatteryLevel $chargingFlag $timeValue"
        enqueueCommand(command)
    }

    private fun updateChargeLimit(limit: Int, enabled: Boolean): Boolean {
        if (limit < 0 || limit > 100) return false
        
        chargeLimit = limit
        chargeLimitEnabled = enabled
        
        logger.logChargeLimit(limit, enabled)
        
        // Save to preferences
        prefs?.edit()?.apply {
            putInt(KEY_CHARGE_LIMIT, limit)
            putBoolean(KEY_CHARGE_LIMIT_ENABLED, enabled)
            apply()
        }
        
        // Send command if connected
        if (isUartReady && connectionState == STATE_CONNECTED) {
            sendChargeLimitCommand()
        }
        
        MainActivity.sendChargeLimitUpdate(chargeLimit, chargeLimitEnabled)
        updateNotificationWithBattery()
        return true
    }
    
    private fun updateLedTimeout(seconds: Int): Boolean {
        if (seconds < 0 || seconds > 99999) return false
        
        ledTimeoutSeconds = seconds
        prefs?.edit()?.putInt(KEY_LED_TIMEOUT, seconds)?.apply()
        MainActivity.sendLedTimeoutUpdate(ledTimeoutSeconds)
        
        if (isUartReady && connectionState == STATE_CONNECTED) {
            val sent = enqueueCommand("app_msg led_time_before_dim $seconds")
            if (!sent) return false
            handler.postDelayed({
                if (isUartReady && connectionState == STATE_CONNECTED) {
                    enqueueCommand("py_msg")
                }
            }, 250)
        }
        
        return true
    }
    
    private fun requestLedTimeoutFromDevice(): Boolean {
        if (!isUartReady || connectionState != STATE_CONNECTED) return false
        
        val requested = enqueueCommand("app_msg led_time_before_dim")
        if (!requested) return false
        
        handler.postDelayed({
            if (isUartReady && connectionState == STATE_CONNECTED) {
                enqueueCommand("py_msg")
            }
        }, 250)
        
        return true
    }
    
    private fun updateChargeLimitEnabled(enabled: Boolean): Boolean {
        chargeLimitEnabled = enabled
        
        // Save to preferences
        prefs?.edit()?.putBoolean(KEY_CHARGE_LIMIT_ENABLED, enabled)?.apply()
        
        // Send command if connected - enabled sends chargeLimit, disabled sends 0
        if (isUartReady && connectionState == STATE_CONNECTED) {
            sendChargeLimitCommand()
        }
        
        MainActivity.sendChargeLimitUpdate(chargeLimit, chargeLimitEnabled)
        updateNotificationWithBattery()
        return true
    }
    
    private fun updateAdvancedModeState(
        ghost: Boolean? = null,
        silent: Boolean? = null,
        higherCharge: Boolean? = null
    ) {
        ghost?.let {
            ghostModeEnabled = it
            prefs?.edit()?.putBoolean(KEY_GHOST_MODE, it)?.apply()
        }
        silent?.let {
            silentModeEnabled = it
            prefs?.edit()?.putBoolean(KEY_SILENT_MODE, it)?.apply()
        }
        higherCharge?.let {
            higherChargeLimitEnabled = it
            prefs?.edit()?.putBoolean(KEY_HIGHER_CHARGE_LIMIT, it)?.apply()
        }
        
        MainActivity.sendAdvancedModesUpdate(
            ghostModeEnabled,
            silentModeEnabled,
            higherChargeLimitEnabled
        )
    }
    
    private fun scheduleAdvancedRefresh(mode: String) {
        handler.postDelayed({
            if (isUartReady && connectionState == STATE_CONNECTED) {
                enqueueCommand("app_msg $mode")
                handler.postDelayed({
                    if (isUartReady && connectionState == STATE_CONNECTED) {
                        enqueueCommand("py_msg")
                    }
                }, 250)
            }
        }, 200)
    }
    
    private fun updateGhostMode(enabled: Boolean): Boolean {
        updateAdvancedModeState(ghost = enabled)
        
        if (isUartReady && connectionState == STATE_CONNECTED) {
            val sent = enqueueCommand("app_msg ghost_mode ${if (enabled) 1 else 0}")
            if (!sent) return false
            scheduleAdvancedRefresh("ghost_mode")
        }
        
        return true
    }
    
    private fun updateSilentMode(enabled: Boolean): Boolean {
        updateAdvancedModeState(silent = enabled)
        
        if (isUartReady && connectionState == STATE_CONNECTED) {
            val sent = enqueueCommand("app_msg quiet_mode ${if (enabled) 1 else 0}")
            if (!sent) return false
            scheduleAdvancedRefresh("quiet_mode")
        }
        
        return true
    }
    
    private fun updateHigherChargeLimit(enabled: Boolean): Boolean {
        updateAdvancedModeState(higherCharge = enabled)
        
        if (isUartReady && connectionState == STATE_CONNECTED) {
            val sent = enqueueCommand("app_msg charge_limit ${if (enabled) 1 else 0}")
            if (!sent) return false
            scheduleAdvancedRefresh("charge_limit")
        }
        
        return true
    }
    
    private fun requestAdvancedModesFromDevice(): Boolean {
        if (!isUartReady || connectionState != STATE_CONNECTED) return false
        val now = System.currentTimeMillis()
        if (advancedRequestInProgress || now - lastAdvancedRequestMs < 1500) {
            return false
        }
        advancedRequestInProgress = true
        lastAdvancedRequestMs = now
        
        var delayMs = 0L
        val modes = listOf("ghost_mode", "quiet_mode", "charge_limit")
        modes.forEachIndexed { index, mode ->
            handler.postDelayed({
                if (isUartReady && connectionState == STATE_CONNECTED) {
                    enqueueCommand("app_msg $mode")
                    handler.postDelayed({
                        if (isUartReady && connectionState == STATE_CONNECTED) {
                            enqueueCommand("py_msg")
                        }
                        if (index == modes.lastIndex) {
                            advancedRequestInProgress = false
                        }
                    }, 300)
                } else if (index == modes.lastIndex) {
                    advancedRequestInProgress = false
                }
            }, delayMs)
            delayMs += 450
        }
        
        return true
    }

    private fun startChargeLimitTimer() {
        stopChargeLimitTimer()
        
        chargeLimitRunnable = object : Runnable {
            override fun run() {
                if (isUartReady && connectionState == STATE_CONNECTED) {
                    sendChargeLimitCommand()
                }
                handler.postDelayed(this, CHARGE_LIMIT_INTERVAL_MS)
            }
        }
        handler.postDelayed(chargeLimitRunnable!!, CHARGE_LIMIT_INTERVAL_MS)
    }

    private fun stopChargeLimitTimer() {
        chargeLimitRunnable?.let { handler.removeCallbacks(it) }
        chargeLimitRunnable = null
    }

    private fun startTimeTracking() {
        stopTimeTracking()
        
        timeTrackingRunnable = object : Runnable {
            override fun run() {
                if (isPhoneCharging) {
                    chargingTimeSeconds++
                } else {
                    dischargingTimeSeconds++
                }
                // Schedule next update after 1 second
                handler.postDelayed(this, 1000)
            }
        }
        // Start immediately to get first increment right away
        handler.post(timeTrackingRunnable!!)
    }

    private fun stopTimeTracking() {
        timeTrackingRunnable?.let { handler.removeCallbacks(it) }
        timeTrackingRunnable = null
    }

    private fun startMeasureTimer() {
        stopMeasureTimer()
        
        measureRunnable = object : Runnable {
            override fun run() {
                if (isUartReady && connectionState == STATE_CONNECTED) {
                    enqueueCommand("measure")
                }
                handler.postDelayed(this, MEASURE_INTERVAL_MS)
            }
        }
        handler.postDelayed(measureRunnable!!, MEASURE_INITIAL_DELAY_MS)
    }

    private fun stopMeasureTimer() {
        measureRunnable?.let { handler.removeCallbacks(it) }
        measureRunnable = null
    }
    
    // ==================== Battery Health Calculation ====================
    
    private fun getDesignedCapacity(): Int {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            
            // Try to get designed capacity (in microampere-hours)
            val capacityMicroAh = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
            
            // Some devices report designed capacity via PowerProfile (reflection needed)
            val powerProfileClass = Class.forName("com.android.internal.os.PowerProfile")
            val constructor = powerProfileClass.getConstructor(Context::class.java)
            val powerProfile = constructor.newInstance(this)
            val method = powerProfileClass.getMethod("getBatteryCapacity")
            val capacity = method.invoke(powerProfile) as Double
            
            capacity.toInt()
        } catch (e: Exception) {
            // Fallback: try to read from system properties or return default
            try {
                val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                // BATTERY_PROPERTY_CAPACITY returns percentage, not useful here
                // Return 0 to indicate we couldn't get it
                0
            } catch (e2: Exception) {
                0
            }
        }
    }
    
    /**
     * Get battery current in microamperes (µA).
     * Handles device-specific reporting differences (some devices return mA instead of µA).
     * Always returns value in microamperes for consistent calculations.
     * 
     * Detection logic: Use magnitude to determine unit
     * - If absolute value < 10000: likely in mA (typical charging current 500-3000 mA), convert to µA
     * - If absolute value >= 10000: likely already in µA (typical charging current 500000-3000000 µA)
     * This is more reliable than string length and handles edge cases better (e.g., Vivo, OnePlus).
     */
    private fun getCurrentNowMicroAmps(): Int {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val currentRaw = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            val absCurrent = kotlin.math.abs(currentRaw)
            
            // Detection logic: Use magnitude to determine unit
            // Typical charging currents: 500-3000 mA (500000-3000000 µA)
            // If value is less than 10000, it's likely in mA and needs conversion
            // If value is 10000 or more, it's likely already in µA
            if (absCurrent < 10000 && absCurrent > 0) {
                // Value is in milliamperes (mA), convert to microamperes (µA)
                // Preserve sign for proper handling
                if (currentRaw < 0) {
                    -(absCurrent * 1000)
                } else {
                    absCurrent * 1000
                }
            } else {
                // Value is already in microamperes (µA)
                currentRaw
            }
        } catch (e: Exception) {
            0
        }
    }
    
    /**
     * @deprecated Use getCurrentNowMicroAmps() instead for proper unit detection
     */
    private fun getCurrentNow(): Int {
        return getCurrentNowMicroAmps()
    }
    
    fun startHealthCalculation(): Boolean {
        if (!isPhoneCharging) {
            logger.logWarning("Cannot start health calculation - device not charging")
            return false
        }
        
        if (phoneBatteryLevel > (100 - HEALTH_CALCULATION_RANGE)) {
            logger.logWarning("Cannot start health calculation - battery too high (need room for ${HEALTH_CALCULATION_RANGE}% charge)")
            return false
        }
        
        // Get designed capacity
        designedCapacityMah = getDesignedCapacity()
        if (designedCapacityMah <= 0) {
            logger.logWarning("Could not determine designed battery capacity")
            // Continue anyway, we can still calculate estimated capacity
        } else {
            // Save designed capacity to preferences
            prefs?.edit()?.apply {
                putInt("designed_capacity_mah", designedCapacityMah)
                apply()
            }
        }
        
        // Reset calculation state
        healthCalculationInProgress = true
        healthCalculationStartPercent = phoneBatteryLevel
        healthCalculationEndPercent = phoneBatteryLevel + HEALTH_CALCULATION_RANGE
        accumulatedCurrentMah = 0.0
        lastHealthSampleTime = System.currentTimeMillis()
        
        logger.logInfo("Battery health calculation started at $phoneBatteryLevel% (target: $healthCalculationEndPercent%)")
        
        // Start sampling current
        startHealthSampling()
        
        // Notify Flutter
        MainActivity.sendBatteryHealthUpdate()
        
        return true
    }
    
    fun stopHealthCalculation() {
        healthCalculationInProgress = false
        stopHealthSampling()
        MainActivity.sendBatteryHealthUpdate()
    }
    
    private fun resetHealthCalculation() {
        healthCalculationInProgress = false
        healthCalculationWasActive = false
        healthCalculationStartPercent = -1
        healthCalculationEndPercent = -1
        accumulatedCurrentMah = 0.0
        lastHealthSampleTime = 0
        stopHealthSampling()
    }
    
    private fun startHealthSampling() {
        stopHealthSampling()
        
        healthCalculationRunnable = object : Runnable {
            override fun run() {
                if (healthCalculationInProgress && isPhoneCharging) {
                    sampleBatteryCurrent()
                    handler.postDelayed(this, HEALTH_SAMPLE_INTERVAL_MS)
                }
            }
        }
        handler.postDelayed(healthCalculationRunnable!!, HEALTH_SAMPLE_INTERVAL_MS)
    }
    
    private fun stopHealthSampling() {
        healthCalculationRunnable?.let { handler.removeCallbacks(it) }
        healthCalculationRunnable = null
    }
    
    private fun sampleBatteryCurrent() {
        // Get current in microamperes (with proper unit detection)
        val currentMicroAmps = getCurrentNowMicroAmps()
        currentNowMicroAmps = currentMicroAmps
        
        val now = System.currentTimeMillis()
        val elapsedSeconds = (now - lastHealthSampleTime) / 1000.0
        lastHealthSampleTime = now
        
        // Use absolute value since charging current is typically negative on some devices (Vivo, OnePlus)
        // but we only care about the magnitude for calculating charge accumulated
        val absCurrentMicroAmps = kotlin.math.abs(currentMicroAmps)
        
        if (absCurrentMicroAmps > 0 && elapsedSeconds > 0) {
            // Convert microamps to milliamps and accumulate (current * time = charge)
            // Current is in microamps, time is in seconds
            // mAh = (microamps / 1000) * (seconds / 3600) = microamps * seconds / 3,600,000
            val chargeMah = (absCurrentMicroAmps.toDouble() * elapsedSeconds) / 3600000.0
            accumulatedCurrentMah += chargeMah
        }
    }
    
    private fun checkHealthCalculationProgress() {
        if (!healthCalculationInProgress) return
        
        val percentCharged = phoneBatteryLevel - healthCalculationStartPercent
        
        if (percentCharged >= HEALTH_CALCULATION_RANGE) {
            // Calculation complete!
            calculateBatteryHealth()
        }
    }
    
    private fun calculateBatteryHealth() {
        stopHealthSampling()
        healthCalculationInProgress = false
        
        val percentCharged = phoneBatteryLevel - healthCalculationStartPercent
        
        if (percentCharged > 0 && accumulatedCurrentMah > 0) {
            // Estimated capacity = (accumulated mAh / percent charged) * 100
            val newEstimatedCapacity = (accumulatedCurrentMah / percentCharged) * 100
            
            // Battery health = (estimated capacity / designed capacity) * 100
            var newHealthPercent = -1.0
            if (designedCapacityMah > 0) {
                newHealthPercent = (newEstimatedCapacity / designedCapacityMah) * 100
                // Cap at 100%
                if (newHealthPercent > 100) newHealthPercent = 100.0
            }
            
            // Add new reading to history
            addHealthReading(newEstimatedCapacity, newHealthPercent)
            
            // Calculate averages from last 5 readings
            calculateAveragedHealth()
            
            logger.logInfo("Battery health calculation complete: " +
                    "Estimated capacity: ${newEstimatedCapacity.toInt()} mAh, " +
                    "Designed capacity: $designedCapacityMah mAh, " +
                    "Health: ${newHealthPercent.toInt()}%, " +
                    "Averaged (${healthReadings.size} readings): " +
                    "Est: ${estimatedCapacityMah.toInt()} mAh, " +
                    "Health: ${batteryHealthPercent.toInt()}%")
            
            // Save results to preferences
            saveHealthReadings()
            prefs?.edit()?.apply {
                putFloat("estimated_capacity_mah", estimatedCapacityMah.toFloat())
                putFloat("battery_health_percent", batteryHealthPercent.toFloat())
                putInt("designed_capacity_mah", designedCapacityMah)
                putLong("health_calculation_time", System.currentTimeMillis())
                apply()
            }
        } else {
            logger.logWarning("Battery health calculation failed - insufficient data")
        }
        
        // Notify Flutter
        MainActivity.sendBatteryHealthUpdate()
    }
    
    private fun addHealthReading(estimatedCapacity: Double, healthPercent: Double) {
        val reading = HealthReading(estimatedCapacity, healthPercent, System.currentTimeMillis())
        healthReadings.add(reading)
        
        // Keep only last MAX_HEALTH_READINGS readings
        if (healthReadings.size > MAX_HEALTH_READINGS) {
            healthReadings.removeAt(0)
        }
    }
    
    private fun calculateAveragedHealth() {
        if (healthReadings.isEmpty()) {
            estimatedCapacityMah = 0.0
            batteryHealthPercent = -1.0
            return
        }
        
        // Calculate average estimated capacity
        val validReadings = healthReadings.filter { it.estimatedCapacityMah > 0 }
        if (validReadings.isNotEmpty()) {
            estimatedCapacityMah = validReadings.map { it.estimatedCapacityMah }.average()
        } else {
            estimatedCapacityMah = 0.0
        }
        
        // Calculate average health percent (only from readings with valid health)
        val validHealthReadings = healthReadings.filter { it.batteryHealthPercent >= 0 }
        if (validHealthReadings.isNotEmpty()) {
            batteryHealthPercent = validHealthReadings.map { it.batteryHealthPercent }.average()
            // Cap at 100%
            if (batteryHealthPercent > 100) batteryHealthPercent = 100.0
        } else {
            batteryHealthPercent = -1.0
        }
    }
    
    private fun saveHealthReadings() {
        prefs?.edit()?.apply {
            putInt("health_readings_count", healthReadings.size)
            healthReadings.forEachIndexed { index, reading ->
                putFloat("health_reading_${index}_estimated", reading.estimatedCapacityMah.toFloat())
                putFloat("health_reading_${index}_health", reading.batteryHealthPercent.toFloat())
                putLong("health_reading_${index}_timestamp", reading.timestamp)
            }
            apply()
        }
    }
    
    private fun loadHealthReadings() {
        val count = prefs?.getInt("health_readings_count", 0) ?: 0
        healthReadings.clear()
        
        for (i in 0 until count.coerceAtMost(MAX_HEALTH_READINGS)) {
            val estimated = prefs?.getFloat("health_reading_${i}_estimated", 0f)?.toDouble() ?: 0.0
            val health = prefs?.getFloat("health_reading_${i}_health", -1f)?.toDouble() ?: -1.0
            val timestamp = prefs?.getLong("health_reading_${i}_timestamp", 0L) ?: 0L
            
            if (estimated > 0 || health >= 0) {
                healthReadings.add(HealthReading(estimated, health, timestamp))
            }
        }
        
        // Calculate averages from loaded readings
        if (healthReadings.isNotEmpty()) {
            calculateAveragedHealth()
        }
    }
    
    fun resetHealthReadings(): Boolean {
        return try {
            // Clear in-memory readings
            healthReadings.clear()
            
            // Reset calculated values
            estimatedCapacityMah = 0.0
            batteryHealthPercent = -1.0
            
            // Clear SharedPreferences
            prefs?.edit()?.apply {
                putInt("health_readings_count", 0)
                // Clear all health reading entries
                for (i in 0 until MAX_HEALTH_READINGS) {
                    remove("health_reading_${i}_estimated")
                    remove("health_reading_${i}_health")
                    remove("health_reading_${i}_timestamp")
                }
                // Clear calculated values
                putFloat("estimated_capacity_mah", 0f)
                putFloat("battery_health_percent", -1f)
                remove("health_calculation_time")
                apply()
            }
            
            logger.logInfo("Battery health readings reset")
            
            // Notify Flutter
            MainActivity.sendBatteryHealthUpdate()
            
            true
        } catch (e: Exception) {
            logger.logError("Failed to reset health readings: ${e.message}")
            false
        }
    }
    
    // ==================== End Battery Health Calculation ====================
    
    // ==================== Battery Session Tracking ====================
    
    private fun startNewSession(initialLevel: Int, isCharging: Boolean) {
        currentSessionStartTime = System.currentTimeMillis()
        currentSessionInitialLevel = initialLevel
        currentSessionIsCharging = isCharging
        currentSessionAccumulatedMah = 0.0
        
        // Save the new session state
        saveCurrentSessionState()
    }
    
    
    private fun endCurrentSession() {
        if (currentSessionInitialLevel < 0) return
        
        val endTime = System.currentTimeMillis()
        val durationSeconds = (endTime - currentSessionStartTime) / 1000
        
        // Save session whenever charging state changes (regardless of level change)
        // Only skip if duration is too short (< 1 second) or mAh is too low (< 1) to avoid noise
        if (durationSeconds >= 1 && currentSessionAccumulatedMah >= 1.0) {
            val session = Companion.BatterySession(
                startTime = currentSessionStartTime,
                endTime = endTime,
                initialLevel = currentSessionInitialLevel,
                finalLevel = phoneBatteryLevel,
                isCharging = currentSessionIsCharging,
                durationSeconds = durationSeconds,
                accumulatedMah = currentSessionAccumulatedMah
            )
            
            batterySessions.add(session)
            
            // Keep only last MAX_SESSIONS
            if (batterySessions.size > MAX_SESSIONS) {
                batterySessions.removeAt(0)
            }
            
            // Save to SharedPreferences
            val saveSuccess = saveSessions()
            
            if (saveSuccess) {
                logger.logInfo("(session) Battery session added: ${if (currentSessionIsCharging) "Charge" else "Discharge"} " +
                        "$currentSessionInitialLevel% -> $phoneBatteryLevel% " +
                        "($durationSeconds s, ${currentSessionAccumulatedMah.toInt()} mAh)")
            } else {
                logger.logError("(session) Battery session failed to save: ${if (currentSessionIsCharging) "Charge" else "Discharge"} " +
                        "$currentSessionInitialLevel% -> $phoneBatteryLevel% " +
                        "($durationSeconds s, ${currentSessionAccumulatedMah.toInt()} mAh)")
            }
        } else {
            // Session skipped due to insufficient duration or mAh
            val skipReason = when {
                durationSeconds < 1 -> "duration too short ($durationSeconds s < 1 s)"
                currentSessionAccumulatedMah < 1.0 -> "mAh too low (${currentSessionAccumulatedMah.toInt()} mAh < 1 mAh)"
                else -> "unknown reason"
            }
            logger.logInfo("(session) Battery session skipped: ${if (currentSessionIsCharging) "Charge" else "Discharge"} " +
                    "$currentSessionInitialLevel% -> $phoneBatteryLevel% " +
                    "($durationSeconds s, ${currentSessionAccumulatedMah.toInt()} mAh) - Reason: $skipReason")
        }
        
        // Reset current session
        currentSessionInitialLevel = -1
        currentSessionAccumulatedMah = 0.0
        
        // Clear saved in-progress session state
        clearCurrentSessionState()
    }
    
    private fun saveCurrentSessionState() {
        if (currentSessionInitialLevel < 0) {
            // No active session, clear any saved state
            clearCurrentSessionState()
            return
        }
        
        try {
            prefs?.edit()?.apply {
                putLong("current_session_start_time", currentSessionStartTime)
                putInt("current_session_initial_level", currentSessionInitialLevel)
                putBoolean("current_session_is_charging", currentSessionIsCharging)
                putFloat("current_session_mah", currentSessionAccumulatedMah.toFloat())
                apply()
            }
            // TODO: remove this log
            // logger.logInfo("(session) Saved in-progress session state: ${if (currentSessionIsCharging) "Charge" else "Discharge"} " +
            //         "$currentSessionInitialLevel% (${currentSessionAccumulatedMah.toInt()} mAh)")
        } catch (e: Exception) {
            logger.logError("(session) Failed to save in-progress session state: ${e.message}")
        }
    }
    
    private fun loadCurrentSessionState(): Boolean {
        return try {
            val savedStartTime = prefs?.getLong("current_session_start_time", 0L) ?: 0L
            val savedInitialLevel = prefs?.getInt("current_session_initial_level", -1) ?: -1
            val savedIsCharging = prefs?.getBoolean("current_session_is_charging", false) ?: false
            val savedMah = prefs?.getFloat("current_session_mah", 0f)?.toDouble() ?: 0.0
            
            if (savedStartTime > 0 && savedInitialLevel >= 0) {
                // Check if the saved session is still valid (not too old - max 7 days)
                val now = System.currentTimeMillis()
                val ageDays = (now - savedStartTime) / (1000 * 60 * 60 * 24)
                
                if (ageDays < 7) {
                    currentSessionStartTime = savedStartTime
                    currentSessionInitialLevel = savedInitialLevel
                    currentSessionIsCharging = savedIsCharging
                    currentSessionAccumulatedMah = savedMah
                    logger.logInfo("(session) Restored in-progress session state: ${if (savedIsCharging) "Charge" else "Discharge"} " +
                            "$savedInitialLevel% (${savedMah.toInt()} mAh, started ${ageDays.toInt()} day(s) ago)")
                    return true
                } else {
                    logger.logInfo("(session) Saved in-progress session is too old (${ageDays.toInt()} days), discarding")
                    clearCurrentSessionState()
                }
            }
            false
        } catch (e: Exception) {
            logger.logError("(session) Failed to load in-progress session state: ${e.message}")
            false
        }
    }
    
    private fun clearCurrentSessionState() {
        try {
            prefs?.edit()?.apply {
                remove("current_session_start_time")
                remove("current_session_initial_level")
                remove("current_session_is_charging")
                remove("current_session_mah")
                remove("current_session_last_save_time")
                apply()
            }
        } catch (e: Exception) {
            logger.logError("(session) Failed to clear in-progress session state: ${e.message}")
        }
    }
    
    private fun saveSessions(): Boolean {
        return try {
            // Log all sessions being saved
            logger.logInfo("(session) Saving ${batterySessions.size} battery session(s) to SharedPreferences:")
            batterySessions.forEachIndexed { index, session ->
                logger.logInfo("(session) Saving session ${index + 1}/${batterySessions.size}: ${if (session.isCharging) "Charge" else "Discharge"} " +
                        "${session.initialLevel}% -> ${session.finalLevel}% " +
                        "(${session.durationSeconds} s, ${session.accumulatedMah.toInt()} mAh)")
            }
            
            prefs?.edit()?.apply {
                putInt("battery_sessions_count", batterySessions.size)
                batterySessions.forEachIndexed { index, session ->
                    putLong("session_${index}_start", session.startTime)
                    putLong("session_${index}_end", session.endTime)
                    putInt("session_${index}_initial", session.initialLevel)
                    putInt("session_${index}_final", session.finalLevel)
                    putBoolean("session_${index}_charging", session.isCharging)
                    putLong("session_${index}_duration", session.durationSeconds)
                    putFloat("session_${index}_mah", session.accumulatedMah.toFloat())
                }
                apply()
            } != null
        } catch (e: Exception) {
            logger.logError("(session) Failed to save battery sessions to SharedPreferences: ${e.message}")
            false
        }
    }
    
    private fun loadSessions() {
        val count = prefs?.getInt("battery_sessions_count", 0) ?: 0
        logger.logInfo("(session) Loading battery session history from SharedPreferences (found $count session(s) in storage)")
        batterySessions.clear()
        
        var loadedCount = 0
        for (i in 0 until count.coerceAtMost(MAX_SESSIONS)) {
            val startTime = prefs?.getLong("session_${i}_start", 0L) ?: 0L
            val endTime = prefs?.getLong("session_${i}_end", 0L) ?: 0L
            val initialLevel = prefs?.getInt("session_${i}_initial", -1) ?: -1
            val finalLevel = prefs?.getInt("session_${i}_final", -1) ?: -1
            val isCharging = prefs?.getBoolean("session_${i}_charging", false) ?: false
            val durationSeconds = prefs?.getLong("session_${i}_duration", 0L) ?: 0L
            val accumulatedMah = prefs?.getFloat("session_${i}_mah", 0f)?.toDouble() ?: 0.0
            
            // Only load sessions with valid data and mAh >= 1 to filter out noise
            if (startTime > 0 && endTime > 0 && initialLevel >= 0 && finalLevel >= 0 && accumulatedMah >= 1.0) {
                batterySessions.add(Companion.BatterySession(
                    startTime = startTime,
                    endTime = endTime,
                    initialLevel = initialLevel,
                    finalLevel = finalLevel,
                    isCharging = isCharging,
                    durationSeconds = durationSeconds,
                    accumulatedMah = accumulatedMah
                ))
                loadedCount++
                logger.logInfo("(session) Loaded session $loadedCount: ${if (isCharging) "Charge" else "Discharge"} " +
                        "$initialLevel% -> $finalLevel% " +
                        "($durationSeconds s, ${accumulatedMah.toInt()} mAh)")
            }
        }
        logger.logInfo("(session) Successfully loaded $loadedCount battery session(s) from SharedPreferences")
    }
    
    fun getSessionHistory(): List<Map<String, Any>> {
        logger.logInfo("(session) Flutter requested battery session history from SharedPreferences")
        
        // Include current session if active and meets criteria (mAh >= 1)
        val sessionsToReturn = mutableListOf<Companion.BatterySession>()
        sessionsToReturn.addAll(batterySessions)
        
        if (currentSessionInitialLevel >= 0 && currentSessionAccumulatedMah >= 1.0) {
            val now = System.currentTimeMillis()
            val durationSeconds = (now - currentSessionStartTime) / 1000
            sessionsToReturn.add(Companion.BatterySession(
                startTime = currentSessionStartTime,
                endTime = now,
                initialLevel = currentSessionInitialLevel,
                finalLevel = phoneBatteryLevel,
                isCharging = currentSessionIsCharging,
                durationSeconds = durationSeconds,
                accumulatedMah = currentSessionAccumulatedMah
            ))
        }
        
        // Filter out any sessions with mAh < 1 and return in reverse chronological order (newest first)
        val filteredSessions = sessionsToReturn
            .filter { it.accumulatedMah >= 1.0 }
            .reversed()
        
        val result = filteredSessions.map { session ->
            mapOf(
                "startTime" to session.startTime,
                "endTime" to session.endTime,
                "initialLevel" to session.initialLevel,
                "finalLevel" to session.finalLevel,
                "isCharging" to session.isCharging,
                "durationSeconds" to session.durationSeconds,
                "accumulatedMah" to session.accumulatedMah
            )
        }
        
        // Log all sessions being returned to Flutter
        logger.logInfo("(session) Returning ${result.size} battery session(s) to Flutter:")
        result.forEachIndexed { index, sessionMap ->
            val isCharging = sessionMap["isCharging"] as? Boolean ?: false
            val initialLevel = sessionMap["initialLevel"] as? Int ?: 0
            val finalLevel = sessionMap["finalLevel"] as? Int ?: 0
            val durationSeconds = sessionMap["durationSeconds"] as? Long ?: 0L
            val accumulatedMah = sessionMap["accumulatedMah"] as? Double ?: 0.0
            logger.logInfo("(session) Session ${index + 1}/${result.size}: ${if (isCharging) "Charge" else "Discharge"} " +
                    "$initialLevel% -> $finalLevel% " +
                    "($durationSeconds s, ${accumulatedMah.toInt()} mAh)")
        }
        
        return result
    }
    
    fun clearSessionHistory(): Boolean {
        return try {
            logger.logInfo("(session) Clearing all battery sessions from SharedPreferences")
            
            // Clear in-memory sessions
            batterySessions.clear()
            
            // Clear SharedPreferences
            val count = prefs?.getInt("battery_sessions_count", 0) ?: 0
            prefs?.edit()?.apply {
                // Clear all session data
                for (i in 0 until count.coerceAtMost(MAX_SESSIONS)) {
                    remove("session_${i}_start")
                    remove("session_${i}_end")
                    remove("session_${i}_initial")
                    remove("session_${i}_final")
                    remove("session_${i}_charging")
                    remove("session_${i}_duration")
                    remove("session_${i}_mah")
                }
                remove("battery_sessions_count")
                apply()
            }
            
            logger.logInfo("(session) Successfully cleared all battery sessions from SharedPreferences")
            true
        } catch (e: Exception) {
            logger.logError("(session) Failed to clear battery sessions: ${e.message}")
            false
        }
    }
    
    // ==================== End Battery Session Tracking ====================

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                MainActivity.sendAdapterStateUpdate(mapAdapterState(state))
                
                when (state) {
                    BluetoothAdapter.STATE_ON -> {
                        logger.logBleState("Bluetooth turned ON")
                        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
                        startBleScan()
                        
                        if (shouldAutoReconnect) {
                            handler.postDelayed({ attemptAutoConnect() }, 1000)
                        }
                    }
                    BluetoothAdapter.STATE_OFF, BluetoothAdapter.STATE_TURNING_OFF -> {
                        logger.logBleState("Bluetooth turned OFF")
                        stopBleScan()
                        cancelReconnect()
                        stopChargeLimitTimer()
                        stopTimeTracking()
                        stopMeasureTimer()
                        closeGatt()
                        connectionState = STATE_DISCONNECTED
                        connectedDeviceAddress = null
                        pendingConnectAddress = null
                        isUartReady = false
                        txCharacteristic = null
                        rxCharacteristic = null
                        // chargeLimitConfirmed = false
                        scannedDevices.clear()
                        MainActivity.sendConnectionUpdate(STATE_DISCONNECTED, null)
                    }
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()
        
        if (isOnePlus()) {
            logger.logServiceState("OnePlus: initializing AlarmManager for restart keep-alive")
            alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        }
        
        // Initialize backend logging
        // Backend logging disabled for beta release
        // initializeLogging()
        
        // Acquire partial wake lock to keep CPU running
        acquireWakeLock()
        
        // Load saved charge limit settings
        chargeLimit = prefs?.getInt(KEY_CHARGE_LIMIT, 90) ?: 90
        chargeLimitEnabled = prefs?.getBoolean(KEY_CHARGE_LIMIT_ENABLED, false) ?: false
        ledTimeoutSeconds = prefs?.getInt(KEY_LED_TIMEOUT, 300) ?: 300
        ghostModeEnabled = prefs?.getBoolean(KEY_GHOST_MODE, false) ?: false
        silentModeEnabled = prefs?.getBoolean(KEY_SILENT_MODE, false) ?: false
        higherChargeLimitEnabled = prefs?.getBoolean(KEY_HIGHER_CHARGE_LIMIT, false) ?: false
        
        // Load saved battery health values
        designedCapacityMah = prefs?.getInt("designed_capacity_mah", 0) ?: 0
        // Load health readings history and calculate averages
        loadHealthReadings()
        // Fallback to single values if no readings loaded
        if (healthReadings.isEmpty()) {
            estimatedCapacityMah = prefs?.getFloat("estimated_capacity_mah", 0f)?.toDouble() ?: 0.0
            batteryHealthPercent = prefs?.getFloat("battery_health_percent", -1f)?.toDouble() ?: -1.0
        }
        
        // Load battery session history
        loadSessions()
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
        
        // Register Bluetooth state receiver
        val btFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        registerReceiver(bluetoothStateReceiver, btFilter)
        
        // Register battery receiver
        val batteryFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, batteryFilter)
        
        // Register network connectivity callback for automatic sync
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
            .build()
        connectivityManager?.registerNetworkCallback(networkRequest, networkCallback)
        android.util.Log.i("BleScanService", "[FileStream] Network connectivity callback registered")
        
        // Get initial battery level and start session tracking
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        batteryIntent?.let {
            val level = it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = it.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            val status = it.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            
            phoneBatteryLevel = (level * 100 / scale.toFloat()).toInt()
            isPhoneCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
            lastChargingState = isPhoneCharging
            
            // Try to restore in-progress session if it exists and charging state matches
            val restoredSession = loadCurrentSessionState()
            
            if (restoredSession && currentSessionIsCharging == isPhoneCharging) {
                // Restored session matches current charging state - continue tracking
                logger.logInfo("(session) Continuing in-progress session: ${if (currentSessionIsCharging) "Charge" else "Discharge"} " +
                        "$currentSessionInitialLevel% -> $phoneBatteryLevel% (restored ${currentSessionAccumulatedMah.toInt()} mAh)")
            } else {
                if (restoredSession) {
                    // Charging state changed - save the old session as completed
                    logger.logInfo("(session) Charging state changed, ending restored session and starting new one")
                    endCurrentSession()
                }
                
                // Start new battery session tracking
                if (phoneBatteryLevel >= 0) {
                    startNewSession(phoneBatteryLevel, isPhoneCharging)
                }
            }
        }
        
        // Start keep-alive mechanism
        startKeepAlive()
        
        // Start battery metrics polling (every 1 second)
        startBatteryMetricsPolling()
        
        // Start time tracking (tracks charging/discharging time)
        startTimeTracking()
        
        logger.logServiceState("Service created")
    }
    
    private fun initializeLogging() {
        try {
            val packageInfo = packageManager.getPackageInfo(packageName, 0)
            val versionName = packageInfo.versionName ?: "1.0.0"
            val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                packageInfo.versionCode.toString()
            }
            logger.initialize(this, versionName, versionCode)
            android.util.Log.d("BleScanService", "Backend logging initialization requested: v$versionName ($versionCode)")
        } catch (e: Exception) {
            android.util.Log.e("BleScanService", "Failed to initialize backend logging", e)
        }
    }
    
    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "LiionApp::BleServiceWakeLock"
            )
            wakeLock?.acquire()
        }
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
    
    private fun startKeepAlive() {
        stopKeepAlive()
        
        val interval = getKeepAliveInterval()
        keepAliveRunnable = object : Runnable {
            override fun run() {
                // This periodic task keeps the service alive
                // Update notification to show service is still running
                updateNotificationWithBattery()
                
                // Re-acquire wake lock if needed
                if (wakeLock?.isHeld != true) {
                    acquireWakeLock()
                }
                
                // Keep restart alarm fresh (OnePlus tends to kill services)
                setupServiceRestart()
                
                // Schedule next keep-alive
                handler.postDelayed(this, interval)
            }
        }
        handler.postDelayed(keepAliveRunnable!!, interval)
        setupServiceRestart()
    }
    
    private fun stopKeepAlive() {
        keepAliveRunnable?.let { handler.removeCallbacks(it) }
        keepAliveRunnable = null
    }

    // OnePlus compatibility: AlarmManager-backed restart if the service is killed
    private fun setupServiceRestart() {
        if (!isOnePlus()) return
        logger.logServiceState("OnePlus: scheduling AlarmManager restart")
        try {
            val intent = Intent(this, BleScanService::class.java).apply {
                action = RESTART_ACTION
            }
            val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            restartPendingIntent = PendingIntent.getService(this, 1001, intent, flags)
            val triggerAt = System.currentTimeMillis() + getKeepAliveInterval()
            val pendingIntent = restartPendingIntent ?: return
            val am = alarmManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (_: Exception) {
            // Ignore scheduling errors
        }
    }

    private fun cancelServiceRestart() {
        if (!isOnePlus()) return
        logger.logServiceState("OnePlus: canceling AlarmManager restart")
        restartPendingIntent?.let { pi ->
            try {
                alarmManager?.cancel(pi)
            } catch (_: Exception) {
            }
        }
    }

    private fun getKeepAliveInterval(): Long {
        return if (isOnePlus()) KEEP_ALIVE_INTERVAL_ONEPLUS_MS else KEEP_ALIVE_INTERVAL_MS
    }

    private fun isOnePlus(): Boolean {
        return Build.MANUFACTURER.equals("OnePlus", ignoreCase = true)
    }
    
    private fun startBatteryMetricsPolling() {
        stopBatteryMetricsPolling()
        lastMetricsSampleTime = System.currentTimeMillis()
        lastMetricsChargingState = isPhoneCharging
        
        batteryMetricsRunnable = object : Runnable {
            override fun run() {
                sampleBatteryMetrics()
                handler.postDelayed(this, BATTERY_METRICS_INTERVAL_MS)
            }
        }
        handler.post(batteryMetricsRunnable!!)
    }
    
    private fun stopBatteryMetricsPolling() {
        batteryMetricsRunnable?.let { handler.removeCallbacks(it) }
        batteryMetricsRunnable = null
    }
    
    private fun sampleBatteryMetrics() {
        try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            
            // Get current in microamperes (with proper unit detection)
            val currentMicroAmps = getCurrentNowMicroAmps()
            
            // Convert from microamperes (µA) to milliamperes (mA) for display
            batteryCurrentMa = currentMicroAmps / 1000.0
            
            // Sanity check: clamp to reasonable range (0-10A = 0-10000 mA)
            // This prevents display of impossible values due to device reporting errors
            if (kotlin.math.abs(batteryCurrentMa) > 10000) {
                android.util.Log.w("BatteryMetrics", 
                    "Unusually high current detected: ${batteryCurrentMa}mA (raw µA: $currentMicroAmps). " +
                    "This may indicate a device reporting error. Clamping to reasonable range.")
                batteryCurrentMa = if (batteryCurrentMa > 0) 10000.0 else -10000.0
            }
            
            // Get voltage from battery intent (in millivolts, convert to V)
            val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            batteryIntent?.let {
                val voltageMv = it.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0)
                batteryVoltageV = voltageMv / 1000.0
                
                // Get temperature (in tenths of degree Celsius)
                val tempTenths = it.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)
                batteryTemperatureC = tempTenths / 10.0
            }
            
            // Check if charging state changed - reset accumulated mAh
            if (lastMetricsChargingState != null && lastMetricsChargingState != isPhoneCharging) {
                metricsAccumulatedMah = 0.0
                lastMetricsSampleTime = System.currentTimeMillis()
            }
            lastMetricsChargingState = isPhoneCharging
            
            // Accumulate mAh (current in mA * time in hours)
            val now = System.currentTimeMillis()
            val elapsedHours = (now - lastMetricsSampleTime) / 3600000.0
            val mahDelta = kotlin.math.abs(batteryCurrentMa) * elapsedHours
            metricsAccumulatedMah += mahDelta
            
            // Also accumulate to current session if active
            if (currentSessionInitialLevel >= 0) {
                currentSessionAccumulatedMah += mahDelta
                // Periodically save session state (every 10 mAh or every 5 minutes)
                val timeSinceLastSave = now - (prefs?.getLong("current_session_last_save_time", currentSessionStartTime) ?: currentSessionStartTime)
                if (currentSessionAccumulatedMah >= 10.0 || timeSinceLastSave >= 5 * 60 * 1000) {
                    saveCurrentSessionState()
                    prefs?.edit()?.putLong("current_session_last_save_time", now)?.apply()
                }
            }
            
            lastMetricsSampleTime = now
            
            // Send update to Flutter
            MainActivity.sendBatteryMetricsUpdate(
                batteryCurrentMa,
                batteryVoltageV,
                batteryTemperatureC,
                metricsAccumulatedMah,
                chargingTimeSeconds,
                dischargingTimeSeconds
            )
        } catch (e: Exception) {
            // Silently fail
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == RESTART_ACTION) {
            logger.logInfo("Service restarted via AlarmManager (OnePlus compatibility)")
            isServiceStopping = false
        }

        val notification = createNotification("Scanning for Leo USB devices...")
        startForeground(NOTIFICATION_ID, notification)
        
        logger.logServiceState("Service started")
        
        setupServiceRestart()

        if (bluetoothAdapter?.isEnabled == true) {
            startBleScan()
            
            if (shouldAutoReconnect && connectionState == STATE_DISCONNECTED) {
                handler.postDelayed({ attemptAutoConnect() }, 500)
            }
        }
        
        return START_STICKY
    }

    private fun connectToDevice(address: String, userInitiated: Boolean): Boolean {
        if (bluetoothAdapter?.isEnabled != true) return false
        
        if (userInitiated) {
            shouldAutoReconnect = true
            reconnectAttempts = 0
            logger.logConnect(address, scannedDevices[address] ?: "Leo Usb")
        }
        
        return try {
            cancelReconnect()
            
            // Properly close existing GATT to avoid status 133 errors
            bluetoothGatt?.let { gatt ->
                try {
                    gatt.disconnect()
                    gatt.close()
                } catch (e: SecurityException) {
                    e.printStackTrace()
                }
            }
            bluetoothGatt = null
            
            // Small delay to let Bluetooth stack reset after closing GATT
            Thread.sleep(100)
            
            val device = bluetoothAdapter?.getRemoteDevice(address) ?: return false
            connectionState = STATE_CONNECTING
            pendingConnectAddress = address
            
            MainActivity.sendConnectionUpdate(STATE_CONNECTING, address)
            updateNotificationWithBattery()
            
            bluetoothGatt = device.connectGatt(this, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            true
        } catch (e: Exception) {
            logger.logError("Connection failed: ${e.message}")
            e.printStackTrace()
            connectionState = STATE_DISCONNECTED
            pendingConnectAddress = null
            
            if (shouldAutoReconnect) {
                scheduleReconnect(address)
            }
            false
        }
    }

    private fun disconnectDevice(userInitiated: Boolean) {
        cancelReconnect()
        stopChargeLimitTimer()
        stopTimeTracking()
        stopMeasureTimer()
        
        if (userInitiated) {
            logger.logDisconnect("User initiated disconnect")
            shouldAutoReconnect = false
            reconnectAttempts = 0
            clearSavedDevice()
        }
        
        pendingConnectAddress = null
        isUartReady = false
        serialRequested = false
        fileStreamingRequested = false
        getFilesRangePending = false
        getFilesRetryDone = false
        getFilesTimeoutRunnable?.let { handler.removeCallbacks(it) }
        txCharacteristic = null
        rxCharacteristic = null
        // chargeLimitConfirmed = false
        
        try {
            bluetoothGatt?.disconnect()
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
        
        if (userInitiated) {
            updateNotificationWithBattery()
        }
    }

    private fun closeGatt() {
        try {
            bluetoothGatt?.close()
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
        bluetoothGatt = null
    }

    private fun attemptAutoConnect() {
        if (connectionState != STATE_DISCONNECTED) return
        if (bluetoothAdapter?.isEnabled != true) return
        if (!shouldAutoReconnect) return
        
        val savedAddress = prefs?.getString(KEY_LAST_DEVICE_ADDRESS, null) ?: return
        
        logger.logAutoConnect(savedAddress)
        
        if (scannedDevices.containsKey(savedAddress)) {
            connectToDevice(savedAddress, userInitiated = false)
        } else {
            connectToDevice(savedAddress, userInitiated = false)
        }
    }

    private fun scheduleReconnect(address: String) {
        if (!shouldAutoReconnect) return
        
        cancelReconnect()
        
        // After MAX_RECONNECT_ATTEMPTS, add a longer cooldown period
        val delay = if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            reconnectAttempts = 0
            logger.logInfo("Max reconnect attempts reached, waiting 30s before retry")
            // Restart BLE scan to refresh device cache
            restartScan()
            30000L // 30 second cooldown
        } else {
            RECONNECT_DELAY_MS + (reconnectAttempts * RECONNECT_BACKOFF_MS)
        }
        
        reconnectAttempts++
        
        logger.logReconnect(reconnectAttempts, address)
        
        reconnectRunnable = Runnable {
            if (shouldAutoReconnect && connectionState == STATE_DISCONNECTED && bluetoothAdapter?.isEnabled == true) {
                connectToDevice(address, userInitiated = false)
            }
        }
        handler.postDelayed(reconnectRunnable!!, delay)
    }

    private fun cancelReconnect() {
        reconnectRunnable?.let { handler.removeCallbacks(it) }
        reconnectRunnable = null
    }

    private fun saveLastDevice(address: String, name: String) {
        prefs?.edit()?.apply {
            putString(KEY_LAST_DEVICE_ADDRESS, address)
            putString(KEY_LAST_DEVICE_NAME, name)
            apply()
        }
    }

    private fun clearSavedDevice() {
        prefs?.edit()?.apply {
            remove(KEY_LAST_DEVICE_ADDRESS)
            remove(KEY_LAST_DEVICE_NAME)
            apply()
        }
    }

    private fun startBleScan() {
        if (isScanning) return
        if (bluetoothAdapter?.isEnabled != true) return
        
        try {
            val scanSettings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            bluetoothLeScanner?.startScan(null, scanSettings, scanCallback)
            isScanning = true
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun stopBleScan() {
        if (!isScanning) return
        
        try {
            bluetoothLeScanner?.stopScan(scanCallback)
            isScanning = false
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }
    
    fun restartScan() {
        stopBleScan()
        startBleScan()
    }

    private fun mapAdapterState(state: Int): Int {
        return when (state) {
            BluetoothAdapter.STATE_OFF -> 0
            BluetoothAdapter.STATE_TURNING_ON -> 1
            BluetoothAdapter.STATE_ON -> 2
            BluetoothAdapter.STATE_TURNING_OFF -> 3
            else -> 0
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "BLE Scan Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Scanning for Leo USB devices"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                enableLights(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Liion Power")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(0) // Disable all defaults (sound, vibration, lights)
            .build()
    }

    private fun updateNotification(text: String) {
        val notification = createNotification(text)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun updateNotificationWithBattery() {
        val batteryText = if (phoneBatteryLevel >= 0) {
            val chargingText = if (isPhoneCharging) "⚡" else ""
            "Phone: $phoneBatteryLevel%$chargingText"
        } else {
            ""
        }
        
        val statusText = when (connectionState) {
            STATE_CONNECTED -> "Connected to Leo"
            STATE_CONNECTING -> "Connecting..."
            else -> "Scanning..."
        }
        
        val limitText = if (chargeLimitEnabled && connectionState == STATE_CONNECTED) {
            " | Limit: $chargeLimit%"
        } else {
            ""
        }
        
        val fullText = if (batteryText.isNotEmpty()) {
            "$statusText | $batteryText$limitText"
        } else {
            statusText
        }
        
        updateNotification(fullText)
    }

    // OTA Update Methods
    fun startOtaUpdate(filePath: String): Boolean {
        if (connectionState != STATE_CONNECTED || bluetoothGatt == null) {
            return false
        }
        
        if (otaDataCharacteristic == null || otaControlCharacteristic == null) {
            return false
        }
        
        if (isOtaInProgress) {
            return false
        }
        
        return try {
            android.util.Log.d("BleScanService", "startOtaUpdate called with path: $filePath")
            
            isOtaInProgress = true
            otaCancelRequested = false
            otaProgress = 0
            otaCurrentPacket = 0
            
            // Stop regular UART commands during OTA to avoid interference
            stopMeasureTimer()
            stopChargeLimitTimer()
            android.util.Log.d("BleScanService", "Stopped regular UART timers for OTA")
            
            // Send initial progress
            MainActivity.sendOtaProgress(0, true, "Reading firmware file...")
            
            // Read firmware file
            val file = java.io.File(filePath)
            android.util.Log.d("BleScanService", "File exists: ${file.exists()}, Path: ${file.absolutePath}")
            
            if (!file.exists()) {
                android.util.Log.e("BleScanService", "Firmware file does not exist: $filePath")
                MainActivity.sendOtaProgress(0, false, "Firmware file does not exist: $filePath")
                isOtaInProgress = false
                return false
            }
            
            val firmwareBytes = file.readBytes()
            android.util.Log.d("BleScanService", "Firmware file read: ${firmwareBytes.size} bytes")
            
            if (firmwareBytes.isEmpty()) {
                android.util.Log.e("BleScanService", "Firmware file is empty")
                MainActivity.sendOtaProgress(0, false, "Firmware file is empty")
                isOtaInProgress = false
                return false
            }
            
            val chunkSize = 250 // MTU - 3
            otaTotalPackets = (firmwareBytes.size + chunkSize - 1) / chunkSize
            android.util.Log.d("BleScanService", "Total packets to send: $otaTotalPackets")
            
            // Check if device is connected and OTA service is available
            if (connectionState != STATE_CONNECTED) {
                android.util.Log.e("BleScanService", "Device not connected")
                MainActivity.sendOtaProgress(0, false, "Device not connected")
                isOtaInProgress = false
                return false
            }
            
            if (bluetoothGatt == null) {
                android.util.Log.e("BleScanService", "GATT is null")
                MainActivity.sendOtaProgress(0, false, "Bluetooth connection not available")
                isOtaInProgress = false
                return false
            }
            
            // Start OTA update in background thread
            Thread {
                performOtaUpdate(firmwareBytes, chunkSize)
            }.start()
            
            android.util.Log.d("BleScanService", "OTA update thread started")
            true
        } catch (e: Exception) {
            android.util.Log.e("BleScanService", "Exception in startOtaUpdate: ${e.message}", e)
            e.printStackTrace()
            MainActivity.sendOtaProgress(0, false, "Error starting OTA: ${e.message}")
            isOtaInProgress = false
            false
        }
    }
    
    private fun performOtaUpdate(firmwareBytes: ByteArray, chunkSize: Int) {
        val gatt = bluetoothGatt ?: run {
            android.util.Log.e("BleScanService", "GATT is null in performOtaUpdate")
            MainActivity.sendOtaProgress(0, false, "Bluetooth connection lost")
            isOtaInProgress = false
            return
        }
        
        val dataChar = otaDataCharacteristic ?: run {
            android.util.Log.e("BleScanService", "OTA data characteristic not found")
            MainActivity.sendOtaProgress(0, false, "OTA data characteristic not found. Device may not support OTA.")
            isOtaInProgress = false
            return
        }
        
        val controlChar = otaControlCharacteristic ?: run {
            android.util.Log.e("BleScanService", "OTA control characteristic not found")
            MainActivity.sendOtaProgress(0, false, "OTA control characteristic not found. Device may not support OTA.")
            isOtaInProgress = false
            return
        }
        
        android.util.Log.d("BleScanService", "OTA characteristics found, proceeding with update")
        
        try {
            android.util.Log.d("BleScanService", "Starting OTA update: ${firmwareBytes.size} bytes, $otaTotalPackets packets")
            
            // Get MTU size (use tracked MTU or default)
            val mtuSize = currentMtu
            val actualChunkSize = minOf(chunkSize, mtuSize - 3)
            android.util.Log.d("BleScanService", "MTU: $mtuSize, Chunk size: $actualChunkSize")
            
            // Write MTU size to data characteristic (250 as 2 bytes)
            val mtuBytes = byteArrayOf((250 and 0xFF).toByte(), ((250 shr 8) and 0xFF).toByte())
            android.util.Log.d("BleScanService", "Writing MTU size to data characteristic")
            if (!writeOtaCharacteristic(gatt, dataChar, mtuBytes, waitForCompletion = true)) {
                android.util.Log.e("BleScanService", "Failed to write MTU size")
                MainActivity.sendOtaProgress(0, false, "Failed to write MTU size")
                isOtaInProgress = false
                return
            }
            
            // Write 0x01 to control characteristic to start OTA
            android.util.Log.d("BleScanService", "Writing 0x01 to control characteristic to start OTA")
            if (!writeOtaCharacteristic(gatt, controlChar, byteArrayOf(1), waitForCompletion = true)) {
                android.util.Log.e("BleScanService", "Failed to start OTA")
                MainActivity.sendOtaProgress(0, false, "Failed to start OTA")
                isOtaInProgress = false
                return
            }
            Thread.sleep(200) // Wait for device response
            
            // Read response from control characteristic
            android.util.Log.d("BleScanService", "Reading response from control characteristic")
            val response = readOtaCharacteristicSync(gatt, controlChar, timeoutMs = 2000)
            
            if (response == null || response.isEmpty() || response[0].toInt() != 2) {
                val responseStr = if (response != null && response.isNotEmpty()) response[0].toInt().toString() else "no response"
                android.util.Log.e("BleScanService", "Device not ready for OTA. Response: $responseStr")
                MainActivity.sendOtaProgress(0, false, "Device not ready for OTA (response: $responseStr)")
                isOtaInProgress = false
                return
            }
            
            android.util.Log.d("BleScanService", "Device ready for OTA. Starting firmware transfer...")
            
            // Send firmware chunks with retry logic and proper flow control
            var packetNumber = 0
            var consecutiveFailures = 0
            val maxConsecutiveFailures = 5
            val retryDelayMs = 50L
            
            for (i in firmwareBytes.indices step actualChunkSize) {
                if (otaCancelRequested) {
                    android.util.Log.d("BleScanService", "OTA cancelled by user")
                    writeOtaCharacteristic(gatt, controlChar, byteArrayOf(4), waitForCompletion = false)
                    MainActivity.sendOtaProgress(0, false, "OTA cancelled")
                    isOtaInProgress = false
                    return
                }
                
                val end = minOf(i + actualChunkSize, firmwareBytes.size)
                val chunk = firmwareBytes.sliceArray(i until end)
                
                if (packetNumber % 100 == 0 || packetNumber < 10) {
                    android.util.Log.d("BleScanService", "Writing packet $packetNumber/$otaTotalPackets (${chunk.size} bytes)")
                }
                
                // Retry logic for packet writes
                var writeSuccess = false
                var retryCount = 0
                val maxRetries = 3
                
                while (!writeSuccess && retryCount < maxRetries && !otaCancelRequested) {
                    // Wait for completion to prevent overlapping writes (prevents GATT busy)
                    writeSuccess = writeOtaCharacteristic(gatt, dataChar, chunk, waitForCompletion = true)
                    
                    if (!writeSuccess) {
                        retryCount++
                        consecutiveFailures++
                        android.util.Log.w("BleScanService", "Failed to write packet $packetNumber (attempt $retryCount/$maxRetries)")
                        
                        if (consecutiveFailures >= maxConsecutiveFailures) {
                            android.util.Log.e("BleScanService", "Too many consecutive failures ($consecutiveFailures). Aborting OTA.")
                            MainActivity.sendOtaProgress(0, false, "Failed to write packet $packetNumber after $consecutiveFailures consecutive failures")
                            isOtaInProgress = false
                            return
                        }
                        
                        // Exponential backoff: 50ms, 100ms, 200ms
                        val backoffDelay = retryDelayMs * (1 shl (retryCount - 1))
                        android.util.Log.d("BleScanService", "Retrying packet $packetNumber after ${backoffDelay}ms delay")
                        Thread.sleep(backoffDelay)
                    } else {
                        consecutiveFailures = 0 // Reset on success
                    }
                }
                
                if (!writeSuccess) {
                    android.util.Log.e("BleScanService", "Failed to write packet $packetNumber after $maxRetries attempts")
                    MainActivity.sendOtaProgress(0, false, "Failed to write packet $packetNumber after $maxRetries attempts")
                    isOtaInProgress = false
                    return
                }
                
                // Small delay after successful write to ensure BLE stack is ready for next packet
                // This prevents "prior command is not finished" errors
                Thread.sleep(10) // 10ms delay is sufficient for BLE stack to process
                
                packetNumber++
                
                // Update progress
                val progress = if (otaTotalPackets > 0) {
                    (packetNumber * 100) / otaTotalPackets
                } else {
                    0
                }
                otaProgress = progress
                otaCurrentPacket = packetNumber
                
                // Send progress update frequently for smooth UI updates
                // Send every packet for first 10, then every 5 packets, then every 10
                val updateFrequency = when {
                    packetNumber < 10 -> 1
                    packetNumber < 100 -> 5
                    else -> 10
                }
                
                if (packetNumber % updateFrequency == 0 || packetNumber == otaTotalPackets) {
                    MainActivity.sendOtaProgress(progress, true, "Sending packet $packetNumber/$otaTotalPackets")
                }
                
                // Always send progress for the last packet
                if (packetNumber == otaTotalPackets) {
                    MainActivity.sendOtaProgress(100, true, "All packets sent")
                }
            }
            
            android.util.Log.d("BleScanService", "All packets sent. Sending completion signal...")
            
            // Write 0x04 to control characteristic to finish
            android.util.Log.d("BleScanService", "Writing 0x04 to control characteristic to finish OTA")
            writeOtaCharacteristic(gatt, controlChar, byteArrayOf(4), waitForCompletion = true)
            Thread.sleep(500) // Wait for device to process
            
            // Try to read final acknowledgment, but don't fail if device disconnects (it's rebooting)
            android.util.Log.d("BleScanService", "Waiting for final acknowledgment (0x05)")
            val finalResponse = readOtaCharacteristicSync(gatt, controlChar, timeoutMs = 2000)
            
            // Check if we got a response or if device disconnected (which is normal - device reboots)
            val deviceDisconnected = connectionState != STATE_CONNECTED || bluetoothGatt == null
            
            if (finalResponse != null && finalResponse.isNotEmpty() && finalResponse[0].toInt() == 5) {
                android.util.Log.d("BleScanService", "OTA update successful! Received acknowledgment (0x05)")
                MainActivity.sendOtaProgress(100, false, "OTA update successful")
            } else if (deviceDisconnected) {
                // Device disconnected after sending all packets - this is normal, device is rebooting to install firmware
                android.util.Log.d("BleScanService", "OTA update completed. Device disconnected (rebooting to install firmware)")
                MainActivity.sendOtaProgress(100, false, "OTA update completed. Device is rebooting to install firmware.")
            } else {
                val responseStr = if (finalResponse != null && finalResponse.isNotEmpty()) finalResponse[0].toInt().toString() else "no response"
                android.util.Log.w("BleScanService", "OTA update may have succeeded but no acknowledgment received. Response: $responseStr")
                // Still mark as success since all packets were sent
                MainActivity.sendOtaProgress(100, false, "OTA update completed. All packets sent successfully.")
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
            android.util.Log.e("BleScanService", "OTA update failed: ${e.message}")
            MainActivity.sendOtaProgress(0, false, "OTA update failed: ${e.message}")
        } finally {
            isOtaInProgress = false
            // Restart regular UART timers after OTA completes (if still connected)
            if (connectionState == STATE_CONNECTED && isUartReady) {
                startMeasureTimer()
                startChargeLimitTimer()
                android.util.Log.d("BleScanService", "Restarted regular UART timers after OTA")
            }
        }
    }
    
    private fun readOtaCharacteristicSync(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        timeoutMs: Long
    ): ByteArray? {
        synchronized(otaReadLock) {
            lastReadValue = null
        }
        
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // For API 33+, reading is asynchronous
                gatt.readCharacteristic(characteristic)
                // Wait for callback
                synchronized(otaReadLock) {
                    otaReadLock.wait(timeoutMs)
                }
                lastReadValue
            } else {
                @Suppress("DEPRECATION")
                gatt.readCharacteristic(characteristic)
                Thread.sleep(200) // Wait a bit for read to complete
                @Suppress("DEPRECATION")
                characteristic.value
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    private fun writeOtaCharacteristic(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        data: ByteArray,
        waitForCompletion: Boolean = true
    ): Boolean {
        return try {
            synchronized(otaWriteLock) {
                otaWriteCompleted = false
            }
            
            // Try to write the characteristic
            val writeSuccess = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val result = gatt.writeCharacteristic(characteristic, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
                result == BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = data
                @Suppress("DEPRECATION")
                characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(characteristic)
            }
            
            if (!writeSuccess) {
                android.util.Log.w("BleScanService", "writeCharacteristic returned false immediately - BLE stack may be busy")
                return false
            }
            
            // Wait for write completion if requested
            if (waitForCompletion) {
                synchronized(otaWriteLock) {
                    val timeout = 3000L // 3 second timeout (increased from 2s for reliability)
                    val startTime = System.currentTimeMillis()
                    while (!otaWriteCompleted && isOtaInProgress) {
                        val elapsed = System.currentTimeMillis() - startTime
                        if (elapsed >= timeout) {
                            android.util.Log.w("BleScanService", "Write completion timeout after ${elapsed}ms")
                            return false // Timeout
                        }
                        val remainingTime = timeout - elapsed
                        if (remainingTime > 0) {
                            otaWriteLock.wait(remainingTime)
                        }
                    }
                    if (!otaWriteCompleted) {
                        android.util.Log.w("BleScanService", "Write completed but otaWriteCompleted is false")
                        return false
                    }
                    return true
                }
            }
            
            true
        } catch (e: SecurityException) {
            android.util.Log.e("BleScanService", "SecurityException in writeOtaCharacteristic: ${e.message}")
            e.printStackTrace()
            false
        } catch (e: InterruptedException) {
            android.util.Log.e("BleScanService", "InterruptedException in writeOtaCharacteristic: ${e.message}")
            e.printStackTrace()
            false
        } catch (e: Exception) {
            android.util.Log.e("BleScanService", "Exception in writeOtaCharacteristic: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    
    fun cancelOtaUpdate() {
        otaCancelRequested = true
    }
    
    fun getOtaProgress(): Int {
        return otaProgress
    }
    
    fun isOtaUpdateInProgress(): Boolean {
        return isOtaInProgress
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        val preserveSession = isOnePlus() && !isServiceStopping
        logger.logServiceState("Service destroyed (intentional stop: $isServiceStopping, preserveSession: $preserveSession)")
        
        // For OnePlus unexpected kills, keep the session open and persist state to resume on restart
        if (preserveSession) {
            logger.logServiceState("OnePlus: preserving session state on destroy")
            saveCurrentSessionState()
        } else if (currentSessionInitialLevel >= 0) {
            logger.logServiceState("Service ended session at level $currentSessionInitialLevel%")
            endCurrentSession()
        }
        
        stopBleScan()
        cancelReconnect()
        stopChargeLimitTimer()
        stopTimeTracking()
        stopMeasureTimer()
        
        // Cancel file streaming next file command
        fileStreamingNextFileRunnable?.let {
            handler.removeCallbacks(it)
            fileStreamingNextFileRunnable = null
        }
        
        // Cancel file streaming timeout
        cancelStreamFileTimeout()

        stopKeepAlive()
        stopBatteryMetricsPolling()
        releaseWakeLock()
        closeGatt()
        unregisterReceiver(bluetoothStateReceiver)
        unregisterReceiver(batteryReceiver)
        
        // Unregister network connectivity callback
        connectivityManager?.unregisterNetworkCallback(networkCallback)
        connectivityManager = null
        if (isServiceStopping) {
            cancelServiceRestart()
        } else {
            setupServiceRestart()
        }
        instance = null
        super.onDestroy()
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        logger.logServiceState("App removed from recents - service continuing")
        // Service continues running even when app is removed from recents
        // Re-acquire wake lock if needed
        if (wakeLock?.isHeld != true) {
            acquireWakeLock()
        }
        super.onTaskRemoved(rootIntent)
    }
}

