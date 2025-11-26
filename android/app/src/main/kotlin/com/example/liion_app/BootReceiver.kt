package com.example.liion_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            
            // Check if auto-reconnect was enabled (meaning user was using the service)
            val prefs = context.getSharedPreferences(BleScanService.PREFS_NAME, Context.MODE_PRIVATE)
            val shouldStart = prefs.getBoolean(BleScanService.KEY_AUTO_RECONNECT, false)
            
            if (shouldStart) {
                val serviceIntent = Intent(context, BleScanService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}

