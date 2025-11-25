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
        private const val ADAPTER_STATE_CHANNEL = "com.liion_app/adapter_state"
        private const val DATA_RECEIVED_CHANNEL = "com.liion_app/data_received"
        private const val BATTERY_CHANNEL = "com.liion_app/phone_battery"
        private const val REQUEST_ENABLE_BT = 1001
        
        private var eventSink: EventChannel.EventSink? = null
        private var connectionEventSink: EventChannel.EventSink? = null
        private var adapterStateSink: EventChannel.EventSink? = null
        private var dataReceivedSink: EventChannel.EventSink? = null
        private var batterySink: EventChannel.EventSink? = null
        private var pendingBluetoothResult: MethodChannel.Result? = null
        
        fun sendDeviceUpdate(address: String, name: String) {
            eventSink?.success(mapOf("address" to address, "name" to name))
        }
        
        fun sendConnectionUpdate(state: Int, address: String?) {
            connectionEventSink?.success(mapOf("state" to state, "address" to address))
        }
        
        fun sendAdapterStateUpdate(state: Int) {
            adapterStateSink?.success(state)
        }
        
        fun sendServicesDiscovered(services: List<String>) {
            // Can be used later
        }
        
        fun sendDataReceived(data: String) {
            dataReceivedSink?.success(data)
        }
        
        fun sendUartReady(ready: Boolean) {
            // UART ready
        }
        
        fun sendBatteryUpdate(level: Int, isCharging: Boolean) {
            batterySink?.success(mapOf("level" to level, "isCharging" to isCharging))
        }
    }

    private var bluetoothAdapter: BluetoothAdapter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothAdapter = bluetoothManager.adapter

        // Method Channel
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
                    "getAdapterState" -> {
                        result.success(getBluetoothAdapterState())
                    }
                    "requestEnableBluetooth" -> {
                        requestEnableBluetooth(result)
                    }
                    "connect" -> {
                        val address = call.argument<String>("address")
                        if (address != null) {
                            val success = BleScanService.connect(address)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Address is required", null)
                        }
                    }
                    "disconnect" -> {
                        BleScanService.disconnect()
                        result.success(true)
                    }
                    "isConnected" -> {
                        result.success(BleScanService.connectionState == BleScanService.STATE_CONNECTED)
                    }
                    "getConnectionState" -> {
                        result.success(BleScanService.connectionState)
                    }
                    "getConnectedDeviceAddress" -> {
                        result.success(BleScanService.connectedDeviceAddress)
                    }
                    "sendCommand" -> {
                        val command = call.argument<String>("command")
                        if (command != null) {
                            val success = BleScanService.sendCommand(command)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Command is required", null)
                        }
                    }
                    "getPhoneBattery" -> {
                        result.success(BleScanService.getPhoneBatteryInfo())
                    }
                    else -> result.notImplemented()
                }
            }

        // Event Channel for device updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
        
        // Event Channel for connection state
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTION_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    connectionEventSink = events
                    events?.success(mapOf(
                        "state" to BleScanService.connectionState,
                        "address" to BleScanService.connectedDeviceAddress
                    ))
                }
                override fun onCancel(arguments: Any?) {
                    connectionEventSink = null
                }
            })
        
        // Event Channel for adapter state
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ADAPTER_STATE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    adapterStateSink = events
                    events?.success(getBluetoothAdapterState())
                }
                override fun onCancel(arguments: Any?) {
                    adapterStateSink = null
                }
            })
        
        // Event Channel for data received
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DATA_RECEIVED_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    dataReceivedSink = events
                }
                override fun onCancel(arguments: Any?) {
                    dataReceivedSink = null
                }
            })
        
        // Event Channel for phone battery
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    batterySink = events
                    // Send current battery state immediately
                    events?.success(mapOf(
                        "level" to BleScanService.phoneBatteryLevel,
                        "isCharging" to BleScanService.isPhoneCharging
                    ))
                }
                override fun onCancel(arguments: Any?) {
                    batterySink = null
                }
            })
    }

    private fun getBluetoothAdapterState(): Int {
        return when (bluetoothAdapter?.state) {
            BluetoothAdapter.STATE_OFF -> 0
            BluetoothAdapter.STATE_TURNING_ON -> 1
            BluetoothAdapter.STATE_ON -> 2
            BluetoothAdapter.STATE_TURNING_OFF -> 3
            else -> 0
        }
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
