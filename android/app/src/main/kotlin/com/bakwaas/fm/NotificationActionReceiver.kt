package com.bakwaas.fm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receive notification action broadcasts and forward them to the app.
 *
 * For simplicity we start the MainActivity with the action extra so the
 * existing `onNewIntent` code path handles forwarding to Dart. This
 * behavior is user-initiated (notification tap) so it's allowed on
 * modern Android versions and keeps the implementation simple.
 */
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val action = intent?.getStringExtra("action")
            if (action == null) return
            val i = Intent(context, MainActivity::class.java)
            i.putExtra("action", action)
            // We're in a BroadcastReceiver; ensure we start activity from
            // a new task so the system will bring or create the activity.
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            context.startActivity(i)
        } catch (e: Exception) {
            Log.e("NotificationActionRcvr", "failed to forward action", e)
        }
    }
}
