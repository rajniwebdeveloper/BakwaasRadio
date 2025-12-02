package com.bakwaas.fm

import android.content.Intent
import android.os.Build
import android.util.Log
import android.media.AudioManager
import kotlin.math.roundToInt
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
	private val CHANNEL = "com.bakwaas.fm/keepalive"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"startService" -> {
					try {
						val intent = Intent(this, PlaybackKeepAliveService::class.java)
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							startForegroundService(intent)
						} else {
							startService(intent)
						}
						result.success(true)
					} catch (e: Exception) {
						Log.e("MainActivity", "startService failed", e)
						result.error("start_failed", e.message, null)
					}
				}
				"stopService" -> {
					try {
						val intent = Intent(this, PlaybackKeepAliveService::class.java)
						stopService(intent)
						result.success(true)
					} catch (e: Exception) {
						Log.e("MainActivity", "stopService failed", e)
						result.error("stop_failed", e.message, null)
					}
				}
				else -> result.notImplemented()
			}
		}
		// Volume control channel: get/set system media volume (0.0 - 1.0)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bakwaas.fm/volume").setMethodCallHandler { call, result ->
			try {
				val am = getSystemService(AUDIO_SERVICE) as AudioManager
				when (call.method) {
					"getVolume" -> {
						val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
						val cur = am.getStreamVolume(AudioManager.STREAM_MUSIC)
						val frac = if (max > 0) cur.toDouble() / max.toDouble() else 0.0
						result.success(frac)
					}
					"setVolume" -> {
						val arg = call.arguments as? Double ?: (call.arguments as? Number)?.toDouble() ?: 0.0
						val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
						val vol = (arg * max).roundToInt().coerceIn(0, max)
						am.setStreamVolume(AudioManager.STREAM_MUSIC, vol, AudioManager.FLAG_SHOW_UI)
						result.success(true)
					}
					else -> result.notImplemented()
				}
			} catch (e: Exception) {
				Log.e("MainActivity", "volume channel error", e)
				result.error("volume_error", e.message, null)
			}
		}
	}
}
