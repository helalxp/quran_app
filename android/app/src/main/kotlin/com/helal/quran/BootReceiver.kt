package com.helal.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver that triggers when device boots up.
 * Launches the app silently to reschedule all prayer alarms.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {

            Log.d(TAG, "📱 Device booted - launching app to reschedule prayer alarms")

            try {
                // Launch MainActivity in background to reschedule alarms
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                    putExtra("boot_reschedule", true)
                }

                context.startActivity(launchIntent)

                Log.d(TAG, "✅ App launched for alarm rescheduling")

            } catch (e: Exception) {
                Log.e(TAG, "❌ Error launching app after boot: ${e.message}", e)
            }
        }
    }
}
