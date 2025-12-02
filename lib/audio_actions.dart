/// Lightweight bridge for audio action callbacks so the background
/// audio handler (which may run in a separate audio_service isolate)
/// can notify the app-level `PlaybackManager` of skip/play actions.
class AudioActions {
  static void Function()? onSkipNext;
  static void Function()? onSkipPrevious;
  static void Function()? onPlay;
  static void Function()? onPause;
}
