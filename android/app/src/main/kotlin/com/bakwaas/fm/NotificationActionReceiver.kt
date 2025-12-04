package com.bakwaas.fm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.KeyEvent

/**
 * Receive notification action broadcasts and translate them into
 * media-button KeyEvents which are broadcast to the system. The
 * `audio_service` plugin (or any MediaButtonReceiver) will receive
 * these events and handle them even when the Flutter UI is suspended.
 */
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val action = intent?.getStringExtra("action") ?: return

            val keyCode = when (action) {
                "play", "pause", "toggle", "play_pause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                "previous", "prev" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                else -> null
            } ?: return

            // Send a down then up event to simulate a button press.
            val down = KeyEvent(KeyEvent.ACTION_DOWN, keyCode)
            val up = KeyEvent(KeyEvent.ACTION_UP, keyCode)

            val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            downIntent.putExtra(Intent.EXTRA_KEY_EVENT, down)
            context.sendOrderedBroadcast(downIntent, null)

            val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON)
            upIntent.putExtra(Intent.EXTRA_KEY_EVENT, up)
            context.sendOrderedBroadcast(upIntent, null)

            // Also start/notify the MainActivity with the action so Dart side
            // receives the event even when audio_service is not bound. This
            // may bring the activity to foreground on some devices.
            try {
                val activityIntent = Intent(context, MainActivity::class.java)
                activityIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                activityIntent.putExtra("action", action)
                context.startActivity(activityIntent)
            } catch (e: Exception) {
                Log.w("NotificationActionRcvr", "failed to start MainActivity for action: $action", e)
            }
        } catch (e: Exception) {
            Log.e("NotificationActionRcvr", "failed to forward media action", e)
        }
    }
}
