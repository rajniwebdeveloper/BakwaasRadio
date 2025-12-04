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
	private lateinit var keepAliveChannel: MethodChannel

	companion object {
		// Store a pending notification action if it can't be delivered
		// immediately to the Dart side (for example if the Dart isolate
		// hasn't finished initializing). Dart can call `getPendingNotificationAction`
		// to retrieve and clear this value on startup.
		var pendingNotificationAction: String? = null
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		keepAliveChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
		keepAliveChannel.setMethodCallHandler { call, result ->
			when (call.method) {
				"startService" -> {
					try {
						val intent = Intent(this, PlaybackKeepAliveService::class.java)
						// Accept optional metadata map to show in the native notification
						val args = call.arguments
						if (args is Map<*, *>) {
							val title = args["title"] as? String
							val subtitle = args["subtitle"] as? String
							val artUri = args["artUri"] as? String
							// isPlaying/loading may be passed as strings ('true'/'false') or booleans
							val isPlayingRaw = args["isPlaying"]
							val loadingRaw = args["loading"]
							var isPlayingBool: Boolean? = null
							var loadingBool: Boolean? = null
							if (isPlayingRaw is Boolean) isPlayingBool = isPlayingRaw
							if (isPlayingRaw is String) isPlayingBool = isPlayingRaw.toBoolean()
							if (loadingRaw is Boolean) loadingBool = loadingRaw
							if (loadingRaw is String) loadingBool = loadingRaw.toBoolean()
							if (title != null) intent.putExtra("title", title)
							if (subtitle != null) intent.putExtra("subtitle", subtitle)
							if (artUri != null) intent.putExtra("artUri", artUri)
							if (isPlayingBool != null) intent.putExtra("isPlaying", isPlayingBool)
							if (loadingBool != null) intent.putExtra("loading", loadingBool)
						}
						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							try {
								startForegroundService(intent)
							} catch (ise: IllegalStateException) {
								// Some OEM/Android versions disallow starting a foreground
								// service from the background (mAllowStartForeground=false).
								// Fall back to a normal startService call to avoid a hard
								// exception; the service will attempt to call startForeground
								// itself when it can.
								startService(intent)
							}
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
				"getPendingNotificationAction" -> {
					result.success(pendingNotificationAction)
					pendingNotificationAction = null
				}
				else -> result.notImplemented()
			}
		}

		// If the Activity was started fresh from a notification action, the
		// Intent may contain an "action" extra. Forward it to Dart so the
		// background handler and PlaybackManager receive the notification action
		// even when the Activity is created (not just when onNewIntent is used).
		try {
			val initialAction = intent?.getStringExtra("action")
			if (initialAction != null) {
				try {
					keepAliveChannel.invokeMethod("notificationAction", initialAction)
				} catch (e: Exception) {
					// Dart may not be ready to receive method calls; stash the
					// action for Dart to retrieve after initialization.
					pendingNotificationAction = initialAction
				}
			}
			// Also handle a request to open the player with metadata coming
			// from the notification content tap. If present, forward to Dart
			// so the UI can navigate to the player immediately.
			try {
				val openPlayer = intent?.getBooleanExtra("openPlayer", false) ?: false
				if (openPlayer) {
					val m = HashMap<String, Any?>()
					intent?.getStringExtra("title")?.let { m["title"] = it }
					intent?.getStringExtra("subtitle")?.let { m["subtitle"] = it }
					intent?.getStringExtra("artUri")?.let { m["artUri"] = it }
					intent?.getStringExtra("url")?.let { m["url"] = it }
					keepAliveChannel.invokeMethod("openPlayer", m)
				}
			} catch (e: Exception) {
				// ignore
			}
		} catch (e: Exception) {
			Log.e("MainActivity", "failed to forward initial notification action", e)
		}
		// Volume control channel: get/set system media volume (0.0 - 1.0)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bakwaas.fm/volume").setMethodCallHandler { call, result ->
			try {
				val am = getSystemService(AUDIO_SERVICE) as AudioManager
				when (call.method) {
					"getVolume" -> {
						// If Dart isn't ready, remember the action for later retrieval.
						pendingNotificationAction = action
						Log.e("MainActivity", "failed to invoke notificationAction", e)
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

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		val action = intent.getStringExtra("action")
		if (action != null) {
			try {
				// Forward the notification action to Dart via the same keepalive channel.
				keepAliveChannel.invokeMethod("notificationAction", action)
			} catch (e: Exception) {
				Log.e("MainActivity", "failed to invoke notificationAction", e)
			}
		}
			// Also handle openPlayer intents arriving via newIntent
			try {
				val openPlayer = intent.getBooleanExtra("openPlayer", false)
				if (openPlayer) {
					val m = HashMap<String, Any?>()
					intent.getStringExtra("title")?.let { m["title"] = it }
					intent.getStringExtra("subtitle")?.let { m["subtitle"] = it }
					intent.getStringExtra("artUri")?.let { m["artUri"] = it }
					intent.getStringExtra("url")?.let { m["url"] = it }
					keepAliveChannel.invokeMethod("openPlayer", m)
				}
			} catch (e: Exception) {}
	}

}
