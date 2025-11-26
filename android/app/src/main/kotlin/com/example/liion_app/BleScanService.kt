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
        
        // Charge limit state
        var chargeLimit: Int = 90
        var chargeLimitEnabled: Boolean = false
        var chargeLimitConfirmed: Boolean = false
        var chargingTimeSeconds: Long = 0
        var dischargingTimeSeconds: Long = 0
        
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
        
        fun getPhoneBatteryInfo(): Map<String, Any> {
            return mapOf(
                "level" to phoneBatteryLevel,
                "isCharging" to isPhoneCharging
            )
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
    
    // Firebase logging
    private val logger: FirebaseLoggingService by lazy { FirebaseLoggingService.getInstance() }

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
                    phoneBatteryLevel = batteryPct
                    isPhoneCharging = isCharging
                    
                    // Reset time counters if charging state changed
                    if (chargingStateChanged) {
                        if (isCharging) {
                            chargingTimeSeconds = 0
                        } else {
                            dischargingTimeSeconds = 0
                        }
                        lastChargingState = isCharging
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
                            gatt.discoverServices()
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
                        chargeLimitConfirmed = false
                        
                        // Stop charge limit timer
                        stopChargeLimitTimer()
                        
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
                } else {
                    // Write failed
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
        if (parts.size >= 4 && parts[2] == "charge_limit") {
            try {
                val value = parts[3].toIntOrNull() ?: return
                chargeLimitConfirmed = value == 1
                MainActivity.sendChargeLimitConfirmed(chargeLimitConfirmed)
            } catch (e: Exception) {
                e.printStackTrace()
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
                handler.postDelayed(this, 1000)
            }
        }
        handler.postDelayed(timeTrackingRunnable!!, 1000)
    }

    private fun stopTimeTracking() {
        timeTrackingRunnable?.let { handler.removeCallbacks(it) }
        timeTrackingRunnable = null
    }

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
                        closeGatt()
                        connectionState = STATE_DISCONNECTED
                        connectedDeviceAddress = null
                        pendingConnectAddress = null
                        isUartReady = false
                        txCharacteristic = null
                        rxCharacteristic = null
                        chargeLimitConfirmed = false
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
        
        // Initialize Firebase logging
        initializeLogging()
        
        // Acquire partial wake lock to keep CPU running
        acquireWakeLock()
        
        // Load saved charge limit settings
        chargeLimit = prefs?.getInt(KEY_CHARGE_LIMIT, 90) ?: 90
        chargeLimitEnabled = prefs?.getBoolean(KEY_CHARGE_LIMIT_ENABLED, false) ?: false
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
        
        // Register Bluetooth state receiver
        val btFilter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        registerReceiver(bluetoothStateReceiver, btFilter)
        
        // Register battery receiver
        val batteryFilter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        registerReceiver(batteryReceiver, batteryFilter)
        
        // Get initial battery level
        val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        batteryIntent?.let {
            val level = it.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = it.getIntExtra(BatteryManager.EXTRA_SCALE, 100)
            val status = it.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
            
            phoneBatteryLevel = (level * 100 / scale.toFloat()).toInt()
            isPhoneCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL
            lastChargingState = isPhoneCharging
        }
        
        // Start keep-alive mechanism
        startKeepAlive()
        
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
        } catch (e: Exception) {
            // Silently fail
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
            closeGatt()
            
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
        chargeLimitConfirmed = false
        
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
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            reconnectAttempts = 0
        }
        
        cancelReconnect()
        
        val delay = RECONNECT_DELAY_MS + (reconnectAttempts * RECONNECT_BACKOFF_MS)
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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        logger.logServiceState("Service destroyed")
        stopBleScan()
        cancelReconnect()
        stopChargeLimitTimer()
        stopTimeTracking()
        stopKeepAlive()
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
