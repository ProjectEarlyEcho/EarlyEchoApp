import 'dart:async';

import 'package:earlyecho/core/constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Canned native-pipeline payload for an INCOMPLETE analysis — exercises
/// the retry path and never touches session persistence.
final incompletePipelineResponse = <String, dynamic>{
  'analysis_status': 'INCOMPLETE',
  'quality_reasons': <String>[
    'At least 20 seconds of voiced audio is required.',
  ],
  'vttl_ms': 0.0,
  'pfv_std': 0.0,
  'pfv_z_score': 0.0,
  'cvr_ratio': 0.0,
  'child_age_months': 30,
  'audio_source_used': 'UNPROCESSED',
};

/// Canned COMPLETE payload that scores RED for a 30-month-old:
/// VTTL 1450 ms > 1000 ms and CVR 0.05 < 0.12 (the 24–36 m bucket);
/// PFV only flags from 36 months, so exactly two flags land.
final completeRedPipelineResponse = <String, dynamic>{
  'analysis_status': 'COMPLETE',
  'quality_reasons': <String>[],
  'vttl_ms': 1450.0,
  'pfv_std': 20.0,
  'pfv_z_score': 0.2,
  'cvr_ratio': 0.05,
  'vttl_flagged': true,
  'pfv_flagged': false,
  'cvr_flagged': true,
  'child_age_months': 30,
  'audio_source_used': 'UNPROCESSED',
  'frames_processed': 12800,
  'child_voiced_seconds': 36.0,
  'adult_voiced_seconds': 164.0,
  'transition_count': 18,
  'waveform': List<double>.filled(256, 0.1),
  'decision_trace': <Map<String, Object>>[],
};

/// Installs a mock handler on `com.earlyecho/audio_pipeline` so widget
/// tests exercise the real channel code paths off-device.
///
/// Every method succeeds; `runPipeline` returns [runPipelineResponse], or
/// never completes when it is null — useful for keeping the processing
/// screen mid-analysis in route tests.
void installMockPipelineChannel({Map<String, dynamic>? runPipelineResponse}) {
  const channel = MethodChannel(EarlyEchoConstants.audioPipelineChannel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(channel, (call) {
    if (call.method == 'runPipeline') {
      final response = runPipelineResponse;
      if (response == null) return Completer<dynamic>().future;
      return Future.value(response);
    }
    return Future.value(true);
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}
