/// App-wide constants for EarlyEcho screening.
library;

/// Numeric contract shared by the Flutter UI and the native audio pipeline.
///
/// These values mirror the protocol in the project context document:
/// three elicitation protocols totalling roughly 200 seconds of passive
/// recording, analysed as 16 kHz mono PCM in 30 ms VAD frames, for children
/// between 12 and 60 months of age.
class EarlyEchoConstants {
  EarlyEchoConstants._();

  // ── Method channel (Flutter ↔ Kotlin audio pipeline) ──
  static const String audioPipelineChannel = 'com.earlyecho/audio_pipeline';

  // ── Method channel (Flutter ↔ Kotlin video-quality pipeline) ──
  static const String videoPipelineChannel = 'com.earlyecho/video_pipeline';

  // ── Child age bounds (months) ──
  static const int minChildAgeMonths = 12;
  static const int maxChildAgeMonths = 60;

  // ── Elicitation protocol durations (seconds) ──
  static const int rattleProtocolSeconds = 60;
  static const int toyHideProtocolSeconds = 80;
  static const int imitationProtocolSeconds = 60;

  /// Approximate total passive recording time across all three protocols.
  static const int elicitationTotalSeconds = 200;

  // ── Audio capture ──
  static const int audioSampleRateHz = 16000;

  /// Mono capture — a single channel keeps the pipeline light.
  static const int audioChannels = 1;

  /// WebRTC VAD frame duration.
  static const int vadFrameSizeMs = 30;

  /// Samples per VAD frame at [audioSampleRateHz] (480 at 16 kHz).
  static const int vadFrameSamples = audioSampleRateHz * vadFrameSizeMs ~/ 1000;
}
