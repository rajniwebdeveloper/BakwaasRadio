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

        val openIntent = Intent(this, MainActivity::class.java)
        openIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pendingOpen = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Bakwaas FM")
            .setContentText("Keeping playback alive")
            .setSmallIcon(R.drawable.ic_stat_bakwaas)
            .setContentIntent(pendingOpen)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(notificationId, notification)

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
        super.onDestroy()
        Log.d("PlaybackKeepAliveService", "onDestroy called")
    }
}
