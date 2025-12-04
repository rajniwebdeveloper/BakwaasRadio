iOS platform notes

- Background audio:
  - `ios/Runner/Info.plist` must include `UIBackgroundModes` with `audio`. This allows playback to continue when the app is backgrounded.

- AVAudioSession:
  - `audio_session` + `audio_service` configure AVAudioSession at runtime. No Info.plist key is needed beyond `UIBackgroundModes` for audio.

- App capabilities / entitlements:
  - In Xcode, ensure the app's Background Modes capability includes "Audio, AirPlay, and Picture in Picture".

- Testing tips:
  - Use Xcode device console to inspect AVAudioSession activation and plugin logs.
  - If artwork or Now Playing info doesn't appear, ensure your `BackgroundAudioHandler` populates `MediaItem` metadata (title, album, artUri) before playback.
