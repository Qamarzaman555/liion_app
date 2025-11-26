package com.example.liion_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.*
import java.util.Date

class FirebaseLoggingService private constructor() {
    
    companion object {
        @Volatile
        private var instance: FirebaseLoggingService? = null
        
        fun getInstance(): FirebaseLoggingService {
            return instance ?: synchronized(this) {
                instance ?: FirebaseLoggingService().also { instance = it }
            }
        }
    }
    
    private var firestore: FirebaseFirestore? = null
    private var sessionDocPath: String? = null
    private var deviceKey: String? = null
    private var sessionId: String? = null
    private var isInitialized = false
    private var context: Context? = null
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    val initialized: Boolean get() = isInitialized
    
    fun initialize(context: Context, appVersion: String, buildNumber: String) {
        this.context = context.applicationContext
        
        scope.launch {
            try {
                // Check network connectivity
                if (!hasNetworkConnection()) {
                    return@launch
                }
                
                // Initialize Firebase if not already done
                if (FirebaseApp.getApps(context).isEmpty()) {
                    FirebaseApp.initializeApp(context)
                }
                
                firestore = FirebaseFirestore.getInstance()
                
                // Get device label
                deviceKey = getDeviceLabel()
                
                // Get next session ID
                val baseCollectionPath = "logs/app-logs/$deviceKey"
                
                firestore?.collection(baseCollectionPath)?.get()
                    ?.addOnSuccessListener { snapshot ->
                        var maxKey = 0
                        for (doc in snapshot.documents) {
                            val id = doc.id.trim()
                            val parsed = id.toIntOrNull()
                            if (parsed != null && parsed > maxKey) {
                                maxKey = parsed
                            }
                        }
                        
                        val nextKey = (maxKey + 1).toString()
                        sessionId = nextKey
                        sessionDocPath = "$baseCollectionPath/$nextKey"
                        
                        // Create session document
                        val sessionData = hashMapOf(
                            "createdAt" to FieldValue.serverTimestamp(),
                            "device" to deviceKey,
                            "platform" to "android",
                            "appVersion" to appVersion,
                            "buildNumber" to buildNumber,
                            "logs" to listOf<Map<String, Any>>()
                        )
                        
                        firestore?.document(sessionDocPath!!)
                            ?.set(sessionData, SetOptions.merge())
                            ?.addOnSuccessListener {
                                isInitialized = true
                                log("INFO", "Logging session initialized")
                            }
                            ?.addOnFailureListener { e ->
                                // Silently fail
                            }
                    }
                    ?.addOnFailureListener { e ->
                        // Silently fail
                    }
                
            } catch (e: Exception) {
                // Swallow errors
            }
        }
    }
    
    fun log(level: String, message: String) {
        if (!isInitialized || sessionDocPath == null) return
        
        scope.launch {
            try {
                // Check network before logging
                if (!hasNetworkConnection()) return@launch
                
                val logEntry = hashMapOf(
                    "ts" to Timestamp(Date()),
                    "level" to level,
                    "message" to message
                )
                
                firestore?.document(sessionDocPath!!)
                    ?.update("logs", FieldValue.arrayUnion(logEntry))
                    ?.addOnFailureListener { 
                        // Silently fail
                    }
                
            } catch (e: Exception) {
                // Ignore errors
            }
        }
    }
    
    // Convenience methods for different log levels
    fun logInfo(message: String) = log("INFO", message)
    fun logDebug(message: String) = log("DEBUG", message)
    fun logWarning(message: String) = log("WARNING", message)
    fun logError(message: String) = log("ERROR", message)
    
    // Specific logging methods for BLE operations
    fun logScan(message: String) = log("SCAN", message)
    fun logConnect(address: String, name: String) = log("CONNECT", "Connecting to $name ($address)")
    fun logConnected(address: String, name: String) = log("CONNECTED", "Connected to $name ($address)")
    fun logAutoConnect(address: String) = log("AUTO_CONNECT", "Auto-connecting to $address")
    fun logDisconnect(reason: String) = log("DISCONNECT", reason)
    fun logCommand(command: String) = log("COMMAND_SENT", command)
    fun logCommandResponse(response: String) = log("COMMAND_RESPONSE", response)
    fun logReconnect(attempt: Int, address: String) = log("RECONNECT", "Attempt $attempt to $address")
    fun logBleState(state: String) = log("BLE_STATE", state)
    fun logServiceState(state: String) = log("SERVICE", state)
    fun logChargeLimit(limit: Int, enabled: Boolean) = log("CHARGE_LIMIT", "Limit: $limit%, Enabled: $enabled")
    fun logBattery(level: Int, charging: Boolean) = log("BATTERY", "Level: $level%, Charging: $charging")
    
    private fun hasNetworkConnection(): Boolean {
        val ctx = context ?: return false
        val connectivityManager = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }
    
    private fun getDeviceLabel(): String {
        val device = Build.DEVICE
        val model = Build.MODEL
        return "$device - $model"
    }
    
    fun getSessionInfo(): Map<String, String?> {
        return mapOf(
            "deviceKey" to deviceKey,
            "sessionId" to sessionId
        )
    }
}

