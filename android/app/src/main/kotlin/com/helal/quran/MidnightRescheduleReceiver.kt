package com.helal.quran

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * BroadcastReceiver that triggers at midnight to reschedule next day's prayer alarms.
 * Launches the app silently to recalculate and reschedule all prayer times.
 */
class MidnightRescheduleReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "MidnightReschedule"
        const val ACTION_RESCHEDULE = "com.helal.quran.MIDNIGHT_RESCHEDULE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🌙 Midnight reschedule triggered")

        try {
            // Launch MainActivity in background to reschedule alarms
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
                addFlags(Intent.FLAG_ACTIVITY_NO_ANIMATION)
                putExtra("midnight_reschedule", true)
            }

            context.startActivity(launchIntent)

            Log.d(TAG, "✅ App launched for midnight rescheduling")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in midnight reschedule: ${e.message}", e)
        }
    }
}
