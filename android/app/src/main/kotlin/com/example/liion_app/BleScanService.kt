package com.example.liion_app

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import java.util.UUID

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
        
        // Nordic UART Service UUIDs
        val SERVICE_UUID: UUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e")
        val TX_CHAR_UUID: UUID = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e")
        val RX_CHAR_UUID: UUID = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        
        // OTA Service UUIDs
        val OTA_SERVICE_UUID: UUID = UUID.fromString("d6f1d96d-594c-4c53-b1c6-144a1dfde6d8")
        val OTA_DATA_CHAR_UUID: UUID = UUID.fromString("23408888-1f40-4cd8-9b89-ca8d45f8a5b0")
        val OTA_CONTROL_CHAR_UUID: UUID = UUID.fromString("7ad671aa-21c0-46a4-b722-270e3ae3d830")
        
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
        
        // Keep-alive interval (every 5 minutes)
        const val KEEP_ALIVE_INTERVAL_MS = 300000L
        
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
        const val MAX_SESSIONS = 100 // Keep last 100 sessions
        
        fun getBatterySessionHistory(): List<Map<String, Any>> {
            return instance?.getSessionHistory() ?: emptyList()
        }
        
        private var instance: BleScanService? = null
        
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
            return instance?.writeCommand(command) ?: false
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
        
        fun setChargeLimit(limit: Int, enabled: Boolean): Boolean {
            return instance?.updateChargeLimit(limit, enabled) ?: false
        }
        
        fun setChargeLimitEnabled(enabled: Boolean): Boolean {
            return instance?.updateChargeLimitEnabled(enabled) ?: false
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
    
    // Measure command timer
    private var measureRunnable: Runnable? = null
    private val MEASURE_INTERVAL_MS = 30000L // Send measure command every 30 seconds
    private val MEASURE_INITIAL_DELAY_MS = 25000L // Initial delay before first measure command
    
    // Battery metrics timer (1 second polling)
    private var batteryMetricsRunnable: Runnable? = null
    private val BATTERY_METRICS_INTERVAL_MS = 1000L
    private var lastMetricsChargingState: Boolean? = null
    private var lastMetricsSampleTime: Long = 0
    
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
                }
            }
        }
    }

    private fun handleReceivedData(data: String) {
        val parts = data.split(" ")
        
        // Handle charge_limit response
        if (parts.size >= 4 && parts[2] == "charge_limit") {
            try {
                val value = parts[3].toIntOrNull() ?: return
                chargeLimitConfirmed = value == 1
                MainActivity.sendChargeLimitConfirmed(chargeLimitConfirmed)
            } catch (e: Exception) {
                e.printStackTrace()
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

    private fun writeCommand(command: String): Boolean {
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

    private fun sendChargeLimitCommand() {
        if (!isUartReady || connectionState != STATE_CONNECTED) return
        
        val limitValue = if (chargeLimitEnabled) chargeLimit else 0
        val chargingFlag = if (isPhoneCharging) 1 else 0
        val timeValue = if (isPhoneCharging) chargingTimeSeconds else dischargingTimeSeconds
        
        val command = "app_msg limit $limitValue $phoneBatteryLevel $chargingFlag $timeValue"
        writeCommand(command)
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
                    writeCommand("measure")
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
     */
    private fun getCurrentNowMicroAmps(): Int {
        return try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val currentRaw = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            val absCurrent = kotlin.math.abs(currentRaw)
            val stringLength = absCurrent.toString().length
            
            // Detection logic: Use string length to determine unit (same as in sampleBatteryMetrics)
            // - If length <= 4: value is in mA, convert to µA by multiplying by 1000
            // - If length > 4: value is already in µA
            if (stringLength <= 4) {
                // Value is in milliamperes (mA), convert to microamperes (µA)
                currentRaw * 1000
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
        
        if (currentMicroAmps > 0 && elapsedSeconds > 0) {
            // Convert microamps to milliamps and accumulate (current * time = charge)
            // Current is in microamps, time is in seconds
            // mAh = (microamps / 1000) * (seconds / 3600) = microamps * seconds / 3,600,000
            val chargeMah = (currentMicroAmps.toDouble() * elapsedSeconds) / 3600000.0
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
    
    // ==================== End Battery Health Calculation ====================
    
    // ==================== Battery Session Tracking ====================
    
    private fun startNewSession(initialLevel: Int, isCharging: Boolean) {
        currentSessionStartTime = System.currentTimeMillis()
        currentSessionInitialLevel = initialLevel
        currentSessionIsCharging = isCharging
        currentSessionAccumulatedMah = 0.0
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
            saveSessions()
            
            logger.logInfo("Battery session saved: ${if (currentSessionIsCharging) "Charge" else "Discharge"} " +
                    "$currentSessionInitialLevel% -> $phoneBatteryLevel% " +
                    "($durationSeconds s, ${currentSessionAccumulatedMah.toInt()} mAh)")
        }
        
        // Reset current session
        currentSessionInitialLevel = -1
        currentSessionAccumulatedMah = 0.0
    }
    
    private fun saveSessions() {
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
        }
    }
    
    private fun loadSessions() {
        val count = prefs?.getInt("battery_sessions_count", 0) ?: 0
        batterySessions.clear()
        
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
            }
        }
    }
    
    fun getSessionHistory(): List<Map<String, Any>> {
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
        return sessionsToReturn
            .filter { it.accumulatedMah >= 1.0 }
            .reversed()
            .map { session ->
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
        
        // Initialize backend logging
        initializeLogging()
        
        // Acquire partial wake lock to keep CPU running
        acquireWakeLock()
        
        // Load saved charge limit settings
        chargeLimit = prefs?.getInt(KEY_CHARGE_LIMIT, 90) ?: 90
        chargeLimitEnabled = prefs?.getBoolean(KEY_CHARGE_LIMIT_ENABLED, false) ?: false
        
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
            
            // Start battery session tracking immediately when service starts
            if (phoneBatteryLevel >= 0) {
                startNewSession(phoneBatteryLevel, isPhoneCharging)
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
        
        keepAliveRunnable = object : Runnable {
            override fun run() {
                // This periodic task keeps the service alive
                // Update notification to show service is still running
                updateNotificationWithBattery()
                
                // Re-acquire wake lock if needed
                if (wakeLock?.isHeld != true) {
                    acquireWakeLock()
                }
                
                // Schedule next keep-alive
                handler.postDelayed(this, KEEP_ALIVE_INTERVAL_MS)
            }
        }
        handler.postDelayed(keepAliveRunnable!!, KEEP_ALIVE_INTERVAL_MS)
    }
    
    private fun stopKeepAlive() {
        keepAliveRunnable?.let { handler.removeCallbacks(it) }
        keepAliveRunnable = null
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
        val notification = createNotification("Scanning for Leo USB devices...")
        startForeground(NOTIFICATION_ID, notification)
        
        logger.logServiceState("Service started")
        
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
            
            // Send firmware chunks (synchronous writes to avoid GATT busy)
            var packetNumber = 0
            
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
                
                // Wait for completion to prevent overlapping writes (prevents GATT busy)
                if (!writeOtaCharacteristic(gatt, dataChar, chunk, waitForCompletion = true)) {
                    android.util.Log.e("BleScanService", "Failed to write packet $packetNumber")
                    MainActivity.sendOtaProgress(0, false, "Failed to write packet $packetNumber")
                    isOtaInProgress = false
                    return
                }
                
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
            
            val writeSuccess = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                gatt.writeCharacteristic(characteristic, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT) == 
                    BluetoothStatusCodes.SUCCESS
            } else {
                @Suppress("DEPRECATION")
                characteristic.value = data
                @Suppress("DEPRECATION")
                characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                @Suppress("DEPRECATION")
                gatt.writeCharacteristic(characteristic)
            }
            
            if (!writeSuccess) {
                return false
            }
            
            // Wait for write completion if requested
            if (waitForCompletion) {
                synchronized(otaWriteLock) {
                    val timeout = 2000L // 2 second timeout
                    val startTime = System.currentTimeMillis()
                    while (!otaWriteCompleted && isOtaInProgress) {
                        val elapsed = System.currentTimeMillis() - startTime
                        if (elapsed >= timeout) {
                            return false // Timeout
                        }
                        otaWriteLock.wait(timeout - elapsed)
                    }
                    return otaWriteCompleted
                }
            }
            
            true
        } catch (e: SecurityException) {
            e.printStackTrace()
            false
        } catch (e: InterruptedException) {
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
        logger.logServiceState("Service destroyed")
        
        // End current session if active
        if (currentSessionInitialLevel >= 0) {
            endCurrentSession()
        }
        
        stopBleScan()
        cancelReconnect()
        stopChargeLimitTimer()
        stopTimeTracking()
        stopMeasureTimer()
        stopKeepAlive()
        stopBatteryMetricsPolling()
        releaseWakeLock()
        closeGatt()
        unregisterReceiver(bluetoothStateReceiver)
        unregisterReceiver(batteryReceiver)
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
