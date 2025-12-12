package com.example.liion_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Date
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class BackendLoggingService private constructor() {

    companion object {
        @Volatile private var instance: BackendLoggingService? = null

        fun getInstance(): BackendLoggingService {
            return instance
                    ?: synchronized(this) {
                        instance ?: BackendLoggingService().also { instance = it }
                    }
        }
    }

    // Backend API configuration
    // Default: "http://10.0.2.2:3000" (Android emulator - maps to host machine's localhost)
    // For physical device: Use setBackendUrl() to set your computer's IP (e.g., "http://192.168.1.100:3000")
    private var backendBaseUrl: String = "http://13.62.9.177:3000"
    private val apiBasePath: String = "/api"
    
    /**
     * Set the backend server URL
     * @param url Full URL including protocol and port (e.g., "http://192.168.1.100:3000")
     */
    fun setBackendUrl(url: String) {
        backendBaseUrl = url.trimEnd('/') // Remove trailing slash if present
        Log.d("BackendLogging", "Backend URL set to: $backendBaseUrl")
    }

    private var deviceKey: String? = null
    private var sessionId: String? = null
    private var isInitialized = false
    private var context: Context? = null
    private var appVersion: String? = null
    private var buildNumber: String? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    // Format timestamp in Pakistani time without timezone offset notation
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("Asia/Karachi") // UTC+5
    }

    val initialized: Boolean
        get() = isInitialized

    fun initialize(context: Context, appVersion: String, buildNumber: String) {
        this.context = context.applicationContext
        this.appVersion = appVersion
        this.buildNumber = buildNumber

        scope.launch {
            try {
                Log.d("BackendLogging", "Initializing backend logging service")
                Log.d("BackendLogging", "Backend URL: $backendBaseUrl")
                Log.d("BackendLogging", "App Version: $appVersion, Build: $buildNumber")

                 // Dev-mode: avoid creating cloud sessions while iterating locally
                 Log.i("BackendLogging", "Skipping backend session creation in dev mode")
                 return@launch
                
                // Check network connectivity
                if (!hasNetworkConnection()) {
                    Log.w("BackendLogging", "No network connection available for backend logging")
                    return@launch
                }

                // Test backend connectivity first
                if (!testBackendConnection()) {
                    Log.e("BackendLogging", "Cannot reach backend server at $backendBaseUrl")
                    Log.e("BackendLogging", "For Android emulator: Use http://10.0.2.2:3000 (default)")
                    Log.e("BackendLogging", "For physical device: Call setBackendUrl() with your computer's IP (e.g., http://192.168.1.100:3000)")
                    return@launch
                }

                // Get device label
                deviceKey = getDeviceLabel()
                Log.d("BackendLogging", "Device key: $deviceKey")

                // First ensure device exists (check via GET /api/devices, create if not exists)
                Log.d("BackendLogging", "Ensuring device exists before getting session ID. Device key: $deviceKey")
                val deviceExists = ensureDeviceExists()
                if (!deviceExists) {
                    Log.e("BackendLogging", "Failed to ensure device exists. Device key: $deviceKey. Retrying...")
                    // Try one more time after a short delay
                    delay(2000)
                    val retryResult = ensureDeviceExists()
                    if (!retryResult) {
                        Log.e("BackendLogging", "Retry failed. Cannot proceed without device. Device key: $deviceKey, Backend URL: $backendBaseUrl")
                        return@launch
                    } else {
                        Log.d("BackendLogging", "Device created successfully on retry")
                    }
                } else {
                    Log.d("BackendLogging", "Device exists, proceeding with session ID retrieval")
                }

                // Get next session ID by querying existing sessions
                val nextSessionId = getNextSessionId()

                sessionId = nextSessionId
                Log.d("BackendLogging", "Session ID: $sessionId")

                // Create session via API (this will update session if it already exists)
                val sessionCreated = createSession(nextSessionId, appVersion, buildNumber)

                if (sessionCreated) {
                    isInitialized = true
                    Log.d("BackendLogging", "Logging session initialized successfully")
                    log("INFO", "Logging session initialized")
                } else {
                    Log.e("BackendLogging", "Failed to create session")
                }
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error in initialize", e)
            }
        }
    }

    private suspend fun getNextSessionId(): String {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("$backendBaseUrl$apiBasePath/sessions/device/$deviceKey")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.connectTimeout = 5000
                connection.readTimeout = 5000

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val sessions = org.json.JSONArray(response)
                    
                    var maxSessionId = 0
                    for (i in 0 until sessions.length()) {
                        val session = sessions.getJSONObject(i)
                        val id = session.getString("sessionId").trim()
                        val parsed = id.toIntOrNull()
                        if (parsed != null && parsed > maxSessionId) {
                            maxSessionId = parsed
                        }
                    }
                    (maxSessionId + 1).toString()
                } else if (responseCode == HttpURLConnection.HTTP_NOT_FOUND) {
                    // Device doesn't exist yet, start with session 1
                    "1"
                } else {
                    // On error, default to 1
                    "1"
                }
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error getting next session ID", e)
                "1" // Default to 1 on error
            }
        }
    }

    private suspend fun createSession(
        sessionId: String,
        appVersion: String,
        buildNumber: String
    ): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                // Device should already exist at this point, but create session
                Log.d("BackendLogging", "Creating/updating session. Device key: $deviceKey, Session ID: $sessionId")

                val url = URL("$backendBaseUrl$apiBasePath/sessions")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true
                connection.connectTimeout = 5000
                connection.readTimeout = 5000

                val requestBody = JSONObject().apply {
                    put("deviceKey", deviceKey)
                    put("sessionId", sessionId)
                    put("appVersion", appVersion)
                    put("buildNumber", buildNumber)
                }

                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(requestBody.toString())
                    writer.flush()
                }

                val responseCode = connection.responseCode
                val success = responseCode == HttpURLConnection.HTTP_OK || 
                             responseCode == HttpURLConnection.HTTP_CREATED

                if (success) {
                    Log.d("BackendLogging", "Session created successfully: $sessionId")
                } else {
                    val errorResponse = try {
                        connection.errorStream?.bufferedReader()?.use { it.readText() } ?: "No error message"
                    } catch (e: Exception) {
                        "Could not read error response: ${e.message}"
                    }
                    Log.e("BackendLogging", "Failed to create session. Response code: $responseCode, Error: $errorResponse")
                }

                success
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error creating session", e)
                false
            }
        }
    }

    private suspend fun ensureDeviceExists(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                if (deviceKey == null) {
                    Log.e("BackendLogging", "Device key is null, cannot check/create device")
                    return@withContext false
                }

                // First, check if device exists by getting all devices
                val checkUrl = "$backendBaseUrl$apiBasePath/devices"
                Log.d("BackendLogging", "Checking if device exists at: $checkUrl")
                val checkConnection = URL(checkUrl).openConnection() as HttpURLConnection
                checkConnection.requestMethod = "GET"
                checkConnection.setRequestProperty("Content-Type", "application/json")
                checkConnection.connectTimeout = 5000
                checkConnection.readTimeout = 5000

                val checkResponseCode = checkConnection.responseCode
                if (checkResponseCode == HttpURLConnection.HTTP_OK) {
                    val response = checkConnection.inputStream.bufferedReader().use { it.readText() }
                    val devices = org.json.JSONArray(response)
                    
                    // Check if device exists in the list
                    var deviceExists = false
                    for (i in 0 until devices.length()) {
                        val device = devices.getJSONObject(i)
                        val existingDeviceKey = device.getString("deviceKey")
                        if (existingDeviceKey == deviceKey) {
                            deviceExists = true
                            Log.d("BackendLogging", "Device found in list: $deviceKey")
                            break
                        }
                    }

                    if (deviceExists) {
                        // Device exists, no need to create
                        Log.d("BackendLogging", "Device already exists: $deviceKey")
                        return@withContext true
                    } else {
                        // Device doesn't exist, create it
                        Log.d("BackendLogging", "Device not found in list, creating new device: $deviceKey")
                    }
                } else {
                    // If GET fails, try to create device anyway
                    Log.w("BackendLogging", "Failed to get devices list (code: $checkResponseCode), attempting to create device")
                }

                // Create device if it doesn't exist
                val createUrl = "$backendBaseUrl$apiBasePath/devices"
                Log.d("BackendLogging", "Creating device at: $createUrl")
                val createConnection = URL(createUrl).openConnection() as HttpURLConnection
                createConnection.requestMethod = "POST"
                createConnection.setRequestProperty("Content-Type", "application/json")
                createConnection.doOutput = true
                createConnection.connectTimeout = 15000
                createConnection.readTimeout = 15000

                val requestBody = JSONObject().apply {
                    put("deviceKey", deviceKey)
                    put("platform", "android")
                }

                val requestBodyString = requestBody.toString()
                Log.d("BackendLogging", "Request body: $requestBodyString")

                OutputStreamWriter(createConnection.outputStream).use { writer ->
                    writer.write(requestBodyString)
                    writer.flush()
                }

                val createResponseCode = createConnection.responseCode
                Log.d("BackendLogging", "Device creation response code: $createResponseCode")
                
                if (createResponseCode == HttpURLConnection.HTTP_OK || 
                    createResponseCode == HttpURLConnection.HTTP_CREATED) {
                    val responseBody = try {
                        createConnection.inputStream.bufferedReader().use { it.readText() }
                    } catch (e: Exception) {
                        "Could not read response: ${e.message}"
                    }
                    Log.d("BackendLogging", "Device created successfully: $deviceKey. Response: $responseBody")
                    true
                } else {
                    val errorResponse = try {
                        createConnection.errorStream?.bufferedReader()?.use { it.readText() } ?: "No error message"
                    } catch (e: Exception) {
                        "Could not read error response: ${e.message}"
                    }
                    Log.e("BackendLogging", "Failed to create device. Response code: $createResponseCode, Error: $errorResponse, URL: $createUrl")
                    false
                }
            } catch (e: java.net.UnknownHostException) {
                Log.e("BackendLogging", "Cannot reach backend server at $backendBaseUrl. Is the server running?", e)
                false
            } catch (e: java.net.ConnectException) {
                Log.e("BackendLogging", "Connection refused to $backendBaseUrl. Is the server running?", e)
                false
            } catch (e: java.net.SocketTimeoutException) {
                Log.e("BackendLogging", "Timeout connecting to backend server at $backendBaseUrl", e)
                false
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error ensuring device exists: ${e.javaClass.simpleName} - ${e.message}", e)
                false
            }
        }
    }

    fun log(level: String, message: String) {
        if (!isInitialized || sessionId == null || deviceKey == null) {
            Log.d(
                    "BackendLogging",
                    "Logging skipped - not initialized. Level: $level, Message: $message"
            )
            return
        }

        scope.launch {
            try {
                if (!hasNetworkConnection()) {
                    Log.w("BackendLogging", "No network connection, skipping log")
                    return@launch
                }

                // Send log immediately (no batching)
                sendLog(level, message)
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error in log method", e)
            }
        }
    }

    private suspend fun sendLog(level: String, message: String) {
        withContext(Dispatchers.IO) {
            try {
                val url = URL("$backendBaseUrl$apiBasePath/logs")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.doOutput = true
                connection.connectTimeout = 5000
                connection.readTimeout = 5000

                val timestamp = dateFormat.format(Date())
                val requestBody = JSONObject().apply {
                    put("deviceKey", deviceKey)
                    put("sessionId", sessionId)
                    put("level", level)
                    put("message", message)
                    put("timestamp", timestamp)
                }

                OutputStreamWriter(connection.outputStream).use { writer ->
                    writer.write(requestBody.toString())
                    writer.flush()
                }

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_CREATED || 
                    responseCode == HttpURLConnection.HTTP_OK) {
                    Log.d("BackendLogging", "Log sent successfully: $level - $message")
                } else {
                    val errorResponse = connection.errorStream?.bufferedReader()?.use { it.readText() }
                    Log.e("BackendLogging", "Failed to send log: $errorResponse")
                }
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error sending log", e)
            }
        }
    }

    private suspend fun testBackendConnection(): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("$backendBaseUrl/health")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                
                val responseCode = connection.responseCode
                val success = responseCode == HttpURLConnection.HTTP_OK
                
                if (success) {
                    Log.d("BackendLogging", "Backend connection test successful")
                } else {
                    Log.e("BackendLogging", "Backend connection test failed. Response code: $responseCode")
                }
                
                success
            } catch (e: java.net.UnknownHostException) {
                Log.e("BackendLogging", "Cannot resolve backend host: $backendBaseUrl", e)
                false
            } catch (e: java.net.ConnectException) {
                Log.e("BackendLogging", "Connection refused to backend: $backendBaseUrl. Is the server running?", e)
                false
            } catch (e: java.net.SocketTimeoutException) {
                Log.e("BackendLogging", "Timeout connecting to backend: $backendBaseUrl", e)
                false
            } catch (e: Exception) {
                Log.e("BackendLogging", "Error testing backend connection: ${e.javaClass.simpleName} - ${e.message}", e)
                false
            }
        }
    }

    private fun hasNetworkConnection(): Boolean {
        val ctx = context ?: return false
        val connectivityManager =
                ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

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
        return mapOf("deviceKey" to deviceKey, "sessionId" to sessionId)
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
}
