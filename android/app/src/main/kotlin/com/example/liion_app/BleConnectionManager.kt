package com.example.liion_app

import android.bluetooth.*
import android.content.Context
import android.os.Handler
import android.os.Looper

class BleConnectionManager(private val context: Context) {

    companion object {
        const val STATE_DISCONNECTED = 0
        const val STATE_CONNECTING = 1
        const val STATE_CONNECTED = 2
    }

    private var bluetoothGatt: BluetoothGatt? = null
    private var connectionState = STATE_DISCONNECTED
    private var connectedDeviceAddress: String? = null

    var onConnectionStateChanged: ((Int, String?) -> Unit)? = null
    var onServicesDiscovered: ((List<BluetoothGattService>) -> Unit)? = null

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            Handler(Looper.getMainLooper()).post {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        connectionState = STATE_CONNECTED
                        connectedDeviceAddress = gatt.device.address
                        onConnectionStateChanged?.invoke(STATE_CONNECTED, connectedDeviceAddress)
                        try {
                            gatt.discoverServices()
                        } catch (e: SecurityException) {
                            e.printStackTrace()
                        }
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        connectionState = STATE_DISCONNECTED
                        connectedDeviceAddress = null
                        onConnectionStateChanged?.invoke(STATE_DISCONNECTED, null)
                        closeGatt()
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            Handler(Looper.getMainLooper()).post {
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    onServicesDiscovered?.invoke(gatt.services)
                }
            }
        }
    }

    fun connect(address: String): Boolean {
        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val bluetoothAdapter = bluetoothManager.adapter ?: return false

        return try {
            val device = bluetoothAdapter.getRemoteDevice(address)
            connectionState = STATE_CONNECTING
            onConnectionStateChanged?.invoke(STATE_CONNECTING, address)
            bluetoothGatt = device.connectGatt(context, false, gattCallback)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun disconnect() {
        try {
            bluetoothGatt?.disconnect()
        } catch (e: SecurityException) {
            e.printStackTrace()
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

    fun getConnectionState(): Int = connectionState

    fun getConnectedDeviceAddress(): String? = connectedDeviceAddress

    fun isConnected(): Boolean = connectionState == STATE_CONNECTED
}

