package com.helal.quran

import android.app.Application
import android.util.Log

/**
 * Custom Application class for the Quran app.
 * android_alarm_manager_plus requires an Application class to be specified
 * for proper background callback initialization.
 */
class MyApplication : Application() {

    companion object {
        private const val TAG = "MyApplication"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "✅ MyApplication initialized")
    }
}
