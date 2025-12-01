package com.bakwaas.fm

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.os.SystemClock
import android.util.Log

class PlaybackKeepAliveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("PlaybackKeepAliveService", "onStartCommand called flags=$flags startId=$startId")
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
