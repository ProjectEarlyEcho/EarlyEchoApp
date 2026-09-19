import 'package:earlyecho/core/constants.dart';
import 'package:earlyecho/services/video_pipeline_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(EarlyEchoConstants.videoPipelineChannel);

  test(
    'video service requests, starts, and returns only a quality summary',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'initializePreview' => 41,
          'stopAnalysis' => <String, dynamic>{
            'analysis_status': 'AVAILABLE',
            'face_visible_ratio': 0.75,
            'raw_video_retained': false,
          },
          _ => true,
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await VideoPipelineService.requestPermission();
      expect(await VideoPipelineService.initializePreview(), 41);
      await VideoPipelineService.startAnalysis();
      final summary = await VideoPipelineService.stopAnalysis();
      await VideoPipelineService.disposePreview();

      expect(calls, [
        'requestPermission',
        'initializePreview',
        'startAnalysis',
        'stopAnalysis',
        'disposePreview',
      ]);
      expect(summary['analysis_status'], 'AVAILABLE');
      expect(summary['raw_video_retained'], isFalse);
      expect(summary.containsKey('frame'), isFalse);
    },
  );
}
