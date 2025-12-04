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
            // Prefer starting the MainActivity so the Flutter engine is created
            // and the action is forwarded to Dart via the keepalive channel.
            val i = Intent(context, MainActivity::class.java)
            i.putExtra("action", action)
            // Ensure we reuse the existing activity when possible; use
            // CLEAR_TOP so onNewIntent is delivered to a running activity.
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            context.startActivity(i)
        } catch (e: Exception) {
            Log.e("NotificationActionRcvr", "failed to forward action", e)
        }
    }
}
