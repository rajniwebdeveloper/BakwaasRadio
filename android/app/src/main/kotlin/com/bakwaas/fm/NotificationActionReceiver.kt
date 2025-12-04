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

            // Also start the MainActivity with the action extra as a best-effort
            // delivery for cases where the app is using the local player (no
            // audio_service background handler) so notification actions are
            // forwarded into Dart. Use TASK flags to avoid creating multiple
            // activity instances; MainActivity will debounce duplicate
            // actions on the Dart side.
            try {
                val activityIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("action", action)
                }
                context.startActivity(activityIntent)
            } catch (e: Exception) {
                // ignore failures to start the activity - media key events were
                // already dispatched above and should be handled by the
                // media framework if available.
            }

            // We intentionally do NOT start the MainActivity here for media
            // actions (play/pause/next/previous). Media button KeyEvents are
            // broadcasted above and handled by the media framework or
            // audio_service. Starting the activity here caused duplicate
            // delivery of the same action into Dart (via MainActivity), which
            // resulted in double toggles/duplicates on some devices.
            // If you need to open the app from the notification content tap,
            // the service provides an activity pending intent for that purpose.
        } catch (e: Exception) {
            Log.e("NotificationActionRcvr", "failed to forward media action", e)
        }
    }
}
