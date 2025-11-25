package com.example.liion_app

import android.app.*
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class BleScanService : Service() {

    companion object {
        const val CHANNEL_ID = "BLE_SCAN_CHANNEL"
        const val NOTIFICATION_ID = 1
        const val DEVICE_FILTER = "Leo Usb"
        
        val scannedDevices = mutableMapOf<String, String>() // address -> name
        var isScanning = false
        
        private var instance: BleScanService? = null
        
        fun rescan() {
            scannedDevices.clear()
            instance?.restartScan()
        }
    }

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothLeScanner: BluetoothLeScanner? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val deviceName = device.name ?: return
            
            if (deviceName.contains(DEVICE_FILTER, ignoreCase = true)) {
                scannedDevices[device.address] = deviceName
                // Notify Flutter about new device
                MainActivity.sendDeviceUpdate(device.address, deviceName)
            }
        }

        override fun onScanFailed(errorCode: Int) {
            isScanning = false
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        bluetoothLeScanner = bluetoothAdapter?.bluetoothLeScanner
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        startBleScan()
        
        return START_STICKY
    }

    private fun startBleScan() {
        if (isScanning) return
        
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

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Liion Power")
            .setContentText("Scanning for Leo USB devices...")
            .setSmallIcon(android.R.drawable.ic_menu_search)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopBleScan()
        instance = null
        super.onDestroy()
    }
}
