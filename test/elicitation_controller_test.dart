import 'package:earlyecho/presentation/screens/elicitation/elicitation_controller.dart';
import 'package:earlyecho/presentation/screens/elicitation/protocol_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ElicitationController makeController() => ElicitationController();

  /// Simulates [seconds] of countdown by driving [ElicitationController.tick]
  /// directly — the same method the screen's periodic timer calls.
  void tickSeconds(ElicitationController controller, int seconds) {
    for (var i = 0; i < seconds; i++) {
      controller.tick();
    }
  }

  group('protocol sequence', () {
    test('starts idle on the rattle protocol', () {
      final state = makeController().state;

      expect(state.protocolIndex, 0);
      expect(state.current.key, 'rattle');
      expect(state.elapsedSeconds, 0);
      expect(state.remainingSeconds, 60);
      expect(state.running, isFalse);
      expect(state.completed, isFalse);
      expect(state.timings, isEmpty);
    });

    test('tick is a no-op before the worker taps start', () {
      final controller = makeController();
      tickSeconds(controller, 10);

      expect(controller.state.elapsedSeconds, 0);
      expect(controller.state.running, isFalse);
    });

    test('start begins the countdown; a second tap does not restart it', () {
      final controller = makeController();
      controller.start();
      tickSeconds(controller, 5);
      controller.start();
      tickSeconds(controller, 5);

      expect(controller.state.elapsedSeconds, 10);
      expect(controller.state.remainingSeconds, 50);
      expect(controller.state.running, isTrue);
    });

    test('countdown auto-advances rattle to toy_hide, then waits again', () {
      final controller = makeController();
      controller.start();
      tickSeconds(controller, 59);
      expect(controller.state.protocolIndex, 0);
      expect(controller.state.running, isTrue);

      controller.tick();
      final state = controller.state;
      expect(state.protocolIndex, 1);
      expect(state.current.key, 'toy_hide');
      expect(state.elapsedSeconds, 0);
      expect(state.remainingSeconds, 80);
      expect(state.running, isFalse);
      expect(state.completed, isFalse);
      expect(state.timings, [
        {'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000},
      ]);
    });

    test('protocol durations match the §3.3 contract (60/80/60)', () {
      expect(elicitationProtocols.map((p) => p.durationSeconds).toList(), [
        60,
        80,
        60,
      ]);
      expect(elicitationProtocols.map((p) => p.key).toList(), [
        'rattle',
        'toy_hide',
        'imitate',
      ]);
    });

    test('full run completes and records the §5.1 timings contract', () {
      final controller = makeController();

      controller.start();
      tickSeconds(controller, 60);
      controller.start();
      tickSeconds(controller, 80);
      controller.start();
      tickSeconds(controller, 60);

      final state = controller.state;
      expect(state.completed, isTrue);
      expect(state.running, isFalse);
      expect(state.timings, [
        {'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000},
        {'protocol': 'toy_hide', 'start_ms': 60000, 'end_ms': 140000},
        {'protocol': 'imitate', 'start_ms': 140000, 'end_ms': 200000},
      ]);
    });

    test('start and tick are inert after completion', () {
      final controller = makeController();
      controller.start();
      tickSeconds(controller, 60);
      controller.start();
      tickSeconds(controller, 80);
      controller.start();
      tickSeconds(controller, 60);

      controller.start();
      tickSeconds(controller, 30);
      expect(controller.state.completed, isTrue);
      expect(controller.state.running, isFalse);
      expect(controller.state.timings, hasLength(3));
    });

    test('overallElapsedSeconds accumulates across finished protocols', () {
      final controller = makeController();
      expect(controller.state.overallElapsedSeconds, 0);

      controller.start();
      tickSeconds(controller, 60);
      expect(controller.state.overallElapsedSeconds, 60);

      controller.start();
      tickSeconds(controller, 25);
      expect(controller.state.overallElapsedSeconds, 85);
    });
  });
}
