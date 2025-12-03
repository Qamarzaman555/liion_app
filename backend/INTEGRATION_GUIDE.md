# Android Integration Guide

This guide explains how to update your Android `FirebaseLoggingService.kt` to use the custom backend instead of Firebase.

## Overview

The backend API provides the same functionality as Firebase:
- Session initialization
- Batch log insertion
- Automatic session ID generation

## Required Changes

### 1. Add HTTP Client Dependency

Add to `android/app/build.gradle.kts`:

```kotlin
dependencies {
    // ... existing dependencies
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("com.google.code.gson:gson:2.10.1")
}
```

### 2. Create API Service Interface

Create `android/app/src/main/kotlin/com/example/liion_app/LoggingApiService.kt`:

```kotlin
package com.example.liion_app

import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import com.google.gson.GsonBuilder
import java.util.concurrent.TimeUnit

data class InitializeSessionRequest(
    val deviceKey: String,
    val appVersion: String,
    val buildNumber: String,
    val platform: String = "android"
)

data class InitializeSessionResponse(
    val success: Boolean,
    val sessionId: Int,
    val deviceKey: String,
    val message: String
)

data class LogEntry(
    val ts: String? = null, // ISO 8601 format, optional
    val level: String,
    val message: String
)

data class BatchLogRequest(
    val sessionId: Int,
    val logs: List<LogEntry>
)

data class BatchLogResponse(
    val success: Boolean,
    val inserted: Int,
    val message: String
)

interface LoggingApiService {
    @POST("sessions/initialize")
    suspend fun initializeSession(
        @Body request: InitializeSessionRequest
    ): InitializeSessionResponse

    @POST("logs/batch")
    suspend fun batchLog(
        @Body request: BatchLogRequest
    ): BatchLogResponse
}

object LoggingApiClient {
    private const val BASE_URL = "http://your-backend-url:3000/api/v1/" // Update with your backend URL
    
    private val loggingInterceptor = HttpLoggingInterceptor().apply {
        level = HttpLoggingInterceptor.Level.BODY
    }
    
    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(loggingInterceptor)
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    
    private val gson = GsonBuilder()
        .setDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .create()
    
    private val retrofit = Retrofit.Builder()
        .baseUrl(BASE_URL)
        .client(okHttpClient)
        .addConverterFactory(GsonConverterFactory.create(gson))
        .build()
    
    val service: LoggingApiService = retrofit.create(LoggingApiService::class.java)
}
```

### 3. Update FirebaseLoggingService.kt

Replace Firebase calls with API calls:

```kotlin
// Add at the top
import retrofit2.HttpException
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*

class FirebaseLoggingService private constructor() {
    // ... existing code ...
    
    private var apiService: LoggingApiService? = null
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }
    
    fun initialize(context: Context, appVersion: String, buildNumber: String) {
        this.context = context.applicationContext
        
        // Initialize API service
        apiService = LoggingApiClient.service
        
        scope.launch {
            try {
                if (!hasNetworkConnection()) {
                    Log.w("FirebaseLogging", "No network connection available")
                    return@launch
                }
                
                deviceKey = getDeviceLabel()
                Log.d("FirebaseLogging", "Device key: $deviceKey")
                
                // Initialize session via API
                val request = InitializeSessionRequest(
                    deviceKey = deviceKey!!,
                    appVersion = appVersion,
                    buildNumber = buildNumber,
                    platform = "android"
                )
                
                val response = apiService?.initializeSession(request)
                if (response != null && response.success) {
                    sessionId = response.sessionId.toString()
                    isInitialized = true
                    Log.d("FirebaseLogging", "Logging session initialized: ${response.sessionId}")
                    log("INFO", "Logging session initialized")
                    
                    if (isSamsungDevice) {
                        startRetryMechanism()
                    }
                } else {
                    Log.e("FirebaseLogging", "Failed to initialize session")
                }
            } catch (e: Exception) {
                Log.e("FirebaseLogging", "Error in initialize", e)
                if (isSamsungDevice) {
                    scope.launch {
                        delay(5000)
                        initialize(context, appVersion, buildNumber)
                    }
                }
            }
        }
    }
    
    private suspend fun flushLogs(batch: List<Map<String, Any>>) {
        if (batch.isEmpty() || sessionId == null) return
        
        try {
            if (isSamsungDevice && !hasNetworkConnection()) {
                Log.w("FirebaseLogging", "Network not available, buffering logs")
                scope.launch { bufferMutex.withLock { failedLogsBuffer.addAll(batch) } }
                return
            }
            
            val logEntries = batch.map { entry ->
                val ts = entry["ts"] as? Date
                LogEntry(
                    ts = ts?.let { dateFormat.format(it) },
                    level = entry["level"] as String,
                    message = entry["message"] as String
                )
            }
            
            val request = BatchLogRequest(
                sessionId = sessionId!!.toInt(),
                logs = logEntries
            )
            
            val response = apiService?.batchLog(request)
            if (response != null && response.success) {
                Log.d("FirebaseLogging", "Successfully flushed ${response.inserted} logs")
            } else {
                throw Exception("Failed to flush logs")
            }
        } catch (e: HttpException) {
            Log.e("FirebaseLogging", "HTTP error flushing logs: ${e.code()}", e)
            if (isSamsungDevice) {
                scope.launch {
                    bufferMutex.withLock { failedLogsBuffer.addAll(batch) }
                }
            }
        } catch (e: IOException) {
            Log.e("FirebaseLogging", "Network error flushing logs", e)
            if (isSamsungDevice) {
                scope.launch {
                    bufferMutex.withLock { failedLogsBuffer.addAll(batch) }
                }
            }
        } catch (e: Exception) {
            Log.e("FirebaseLogging", "Exception flushing logs", e)
            if (isSamsungDevice) {
                scope.launch {
                    bufferMutex.withLock { failedLogsBuffer.addAll(batch) }
                }
            }
        }
    }
    
    // Remove registerNetworkRecovery method or update it to not use Firestore
    private fun registerNetworkRecovery() {
        val start = outageStart ?: return
        val end = Date()
        outageStart = null
        
        // Log network recovery events
        val outageEntry = hashMapOf(
            "ts" to start,
            "level" to "NETWORK_OUTAGE",
            "message" to "Network unavailable until $end."
        )
        val endEntry = hashMapOf(
            "ts" to end,
            "level" to "NETWORK_OUTAGE_END",
            "message" to "Connectivity restored."
        )
        
        // Add to buffer to be sent with next batch
        scope.launch {
            bufferMutex.withLock {
                logBuffer.add(outageEntry)
                logBuffer.add(endEntry)
            }
        }
    }
}
```

### 4. Add Internet Permission

Ensure `android/app/src/main/AndroidManifest.xml` has:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### 5. Update Base URL

Update `BASE_URL` in `LoggingApiClient` to point to your backend server:
- Local development: `http://10.0.2.2:3000/api/v1/` (Android emulator)
- Local device: `http://YOUR_COMPUTER_IP:3000/api/v1/`
- Production: `https://your-domain.com/api/v1/`

## Testing

1. Start your backend server
2. Run the Android app
3. Check backend logs to see incoming requests
4. Verify logs are being saved in the database

## Error Handling

The updated service maintains the same retry mechanism for Samsung devices and network failures. Failed logs are buffered and retried automatically.

## Migration Notes

- Remove Firebase dependencies from `build.gradle.kts` if no longer needed
- Update any code that directly accesses Firebase Firestore
- Test thoroughly with network interruptions
- Monitor backend logs for any issues

