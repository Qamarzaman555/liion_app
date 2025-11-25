package com.example.liion_app

import android.app.*
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class BleScanService : Service() {

    companion object {
        const val CHANNEL_ID = "BLE_SCAN_CHANNEL"
        const val NOTIFICATION_ID = 1
        const val DEVICE_FILTER = "Leo Usb"
        const val PREFS_NAME = "ble_prefs"
        const val KEY_LAST_DEVICE_ADDRESS = "last_device_address"
        const val KEY_LAST_DEVICE_NAME = "last_device_name"
        const val KEY_AUTO_RECONNECT = "auto_reconnect"
        
        // Connection states
        const val STATE_DISCONNECTED = 0
        const val STATE_CONNECTING = 1
        const val STATE_CONNECTED = 2
        
        // Reconnect settings
        const val RECONNECT_DELAY_MS = 2000L
        const val MAX_RECONNECT_ATTEMPTS = 10
        const val RECONNECT_BACKOFF_MS = 1000L
        
        val scannedDevices = mutableMapOf<String, String>() // address -> name
        var isScanning = false
        var connectionState = STATE_DISCONNECTED
        var connectedDeviceAddress: String? = null
        
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
    }

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var prefs: SharedPreferences? = null
    private val handler = Handler(Looper.getMainLooper())
    
    // Reconnection state
    private var reconnectRunnable: Runnable? = null
    private var reconnectAttempts = 0
    private var shouldAutoReconnect: Boolean
        get() = prefs?.getBoolean(KEY_AUTO_RECONNECT, false) ?: false
        set(value) { prefs?.edit()?.putBoolean(KEY_AUTO_RECONNECT, value)?.apply() }
    
    private var pendingConnectAddress: String? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceName = device.name ?: return
            
            if (deviceName.contains(DEVICE_FILTER, ignoreCase = true)) {
                val isNew = !scannedDevices.containsKey(device.address)
                scannedDevices[device.address] = deviceName
                MainActivity.sendDeviceUpdate(device.address, deviceName)
                
                // Auto-connect if this is the saved device and we should reconnect
                if (isNew && shouldAutoReconnect && connectionState == STATE_DISCONNECTED) {
                    attemptAutoConnect()
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            isScanning = false
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
                        
                        // Save device for auto-reconnect
                        saveLastDevice(gatt.device.address, gatt.device.name ?: "Leo Usb")
                        shouldAutoReconnect = true
                        
                        updateNotification("Connected to ${gatt.device.name ?: "Leo Usb"}")
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
                        
                        connectionState = STATE_DISCONNECTED
                        connectedDeviceAddress = null
                        
                        closeGatt()
                        
                        // Check if we should auto-reconnect
                        if (shouldAutoReconnect && bluetoothAdapter?.isEnabled == true && previousAddress != null) {
                            // Connection failed or dropped - schedule reconnect
                            if (status != BluetoothGatt.GATT_SUCCESS || wasConnected) {
                                updateNotification("Reconnecting to Leo...")
                                scheduleReconnect(previousAddress)
                            }
                        } else {
                            updateNotification("Scanning for Leo USB devices...")
                        }
                        
                        MainActivity.sendConnectionUpdate(STATE_DISCONNECTED, null)
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            handler.post {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    MainActivity.sendServicesDiscovered(gatt.services.map { it.uuid.toString() })
                }
            }
        }
    }

    private val bluetoothStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                MainActivity.sendAdapterStateUpdate(mapAdapterState(state))
                
                when (state) {
                    BluetoothAdapter.STATE_ON -> {
                        // Bluetooth turned on, restart scanning and try to reconnect
                        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
                        startBleScan()
                        
                        // Try to reconnect if we have a saved device
                        if (shouldAutoReconnect) {
                            handler.postDelayed({ attemptAutoConnect() }, 1000)
                        }
                    }
                    BluetoothAdapter.STATE_OFF, BluetoothAdapter.STATE_TURNING_OFF -> {
                        // Bluetooth turning off, clear state but keep shouldAutoReconnect
                        stopBleScan()
                        cancelReconnect()
                        closeGatt()
                        connectionState = STATE_DISCONNECTED
                        connectedDeviceAddress = null
                        pendingConnectAddress = null
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
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
        
        // Register Bluetooth state receiver
        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        registerReceiver(bluetoothStateReceiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification("Scanning for Leo USB devices...")
        startForeground(NOTIFICATION_ID, notification)
        
        if (bluetoothAdapter?.isEnabled == true) {
            startBleScan()
            
            // Try to reconnect to last device if auto-reconnect is enabled
            if (shouldAutoReconnect && connectionState == STATE_DISCONNECTED) {
                handler.postDelayed({ attemptAutoConnect() }, 500)
            }
        }
        
        return START_STICKY
    }

    private fun connectToDevice(address: String, userInitiated: Boolean): Boolean {
        if (bluetoothAdapter?.isEnabled != true) return false
        
        // If user initiated, enable auto-reconnect
        if (userInitiated) {
            shouldAutoReconnect = true
            reconnectAttempts = 0
        }
        
        return try {
            cancelReconnect()
            closeGatt()
            
            val device = bluetoothAdapter?.getRemoteDevice(address) ?: return false
            connectionState = STATE_CONNECTING
            pendingConnectAddress = address
            
            MainActivity.sendConnectionUpdate(STATE_CONNECTING, address)
            updateNotification("Connecting to ${device.name ?: "Leo Usb"}...")
            
            bluetoothGatt = device.connectGatt(this, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            connectionState = STATE_DISCONNECTED
            pendingConnectAddress = null
            
            // Schedule retry if auto-reconnect is enabled
            if (shouldAutoReconnect) {
                scheduleReconnect(address)
            }
            false
        }
    }

    private fun disconnectDevice(userInitiated: Boolean) {
        cancelReconnect()
        
        if (userInitiated) {
            // User manually disconnected - disable auto-reconnect
            shouldAutoReconnect = false
            reconnectAttempts = 0
            clearSavedDevice()
        }
        
        pendingConnectAddress = null
        
        try {
            bluetoothGatt?.disconnect()
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
        
        if (userInitiated) {
            updateNotification("Scanning for Leo USB devices...")
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
        
        // Check if device is in scanned list OR try to connect directly
        if (scannedDevices.containsKey(savedAddress)) {
            connectToDevice(savedAddress, userInitiated = false)
        } else {
            // Try to connect even if not in scan list (device might be connectable)
            connectToDevice(savedAddress, userInitiated = false)
        }
    }

    private fun scheduleReconnect(address: String) {
        if (!shouldAutoReconnect) return
        if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            // Max attempts reached, reset and keep trying with longer delay
            reconnectAttempts = 0
        }
        
        cancelReconnect()
        
        val delay = RECONNECT_DELAY_MS + (reconnectAttempts * RECONNECT_BACKOFF_MS)
        reconnectAttempts++
        
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

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopBleScan()
        cancelReconnect()
        closeGatt()
        unregisterReceiver(bluetoothStateReceiver)
        instance = null
        super.onDestroy()
    }
}
