import 'package:flutter/services.dart';

import '../core/constants.dart';

/// Platform-channel failure raised by the native, on-device video pipeline.
class VideoPipelineException implements Exception {
  const VideoPipelineException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

/// Thin Dart wrapper around the separate native video-quality pipeline.
///
/// This channel owns a live CameraX preview and transient ML analysis only.
/// It never asks the native layer to encode, save, upload, or return video
/// frames, facial landmarks, or pose landmarks.
class VideoPipelineService {
  static const _channel = MethodChannel(
    EarlyEchoConstants.videoPipelineChannel,
  );

  static Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw VideoPipelineException(
        e.code,
        e.message ?? 'Video pipeline call failed',
      );
    } on MissingPluginException {
      throw const VideoPipelineException(
        'ERR_UNAVAILABLE',
        'Native video pipeline is unavailable on this platform',
      );
    }
  }

  /// Requests the Android CAMERA runtime permission.
  static Future<void> requestPermission() => _invoke('requestPermission');

  /// Allocates a Flutter texture for the live preview without opening camera.
  static Future<int> initializePreview() async {
    final id = await _invoke<num>('initializePreview');
    if (id == null) {
      throw const VideoPipelineException(
        'ERR_PREVIEW',
        'Video preview could not be initialized',
      );
    }
    return id.toInt();
  }

  /// Opens the camera and begins bounded on-device frame analysis.
  static Future<void> startAnalysis() => _invoke('startAnalysis');

  /// Stops capture and returns only aggregated session-quality measurements.
  static Future<Map<String, dynamic>> stopAnalysis() async {
    final result = await _invoke<dynamic>('stopAnalysis');
    return Map<String, dynamic>.from(result as Map? ?? const {});
  }

  /// Releases the native texture if the screening route is abandoned early.
  static Future<void> disposePreview() => _invoke('disposePreview');
}
