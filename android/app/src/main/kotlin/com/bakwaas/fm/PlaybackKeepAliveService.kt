package com.bakwaas.fm

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.os.SystemClock
import android.util.Log
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.Notification.Builder as FrameworkNotificationBuilder
import android.graphics.drawable.Icon
import android.graphics.BitmapFactory
import android.media.session.MediaSession

class PlaybackKeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("PlaybackKeepAliveService", "onStartCommand called flags=$flags startId=$startId")

        // Create notification channel and foreground notification so Android
        // will keep the service alive as a foreground service.
        // Use the same channel id as the audio_service config in Dart so
        // the notification appears in the same Android channel.
        val channelId = "com.bakwaas.fm.audio"
        val channelName = "Bakwaas Audio"
        val notificationId = 101

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(chan)
        }

        // Notification tap should open the app's main activity (full player UI).
        // Previously this sent a broadcast for "next" which could be confusing
        // and made the notification tap not open the app. Use an activity
        // pending intent so tapping the notification brings the app to foreground.
        // Build an intent that will both bring the app to foreground and
        // carry metadata so the Dart side can open the player UI immediately.
        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // Pass along meta so Dart can open the full player when tapped.
            // These extras are best-effort; if not present they will be ignored.
            intent?.extras?.let {
                // no-op; keep existing extras if any
            }
        }
        // When we show notification metadata (title/subtitle/artUri) pass those along
        // so tapping the notification can open the app to that specific item.
        try {
            val titleExtra = intent?.getStringExtra("title")
            val subtitleExtra = intent?.getStringExtra("subtitle")
            val artUriExtra = intent?.getStringExtra("artUri")
            val urlExtra = intent?.getStringExtra("url")
            if (titleExtra != null) openIntent.putExtra("title", titleExtra)
            if (subtitleExtra != null) openIntent.putExtra("subtitle", subtitleExtra)
            if (artUriExtra != null) openIntent.putExtra("artUri", artUriExtra)
            if (urlExtra != null) openIntent.putExtra("url", urlExtra)
            // Signal that the intent should open the player UI
            openIntent.putExtra("openPlayer", true)
        } catch (e: Exception) {}

        val pendingOpen = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Actions: previous, play/pause, next — these open MainActivity with an "action" extra
        // Use broadcast pending intents for action buttons. A small
        // `NotificationActionReceiver` will receive these and forward the
        // action to the activity (or handle it directly). Using broadcasts
        // avoids launching an activity directly from the notification action
        // and works more consistently across Android 12+.
        val prevIntent = Intent(this, NotificationActionReceiver::class.java).apply { putExtra("action", "previous") }
        val prevPending = PendingIntent.getBroadcast(this, 2, prevIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val playIntent = Intent(this, NotificationActionReceiver::class.java).apply { putExtra("action", "play") }
        val playPending = PendingIntent.getBroadcast(this, 3, playIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        val nextIntent = Intent(this, NotificationActionReceiver::class.java).apply { putExtra("action", "next") }
        val nextPending = PendingIntent.getBroadcast(this, 4, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        // Try to load a large icon from resources if available
        // Prefer artwork passed via intent extras (file:// URI) so the
        // notification can show the currently-playing artwork even when
        // the Flutter engine is not running. Fallback to bundled resource.
        val artUriString = intent?.getStringExtra("artUri")
        val largeIcon = try {
            if (artUriString != null) {
                if (artUriString.startsWith("file://")) {
                    val path = artUriString.removePrefix("file://")
                    BitmapFactory.decodeFile(path)
                } else if (artUriString.startsWith("http://") || artUriString.startsWith("https://")) {
                    // Try to download the image synchronously with a short timeout
                    try {
                        val url = java.net.URL(artUriString)
                        val conn = url.openConnection()
                        conn.connectTimeout = 3000
                        conn.readTimeout = 3000
                        val `is` = conn.getInputStream()
                        val bmp = BitmapFactory.decodeStream(`is`)
                        try { `is`.close() } catch (ignored: Exception) {}
                        bmp
                    } catch (e: Exception) {
                        BitmapFactory.decodeResource(resources, R.drawable.ic_stat_bakwaas)
                    }
                } else {
                    BitmapFactory.decodeResource(resources, R.drawable.ic_stat_bakwaas)
                }
            } else {
                BitmapFactory.decodeResource(resources, R.drawable.ic_stat_bakwaas)
            }
        } catch (e: Exception) {
            null
        }

        // Create a MediaSessionCompat so the notification/media framework has a
        // valid compat media session token. This improves lock-screen controls
        // and allows the system to show the rich media controls and artwork.
        val mediaSession = MediaSession(this, "BakwaasMediaSession")
        mediaSession.setActive(true)

        // Read title/subtitle and playback flags from intent extras when provided.
        val titleExtra = intent?.getStringExtra("title") ?: "Bakwaas FM"
        var subtitleExtra = intent?.getStringExtra("subtitle") ?: "Playing"
        val isPlayingExtra = try { intent?.getBooleanExtra("isPlaying", false) ?: false } catch (e: Exception) { false }
        val loadingExtra = try { intent?.getBooleanExtra("loading", false) ?: false } catch (e: Exception) { false }
        if (loadingExtra) {
            subtitleExtra = "Playing..."
        }

        // Build a notification. Prefer the framework Notification.Builder with
        // MediaStyle on Android O+ so the media session token is accepted and
        // action icons appear correctly on the lock screen and compact view.
        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val playIconRes = if (isPlayingExtra) R.drawable.ic_pause else R.drawable.ic_play
            val nb = FrameworkNotificationBuilder(this, channelId)
                .setContentTitle(titleExtra)
                .setContentText(subtitleExtra)
                .setSmallIcon(R.drawable.ic_stat_bakwaas)
                .setLargeIcon(largeIcon)
                .setContentIntent(pendingOpen)
                .setOngoing(true)

            // Add actions with icons so the notification shows icon buttons.
            // Provide readable titles for actions so they are easier to tap on
            // some device notification UIs and so the touch area is slightly
            // larger than an icon-only action.
            nb.addAction(Notification.Action.Builder(Icon.createWithResource(this, R.drawable.ic_prev), "Prev", prevPending).build())
            nb.addAction(Notification.Action.Builder(Icon.createWithResource(this, playIconRes), if (isPlayingExtra) "Pause" else "Play", playPending).build())
            nb.addAction(Notification.Action.Builder(Icon.createWithResource(this, R.drawable.ic_next), "Next", nextPending).build())

            // Show a spinner/progress when loading/buffering, otherwise clear progress.
            if (loadingExtra) {
                nb.setProgress(0, 0, true)
            } else {
                nb.setProgress(0, 0, false)
            }

            // Attach framework MediaStyle that accepts a framework session token.
            nb.setStyle(Notification.MediaStyle().setShowActionsInCompactView(0,1,2).setMediaSession(mediaSession.sessionToken))
            nb.build()
        } else {
            // Fallback: use NotificationCompat for older devices (icons may be shown differently).
            val playIconRes = if (isPlayingExtra) R.drawable.ic_pause else R.drawable.ic_play
            val cb = NotificationCompat.Builder(this, channelId)
                .setContentTitle(titleExtra)
                .setContentText(subtitleExtra)
                .setSmallIcon(R.drawable.ic_stat_bakwaas)
                .setLargeIcon(largeIcon)
                .setContentIntent(pendingOpen)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .addAction(R.drawable.ic_prev, "Prev", prevPending)
                .addAction(playIconRes, if (isPlayingExtra) "Pause" else "Play", playPending)
                .addAction(R.drawable.ic_next, "Next", nextPending)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            if (loadingExtra) {
                cb.setProgress(0, 0, true)
            } else {
                cb.setProgress(0, 0, false)
            }
            cb.build()
        }

        startForeground(notificationId, notification)

        // Keep the MediaSessionCompat around while the service runs; release when destroyed.
        _mediaSession = mediaSession

        // Return START_STICKY so the system will try to recreate the service
        // after it has enough memory.
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d("PlaybackKeepAliveService", "onTaskRemoved: scheduling restart rootIntent=${rootIntent}")

        // Schedule a restart shortly after the task is removed. This attempts
        // to restart the service and give the audio system a chance to recover.
        val restartIntent = Intent(applicationContext, PlaybackKeepAliveService::class.java)
        val pending = PendingIntent.getService(
            applicationContext,
            1,
            restartIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.set(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + 500, pending)
    }

    override fun onDestroy() {
        try {
            _mediaSession?.release()
        } catch (e: Exception) {
            Log.w("PlaybackKeepAliveService", "failed to release media session: $e")
        }
        // If the service is destroyed unexpectedly, schedule a quick restart
        // to try to recover the foreground notification and keep playback alive.
        try {
            val restart = Intent(applicationContext, PlaybackKeepAliveService::class.java)
            val pending = PendingIntent.getService(
                applicationContext,
                2,
                restart,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.set(AlarmManager.ELAPSED_REALTIME, SystemClock.elapsedRealtime() + 750, pending)
        } catch (e: Exception) {
            Log.w("PlaybackKeepAliveService", "failed to schedule restart: $e")
        }

        super.onDestroy()
        Log.d("PlaybackKeepAliveService", "onDestroy called")
    }

    // Hold media session so it can be released on destroy
    private var _mediaSession: MediaSession? = null
}
