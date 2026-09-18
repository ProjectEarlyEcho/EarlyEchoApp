import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'protocol_card.dart';

/// Snapshot of the guided elicitation sequence.
///
/// The worker taps to start each protocol; [tick] then counts down one
/// second at a time until the protocol's duration elapses, at which point
/// the sequence auto-advances to the next card (idle again) — or marks
/// [completed] after the third.
class ElicitationState {
  const ElicitationState({
    this.protocolIndex = 0,
    this.elapsedSeconds = 0,
    this.running = false,
    this.completed = false,
    this.timings = const [],
  });

  /// Index into [elicitationProtocols] (0 = rattle, 1 = toy hide, 2 = imitate).
  final int protocolIndex;

  /// Seconds counted down within the current protocol.
  final int elapsedSeconds;

  /// The countdown is actively ticking for the current protocol.
  final bool running;

  /// All three protocols have run to completion.
  final bool completed;

  /// §5.1 `protocol_timings` entries for finished protocols —
  /// `[{'protocol': 'rattle', 'start_ms': 0, 'end_ms': 60000}, ...]` with
  /// cumulative millisecond offsets from the start of the sequence.
  final List<Map<String, Object>> timings;

  ElicitationProtocol get current => elicitationProtocols[protocolIndex];

  /// Seconds left on the current protocol's countdown.
  int get remainingSeconds => (current.durationSeconds - elapsedSeconds).clamp(
    0,
    current.durationSeconds,
  );

  /// Total seconds elapsed across the whole sequence, used for the
  /// overall progress bar (~200 s at full duration).
  int get overallElapsedSeconds =>
      _offsetSeconds(protocolIndex) + elapsedSeconds;

  /// Planned start offset (seconds) of the protocol at [index].
  static int _offsetSeconds(int index) {
    var total = 0;
    for (var i = 0; i < index; i++) {
      total += elicitationProtocols[i].durationSeconds;
    }
    return total;
  }

  ElicitationState copyWith({
    int? protocolIndex,
    int? elapsedSeconds,
    bool? running,
    bool? completed,
    List<Map<String, Object>>? timings,
  }) {
    return ElicitationState(
      protocolIndex: protocolIndex ?? this.protocolIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      running: running ?? this.running,
      completed: completed ?? this.completed,
      timings: timings ?? this.timings,
    );
  }
}

/// Sequencing/countdown logic for the three timed protocols.
///
/// Holds no timers itself: the widget drives [tick] from a periodic
/// one-second timer, so tests can simulate the entire countdown by calling
/// [tick] directly — no wall-clock waits needed.
class ElicitationController extends StateNotifier<ElicitationState> {
  ElicitationController() : super(const ElicitationState());

  /// Worker tapped "start" for the current protocol. Ignored while a
  /// countdown is already running or the sequence is complete.
  void start() {
    if (state.running || state.completed) return;
    state = state.copyWith(running: true);
  }

  /// One second of countdown. No-ops while idle so the driver timer can
  /// fire unconditionally.
  void tick() {
    if (!state.running || state.completed) return;
    final protocol = state.current;
    final elapsed = state.elapsedSeconds + 1;
    if (elapsed < protocol.durationSeconds) {
      state = state.copyWith(elapsedSeconds: elapsed);
      return;
    }

    // Protocol finished — stamp its contract window (cumulative offsets,
    // e.g. toy_hide runs 60000–140000 ms) and move on.
    final startMs = ElicitationState._offsetSeconds(state.protocolIndex) * 1000;
    final timings = [
      ...state.timings,
      <String, Object>{
        'protocol': protocol.key,
        'start_ms': startMs,
        'end_ms': startMs + protocol.durationSeconds * 1000,
      },
    ];

    if (state.protocolIndex >= elicitationProtocols.length - 1) {
      state = state.copyWith(
        elapsedSeconds: protocol.durationSeconds,
        running: false,
        completed: true,
        timings: timings,
      );
    } else {
      state = state.copyWith(
        protocolIndex: state.protocolIndex + 1,
        elapsedSeconds: 0,
        running: false,
        timings: timings,
      );
    }
  }
}

/// Per-screen controller; auto-disposed so revisiting the route restarts
/// the guided sequence cleanly.
final elicitationControllerProvider =
    StateNotifierProvider.autoDispose<ElicitationController, ElicitationState>(
      (ref) => ElicitationController(),
    );
