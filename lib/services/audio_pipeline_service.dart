import 'package:flutter/services.dart';

import '../core/constants.dart';

/// Platform-channel failure raised by the native audio pipeline.
class AudioPipelineException implements Exception {
  const AudioPipelineException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Thin Dart wrapper over the `com.earlyecho/audio_pipeline` MethodChannel
/// implemented by the Kotlin pipeline.
///
/// Call order per screening: [requestPermission] → [startRecording] (capture
/// runs through the elicitation protocols) → [stopRecording] → [runPipeline].
/// Only low-dimensional numeric features ever cross the channel; audio never
/// leaves the device.
class AudioPipelineService {
  static const _channel = MethodChannel(
    EarlyEchoConstants.audioPipelineChannel,
  );
  static const _waveformChannel = EventChannel(
    '${EarlyEchoConstants.audioPipelineChannel}/waveform',
  );

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw AudioPipelineException(
        e.code,
        e.message ?? 'Audio pipeline call failed',
      );
    } on MissingPluginException {
      throw const AudioPipelineException(
        'ERR_UNAVAILABLE',
        'Native audio pipeline is unavailable on this platform',
      );
    }
  }

  /// Runtime RECORD_AUDIO grant. Throws [AudioPipelineException] with
  /// `ERR_PERMISSION` when the worker denies it.
  static Future<void> requestPermission() => _invoke('requestPermission');

  /// Starts capture; each filled rolling window is analysed natively.
  static Future<void> startRecording({required int childAgeMonths}) =>
      _invoke('startRecording', {'child_age_months': childAgeMonths});

  /// Ends capture. Safe to call when nothing is recording.
  static Future<void> stopRecording() => _invoke('stopRecording');

  /// Visual-only amplitude levels streamed while recording. These feed the
  /// on-screen waveform; they are never part of the feature vector.
  static Stream<double> get waveform => _waveformChannel
      .receiveBroadcastStream()
      .map((event) => (event as num).toDouble().clamp(0.0, 1.0));

  /// Aggregates the captured windows into the feature-vector contract.
  ///
  /// [protocolTimings] uses the `protocol`/`start_ms`/`end_ms` shape recorded
  /// by the elicitation flow. Returns the raw channel map; callers parse it
  /// with `SessionFeatures.fromChannelMap` and score via `ScoringEngine`.
  static Future<Map<String, dynamic>> runPipeline({
    required int childAgeMonths,
    List<Map<String, Object>> protocolTimings = const [],
  }) async {
    final result = await _invoke<dynamic>('runPipeline', {
      'child_age_months': childAgeMonths,
      'protocol_timings': protocolTimings,
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
