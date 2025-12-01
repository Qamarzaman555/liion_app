package com.example.liion_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import java.util.Date
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class FirebaseLoggingService private constructor() {

    companion object {
        @Volatile private var instance: FirebaseLoggingService? = null

        fun getInstance(): FirebaseLoggingService {
            return instance
                    ?: synchronized(this) {
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
    private val bufferMutex = Mutex()
    private val logBuffer = mutableListOf<Map<String, Any>>()
    private val failedLogsBuffer = mutableListOf<Map<String, Any>>()
    private val batchSize = 10
    private var outageStart: Date? = null
    private var retryJob: Job? = null
    private var isSamsungDevice = false

    val initialized: Boolean
        get() = isInitialized

    fun initialize(context: Context, appVersion: String, buildNumber: String) {
        this.context = context.applicationContext

        // // Detect Samsung devices
        // isSamsungDevice = Build.MANUFACTURER.equals("samsung", ignoreCase = true)
        // if (isSamsungDevice) {
        //     Log.d(
        //             "FirebaseLogging",
        //             "Samsung device detected - applying Samsung-specific workarounds"
        //     )
        // }

        // scope.launch {
        //     try {
        //         // Check network connectivity
        //         if (!hasNetworkConnection()) {
        //             Log.w("FirebaseLogging", "No network connection available for Firebase logging")
        //             return@launch
        //         }

        //         // Initialize Firebase if not already done
        //         if (FirebaseApp.getApps(context).isEmpty()) {
        //             try {
        //                 FirebaseApp.initializeApp(context)
        //                 Log.d("FirebaseLogging", "Firebase initialized")
        //             } catch (e: Exception) {
        //                 Log.e("FirebaseLogging", "Failed to initialize Firebase", e)
        //                 return@launch
        //             }
        //         }

        //         firestore = FirebaseFirestore.getInstance()
        //         if (firestore == null) {
        //             Log.e("FirebaseLogging", "Failed to get Firestore instance")
        //             return@launch
        //         }

        //         // Get device label
        //         deviceKey = getDeviceLabel()
        //         Log.d("FirebaseLogging", "Device key: $deviceKey")

        //         // Get next session ID
        //         val baseCollectionPath = "logs/app-logs/$deviceKey"

        //         firestore
        //                 ?.collection(baseCollectionPath)
        //                 ?.get()
        //                 ?.addOnSuccessListener { snapshot ->
        //                     try {
        //                         var maxKey = 0
        //                         for (doc in snapshot.documents) {
        //                             val id = doc.id.trim()
        //                             val parsed = id.toIntOrNull()
        //                             if (parsed != null && parsed > maxKey) {
        //                                 maxKey = parsed
        //                             }
        //                         }

        //                         val nextKey = (maxKey + 1).toString()
        //                         sessionId = nextKey
        //                         sessionDocPath = "$baseCollectionPath/$nextKey"

        //                         Log.d("FirebaseLogging", "Session path: $sessionDocPath")

        //                         // Create session document
        //                         val sessionData =
        //                                 hashMapOf(
        //                                         "createdAt" to FieldValue.serverTimestamp(),
        //                                         "device" to deviceKey,
        //                                         "platform" to "android",
        //                                         "appVersion" to appVersion,
        //                                         "buildNumber" to buildNumber,
        //                                         "logs" to listOf<Map<String, Any>>()
        //                                 )

        //                         firestore
        //                                 ?.document(sessionDocPath!!)
        //                                 ?.set(sessionData, SetOptions.merge())
        //                                 ?.addOnSuccessListener {
        //                                     isInitialized = true
        //                                     Log.d(
        //                                             "FirebaseLogging",
        //                                             "Logging session initialized successfully"
        //                                     )
        //                                     log("INFO", "Logging session initialized")

        //                                     // Start retry mechanism for Samsung devices
        //                                     if (isSamsungDevice) {
        //                                         startRetryMechanism()
        //                                     }
        //                                 }
        //                                 ?.addOnFailureListener { e ->
        //                                     Log.e(
        //                                             "FirebaseLogging",
        //                                             "Failed to create session document",
        //                                             e
        //                                     )
        //                                     // Retry initialization for Samsung devices
        //                                     if (isSamsungDevice) {
        //                                         scope.launch {
        //                                             delay(5000) // Wait 5 seconds before retry
        //                                             initialize(context, appVersion, buildNumber)
        //                                         }
        //                                     }
        //                                 }
        //                     } catch (e: Exception) {
        //                         Log.e("FirebaseLogging", "Error processing snapshot", e)
        //                     }
        //                 }
        //                 ?.addOnFailureListener { e ->
        //                     Log.e("FirebaseLogging", "Failed to get collection snapshot", e)
        //                 }
        //     } catch (e: Exception) {
        //         Log.e("FirebaseLogging", "Error in initialize", e)
        //     }
        // }
    }

    fun log(level: String, message: String) {
        if (!isInitialized || sessionDocPath == null) {
            Log.d(
                    "FirebaseLogging",
                    "Logging skipped - not initialized. Level: $level, Message: $message"
            )
            return
        }

        scope.launch {
            try {
                if (!hasNetworkConnection()) {
                    registerNetworkLoss()
                    return@launch
                } else {
                    registerNetworkRecovery()
                }

                val logEntry =
                        hashMapOf("ts" to Timestamp(Date()), "level" to level, "message" to message)
                enqueueLog(logEntry)
            } catch (e: Exception) {
                Log.e("FirebaseLogging", "Error in log method", e)
            }
        }
    }

    private suspend fun enqueueLog(entry: Map<String, Any>) {
        var batchToFlush: List<Map<String, Any>>? = null
        bufferMutex.withLock {
            logBuffer.add(entry)
            if (logBuffer.size >= batchSize) {
                batchToFlush = ArrayList(logBuffer)
                logBuffer.clear()
            }
        }
        batchToFlush?.let { flushLogs(it) }
    }

    private suspend fun flushLogs(batch: List<Map<String, Any>>) {
        if (batch.isEmpty()) return
        val docPath = sessionDocPath ?: return
        val document = firestore?.document(docPath) ?: return

        try {
            // For Samsung devices, check network more thoroughly
            if (isSamsungDevice && !hasNetworkConnection()) {
                Log.w("FirebaseLogging", "Samsung device: Network not available, buffering logs")
                scope.launch { bufferMutex.withLock { failedLogsBuffer.addAll(batch) } }
                return
            }

            document.update("logs", FieldValue.arrayUnion(*batch.toTypedArray()))
                    .addOnSuccessListener {
                        Log.d("FirebaseLogging", "Successfully flushed ${batch.size} logs")
                    }
                    .addOnFailureListener { e ->
                        Log.e("FirebaseLogging", "Failed to flush logs", e)
                        // For Samsung devices, retry failed logs
                        if (isSamsungDevice) {
                            scope.launch {
                                bufferMutex.withLock { failedLogsBuffer.addAll(batch) }
                                Log.d(
                                        "FirebaseLogging",
                                        "Buffered ${batch.size} failed logs for retry (Samsung device)"
                                )
                            }
                        }
                    }
        } catch (e: Exception) {
            Log.e("FirebaseLogging", "Exception flushing logs", e)
            if (isSamsungDevice) {
                scope.launch { bufferMutex.withLock { failedLogsBuffer.addAll(batch) } }
            }
        }
    }

    private fun startRetryMechanism() {
        retryJob?.cancel()
        retryJob =
                scope.launch {
                    while (isActive && isInitialized) {
                        delay(30000) // Retry every 30 seconds for Samsung devices

                        if (hasNetworkConnection()) {
                            val logsToRetry =
                                    bufferMutex.withLock {
                                        if (failedLogsBuffer.isEmpty()) {
                                            emptyList()
                                        } else {
                                            val batch = ArrayList(failedLogsBuffer)
                                            failedLogsBuffer.clear()
                                            batch
                                        }
                                    }

                            if (logsToRetry.isNotEmpty()) {
                                Log.d(
                                        "FirebaseLogging",
                                        "Retrying ${logsToRetry.size} failed logs (Samsung device)"
                                )
                                flushLogs(logsToRetry)
                            }
                        }
                    }
                }
    }

    private fun registerNetworkLoss() {
        scope.launch { bufferMutex.withLock { logBuffer.clear() } }
        if (outageStart == null) {
            outageStart = Date()
        }
    }

    private fun registerNetworkRecovery() {
        val start = outageStart ?: return
        val end = Date()
        outageStart = null

        val outageEntry =
                hashMapOf(
                        "ts" to Timestamp(start),
                        "level" to "NETWORK_OUTAGE",
                        "message" to "Network unavailable until $end."
                )
        val endEntry =
                hashMapOf(
                        "ts" to Timestamp(end),
                        "level" to "NETWORK_OUTAGE_END",
                        "message" to "Connectivity restored."
                )

        val docPath = sessionDocPath ?: return
        firestore?.document(docPath)?.update("logs", FieldValue.arrayUnion(outageEntry, endEntry))
    }

    // Convenience methods for different log levels
    fun logInfo(message: String) = log("INFO", message)
    fun logDebug(message: String) = log("DEBUG", message)
    fun logWarning(message: String) = log("WARNING", message)
    fun logError(message: String) = log("ERROR", message)

    // Specific logging methods for BLE operations
    fun logScan(message: String) = log("SCAN", message)
    fun logConnect(address: String, name: String) = log("CONNECT", "Connecting to $name ($address)")
    fun logConnected(address: String, name: String) =
            log("CONNECTED", "Connected to $name ($address)")
    fun logAutoConnect(address: String) = log("AUTO_CONNECT", "Auto-connecting to $address")
    fun logDisconnect(reason: String) = log("DISCONNECT", reason)
    fun logCommand(command: String) = log("COMMAND_SENT", command)
    fun logCommandResponse(response: String) = log("COMMAND_RESPONSE", response)
    fun logReconnect(attempt: Int, address: String) =
            log("RECONNECT", "Attempt $attempt to $address")
    fun logBleState(state: String) = log("BLE_STATE", state)
    fun logServiceState(state: String) = log("SERVICE", state)
    fun logChargeLimit(limit: Int, enabled: Boolean) =
            log("CHARGE_LIMIT", "Limit: $limit%, Enabled: $enabled")
    fun logBattery(level: Int, charging: Boolean) =
            log("BATTERY", "Level: $level%, Charging: $charging")

    private fun hasNetworkConnection(): Boolean {
        val ctx = context ?: return false
        val connectivityManager =
                ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false

        val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val isValidated = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)

        // For Samsung devices, be more lenient - sometimes VALIDATED might be false
        // but network is still usable (Samsung's aggressive optimization)
        if (isSamsungDevice) {
            return hasInternet &&
                    (isValidated ||
                            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR))
        }

        return hasInternet && isValidated
    }

    private fun getDeviceLabel(): String {
        val device = Build.DEVICE
        val model = Build.MODEL
        return "$device - $model"
    }

    fun getSessionInfo(): Map<String, String?> {
        return mapOf("deviceKey" to deviceKey, "sessionId" to sessionId)
    }
}
