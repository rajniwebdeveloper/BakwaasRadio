Android platform notes

- Permissions to verify (already present in `AndroidManifest.xml`):
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_NETWORK_STATE`
  - `android.permission.FOREGROUND_SERVICE`
  - `android.permission.WAKE_LOCK`
  - `android.permission.POST_NOTIFICATIONS` (request at runtime for Android 13+)

- Notification icon:
  - Ensure `res/drawable/ic_stat_bakwaas` exists in `android/app/src/main/res/drawable` (or adjust `AudioServiceConfig.androidNotificationIcon`).

- Foreground service behavior:
  - `PlaybackKeepAliveService` uses `startForeground(...)` and the manifest sets `android:stopWithTask="false"` and `android:foregroundServiceType="mediaPlayback"` to keep playback running when the app is removed from Recents.

- Testing tips:
  - On Android 13+, the user must grant notification permission. Call `requestNotificationPermission()` early in your app (done in `main.dart`).
  - Use `adb logcat` to inspect `PlaybackKeepAliveService` and `AudioService` logs if notifications or service binding fail:
    ```bash
    adb logcat -s AudioService PlaybackKeepAliveService ActivityManager FlutterActivity com.bakwaas.fm *:S
    ```
