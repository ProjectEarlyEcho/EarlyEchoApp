import 'package:earlyecho/core/constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EarlyEchoConstants', () {
    test('exposes the native audio pipeline method channel', () {
      expect(
        EarlyEchoConstants.audioPipelineChannel,
        'com.earlyecho/audio_pipeline',
      );
    });

    test('defines the three elicitation protocol durations', () {
      expect(EarlyEchoConstants.rattleProtocolSeconds, 60);
      expect(EarlyEchoConstants.toyHideProtocolSeconds, 80);
      expect(EarlyEchoConstants.imitationProtocolSeconds, 60);
    });

    test('elicitation total matches the sum of protocol durations', () {
      final sum =
          EarlyEchoConstants.rattleProtocolSeconds +
          EarlyEchoConstants.toyHideProtocolSeconds +
          EarlyEchoConstants.imitationProtocolSeconds;
      expect(EarlyEchoConstants.elicitationTotalSeconds, sum);
      expect(EarlyEchoConstants.elicitationTotalSeconds, 200);
    });

    test('screens children between 12 and 60 months', () {
      expect(EarlyEchoConstants.minChildAgeMonths, 12);
      expect(EarlyEchoConstants.maxChildAgeMonths, 60);
    });

    test('captures 16 kHz mono audio in 30 ms VAD frames', () {
      expect(EarlyEchoConstants.audioSampleRateHz, 16000);
      expect(EarlyEchoConstants.audioChannels, 1);
      expect(EarlyEchoConstants.vadFrameSizeMs, 30);
      expect(EarlyEchoConstants.vadFrameSamples, 480);
    });
  });
}
