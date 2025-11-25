package com.example.liion_app

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.liion_app/ble_service"
        private const val EVENT_CHANNEL = "com.liion_app/ble_devices"
        private const val CONNECTION_EVENT_CHANNEL = "com.liion_app/ble_connection"
        private const val REQUEST_ENABLE_BT = 1001
        
        private var eventSink: EventChannel.EventSink? = null
        private var connectionEventSink: EventChannel.EventSink? = null
        private var pendingBluetoothResult: MethodChannel.Result? = null
        
        fun sendDeviceUpdate(address: String, name: String) {
            eventSink?.success(mapOf("address" to address, "name" to name))
        }
        
        fun sendConnectionUpdate(state: Int, address: String?) {
            connectionEventSink?.success(mapOf("state" to state, "address" to address))
        }
    }

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var connectionManager: BleConnectionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter
        
        connectionManager = BleConnectionManager(this).apply {
            onConnectionStateChanged = { state, address ->
                sendConnectionUpdate(state, address)
            }
        }

        // Method Channel for service control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        startBleService()
                        result.success(true)
                    }
                    "stopService" -> {
                        stopBleService()
                        result.success(true)
                    }
                    "rescan" -> {
                        BleScanService.rescan()
                        result.success(true)
                    }
                    "getScannedDevices" -> {
                        val devices = BleScanService.scannedDevices.map { 
                            mapOf("address" to it.key, "name" to it.value) 
                        }
                        result.success(devices)
                    }
                    "isServiceRunning" -> {
                        result.success(BleScanService.isScanning)
                    }
                    "isBluetoothEnabled" -> {
                        result.success(bluetoothAdapter?.isEnabled == true)
                    }
                    "requestEnableBluetooth" -> {
                        requestEnableBluetooth(result)
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (address != null) {
                            val success = connectionManager?.connect(address) ?: false
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Address is required", null)
                        }
                    }
                    "disconnect" -> {
                        connectionManager?.disconnect()
                        result.success(true)
                    }
                    "isConnected" -> {
                        result.success(connectionManager?.isConnected() ?: false)
                    }
                    "getConnectionState" -> {
                        result.success(connectionManager?.getConnectionState() ?: 0)
                    }
                    "getConnectedDeviceAddress" -> {
                        result.success(connectionManager?.getConnectedDeviceAddress())
                    }
                    else -> result.notImplemented()
                }
            }

        // Event Channel for real-time device updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        
        // Event Channel for connection state updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTION_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    connectionEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    connectionEventSink = null
                }
            })
    }

    private fun requestEnableBluetooth(result: MethodChannel.Result) {
        if (bluetoothAdapter?.isEnabled == true) {
            result.success(true)
            return
        }
        
        try {
            pendingBluetoothResult = result
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
        } catch (e: SecurityException) {
            result.success(false)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_BT) {
            pendingBluetoothResult?.success(resultCode == Activity.RESULT_OK)
            pendingBluetoothResult = null
        }
    }

    private fun startBleService() {
        val serviceIntent = Intent(this, BleScanService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun stopBleService() {
        val serviceIntent = Intent(this, BleScanService::class.java)
        stopService(serviceIntent)
    }
}
