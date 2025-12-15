package nl.liionpower.app

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
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
        private const val CHARGE_LIMIT_CHANNEL = "com.liion_app/charge_limit"
        private const val BATTERY_HEALTH_CHANNEL = "com.liion_app/battery_health"
        private const val MEASURE_DATA_CHANNEL = "com.liion_app/measure_data"
        private const val BATTERY_METRICS_CHANNEL = "com.liion_app/battery_metrics"
        private const val OTA_PROGRESS_CHANNEL = "com.liion_app/ota_progress"
        private const val LED_TIMEOUT_CHANNEL = "com.liion_app/led_timeout"
        private const val ADVANCED_MODES_CHANNEL = "com.liion_app/advanced_modes"
        private const val FILE_STREAMING_CHANNEL = "com.liion_app/file_streaming"
        private const val REQUEST_ENABLE_BT = 1001
        
        private var eventSink: EventChannel.EventSink? = null
        private var connectionEventSink: EventChannel.EventSink? = null
        private var adapterStateSink: EventChannel.EventSink? = null
        private var dataReceivedSink: EventChannel.EventSink? = null
        private var batterySink: EventChannel.EventSink? = null
        private var chargeLimitSink: EventChannel.EventSink? = null
        private var ledTimeoutSink: EventChannel.EventSink? = null
        private var batteryHealthSink: EventChannel.EventSink? = null
        private var measureDataSink: EventChannel.EventSink? = null
        private var batteryMetricsSink: EventChannel.EventSink? = null
        private var otaProgressSink: EventChannel.EventSink? = null
        private var advancedModesSink: EventChannel.EventSink? = null
        private var fileStreamingSink: EventChannel.EventSink? = null
        private var pendingBluetoothResult: MethodChannel.Result? = null
        
        fun clearAllSinks() {
            eventSink = null
            connectionEventSink = null
            adapterStateSink = null
            dataReceivedSink = null
            batterySink = null
            chargeLimitSink = null
            ledTimeoutSink = null
            batteryHealthSink = null
            batteryMetricsSink = null
            otaProgressSink = null
            advancedModesSink = null
            fileStreamingSink = null
        }
        
        fun sendOtaProgress(progress: Int, inProgress: Boolean, message: String?) {
            try {
                otaProgressSink?.success(mapOf(
                    "progress" to progress,
                    "inProgress" to inProgress,
                    "message" to (message ?: "")
                ))
            } catch (e: Exception) {
                otaProgressSink = null
            }
        }
        
        fun sendDeviceUpdate(address: String, name: String) {
            try {
                eventSink?.success(mapOf("address" to address, "name" to name))
            } catch (e: Exception) {
                eventSink = null
            }
        }
        
        fun sendConnectionUpdate(state: Int, address: String?) {
            try {
                connectionEventSink?.success(mapOf("state" to state, "address" to address))
            } catch (e: Exception) {
                connectionEventSink = null
            }
        }
        
        fun sendAdapterStateUpdate(state: Int) {
            try {
                adapterStateSink?.success(state)
            } catch (e: Exception) {
                adapterStateSink = null
            }
        }
        
        fun sendServicesDiscovered(services: List<String>) {
            // Can be used later
        }
        
        fun sendDataReceived(data: String) {
            try {
                dataReceivedSink?.success(data)
            } catch (e: Exception) {
                dataReceivedSink = null
            }
        }
        
        fun sendFileStreamingData(data: ByteArray) {
            try {
                // Convert ByteArray to List<Int> for Flutter compatibility
                val dataList = data.map { it.toInt() and 0xFF }
                fileStreamingSink?.success(dataList)
            } catch (e: Exception) {
                fileStreamingSink = null
            }
        }
        
        fun sendMeasureData(voltage: String, current: String) {
            try {
                measureDataSink?.success(mapOf("voltage" to voltage, "current" to current))
            } catch (e: Exception) {
                measureDataSink = null
            }
        }
        
        fun sendUartReady(ready: Boolean) {
            // UART ready
        }
        
        fun sendBatteryUpdate(level: Int, isCharging: Boolean) {
            try {
                batterySink?.success(mapOf("level" to level, "isCharging" to isCharging))
            } catch (e: Exception) {
                batterySink = null
            }
        }
        
        fun sendChargeLimitUpdate(limit: Int, enabled: Boolean) {
            try {
                chargeLimitSink?.success(mapOf(
                    "limit" to limit,
                    "enabled" to enabled,
                    "confirmed" to BleScanService.chargeLimitConfirmed
                ))
            } catch (e: Exception) {
                chargeLimitSink = null
            }
        }
        
        fun sendChargeLimitConfirmed(confirmed: Boolean) {
            try {
                chargeLimitSink?.success(mapOf(
                    "limit" to BleScanService.chargeLimit,
                    "enabled" to BleScanService.chargeLimitEnabled,
                    "confirmed" to confirmed
                ))
            } catch (e: Exception) {
                chargeLimitSink = null
            }
        }
        
        fun sendLedTimeoutUpdate(timeoutSeconds: Int) {
            try {
                ledTimeoutSink?.success(timeoutSeconds)
            } catch (e: Exception) {
                ledTimeoutSink = null
            }
        }
        
        fun sendAdvancedModesUpdate(ghostMode: Boolean, silentMode: Boolean, higherChargeLimit: Boolean) {
            try {
                advancedModesSink?.success(mapOf(
                    "ghostMode" to ghostMode,
                    "silentMode" to silentMode,
                    "higherChargeLimit" to higherChargeLimit
                ))
            } catch (e: Exception) {
                advancedModesSink = null
            }
        }
        
        fun sendBatteryHealthUpdate() {
            try {
                batteryHealthSink?.success(BleScanService.getBatteryHealthInfo())
            } catch (e: Exception) {
                batteryHealthSink = null
            }
        }
        
        fun sendBatteryMetricsUpdate(current: Double, voltage: Double, temperature: Double, accumulatedMah: Double, chargingTimeSeconds: Long, dischargingTimeSeconds: Long) {
            try {
                batteryMetricsSink?.success(mapOf(
                    "current" to current,
                    "voltage" to voltage,
                    "temperature" to temperature,
                    "accumulatedMah" to accumulatedMah,
                    "chargingTimeSeconds" to chargingTimeSeconds,
                    "dischargingTimeSeconds" to dischargingTimeSeconds
                ))
            } catch (e: Exception) {
                batteryMetricsSink = null
            }
        }
    }

    private var bluetoothAdapter: BluetoothAdapter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Clear any stale event sinks from previous instance
        clearAllSinks()
        
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
                    "setChargeLimit" -> {
                        val limit = call.argument<Int>("limit")
                        val enabled = call.argument<Boolean>("enabled")
                        if (limit != null && enabled != null) {
                            val success = BleScanService.setChargeLimit(limit, enabled)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Limit and enabled are required", null)
                        }
                    }
                    "getChargeLimit" -> {
                        result.success(BleScanService.getChargeLimitInfo())
                    }
                    "setChargeLimitEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled != null) {
                            val success = BleScanService.setChargeLimitEnabled(enabled)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Enabled is required", null)
                        }
                    }
                    "isBatteryOptimizationDisabled" -> {
                        result.success(isBatteryOptimizationDisabled())
                    }
                    "requestDisableBatteryOptimization" -> {
                        requestDisableBatteryOptimization()
                        result.success(true)
                    }
                    "getBatteryHealthInfo" -> {
                        result.success(BleScanService.getBatteryHealthInfo())
                    }
                    "startBatteryHealthCalculation" -> {
                        result.success(BleScanService.startBatteryHealthCalculation())
                    }
                    "stopBatteryHealthCalculation" -> {
                        BleScanService.stopBatteryHealthCalculation()
                        result.success(true)
                    }
                    "getBatterySessionHistory" -> {
                        val sessions = BleScanService.getBatterySessionHistory()
                        result.success(sessions)
                    }
                    "clearBatterySessionHistory" -> {
                        val success = BleScanService.clearBatterySessionHistory()
                        result.success(success)
                    }
                    "startOtaUpdate" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath != null) {
                            val success = BleScanService.startOtaUpdate(filePath)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "File path is required", null)
                        }
                    }
                    "cancelOtaUpdate" -> {
                        BleScanService.cancelOtaUpdate()
                        result.success(true)
                    }
                    "getOtaProgress" -> {
                        result.success(BleScanService.getOtaProgress())
                    }
                    "isOtaUpdateInProgress" -> {
                        result.success(BleScanService.isOtaUpdateInProgress())
                    }
                    "getLedTimeout" -> {
                        result.success(BleScanService.ledTimeoutSeconds)
                    }
                    "requestLedTimeout" -> {
                        result.success(BleScanService.requestLedTimeout())
                    }
                    "setLedTimeout" -> {
                        val seconds = call.argument<Int>("seconds")
                        if (seconds != null) {
                            val success = BleScanService.setLedTimeout(seconds)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Seconds is required", null)
                        }
                    }
                    "getAdvancedModes" -> {
                        result.success(BleScanService.getAdvancedModes())
                    }
                    "setGhostMode" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled != null) {
                            val success = BleScanService.setGhostMode(enabled)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Enabled is required", null)
                        }
                    }
                    "setSilentMode" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled != null) {
                            val success = BleScanService.setSilentMode(enabled)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Enabled is required", null)
                        }
                    }
                    "setHigherChargeLimit" -> {
                        val enabled = call.argument<Boolean>("enabled")
                        if (enabled != null) {
                            val success = BleScanService.setHigherChargeLimit(enabled)
                            result.success(success)
                        } else {
                            result.error("INVALID_ARGUMENT", "Enabled is required", null)
                        }
                    }
                    "requestAdvancedModes" -> {
                        result.success(BleScanService.requestAdvancedModes())
                    }
                    "minimizeApp" -> {
                        moveTaskToBack(true)
                        result.success(true)
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
                    events?.success(mapOf(
                        "level" to BleScanService.phoneBatteryLevel,
                        "isCharging" to BleScanService.isPhoneCharging
                    ))
                }
                override fun onCancel(arguments: Any?) {
                    batterySink = null
                }
            })
        
        // Event Channel for charge limit updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHARGE_LIMIT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    chargeLimitSink = events
                    events?.success(mapOf(
                        "limit" to BleScanService.chargeLimit,
                        "enabled" to BleScanService.chargeLimitEnabled,
                        "confirmed" to BleScanService.chargeLimitConfirmed
                    ))
                }
                override fun onCancel(arguments: Any?) {
                    chargeLimitSink = null
                }
            })
        
        // Event Channel for LED timeout updates
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, LED_TIMEOUT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    ledTimeoutSink = events
                    events?.success(BleScanService.ledTimeoutSeconds)
                }
                override fun onCancel(arguments: Any?) {
                    ledTimeoutSink = null
                }
            })
        
        // Event Channel for advanced modes
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ADVANCED_MODES_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    advancedModesSink = events
                    events?.success(BleScanService.getAdvancedModes())
                }
                override fun onCancel(arguments: Any?) {
                    advancedModesSink = null
                }
            })
        
        // Event Channel for battery health
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_HEALTH_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    batteryHealthSink = events
                    events?.success(BleScanService.getBatteryHealthInfo())
                }
                override fun onCancel(arguments: Any?) {
                    batteryHealthSink = null
                }
            })
        
        // Event Channel for measure data (voltage/current)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MEASURE_DATA_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    measureDataSink = events
                }
                override fun onCancel(arguments: Any?) {
                    measureDataSink = null
                }
            })
        
        // Event Channel for battery metrics (current, voltage, temperature, accumulated mAh)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_METRICS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    batteryMetricsSink = events
                }
                override fun onCancel(arguments: Any?) {
                    batteryMetricsSink = null
                }
            })
        
        // Event Channel for OTA progress
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, OTA_PROGRESS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    otaProgressSink = events
                }
                override fun onCancel(arguments: Any?) {
                    otaProgressSink = null
                }
            })
        
        // Event Channel for file streaming data
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_STREAMING_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    fileStreamingSink = events
                }
                override fun onCancel(arguments: Any?) {
                    fileStreamingSink = null
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
        // Mark service as intentionally stopping to avoid AlarmManager restarts
        BleScanService.markServiceStopping()
        val serviceIntent = Intent(this, BleScanService::class.java)
        stopService(serviceIntent)
    }
    
    private fun isBatteryOptimizationDisabled(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }
    
    private fun requestDisableBatteryOptimization() {
        if (!isBatteryOptimizationDisabled()) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            } catch (e: Exception) {
                // Fallback to battery optimization settings
                try {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                } catch (e2: Exception) {
                    e2.printStackTrace()
                }
            }
        }
    }
    
    override fun onDestroy() {
        // Clear event sinks when activity is destroyed
        clearAllSinks()
        super.onDestroy()
    }
}
