import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../services/elicitation_audio_service.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';
import 'elicitation_controller.dart';
import 'protocol_card.dart';

/// Step 4 of the screening flow — the three timed elicitation protocols.
///
/// Walks the worker through rattle → toy hide/reveal → "aaa" imitation,
/// one [ProtocolCard] at a time. The worker taps to start each protocol;
/// [ElicitationController.tick] then counts down once per second (driven
/// by a single periodic timer) and auto-advances to the next card. When
/// the third protocol completes, the recorded `protocol_timings` land on
/// [sessionProvider] and the flow moves to `/processing`.
class ElicitationScreen extends ConsumerStatefulWidget {
  const ElicitationScreen({super.key});

  @override
  ConsumerState<ElicitationScreen> createState() => _ElicitationScreenState();
}

class _ElicitationScreenState extends ConsumerState<ElicitationScreen> {
  /// One periodic timer drives the countdown; [ElicitationController.tick]
  /// is a no-op while a protocol is idle, so it can fire unconditionally.
  Timer? _tickTimer;

  ElicitationAudioPlayer? _audio;

  /// Lazily resolved so the field can also be stopped from [dispose]
  /// without reading providers during teardown.
  ElicitationAudioPlayer get _player {
    final existing = _audio;
    if (existing != null) return existing;
    final created = ref.read(elicitationAudioPlayerProvider);
    _audio = created;
    return created;
  }

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(elicitationControllerProvider.notifier).tick();
    });
  }

  /// Starts the current protocol's countdown and plays its spoken Hindi
  /// instruction. Playback is best-effort — the on-screen instruction is
  /// the fallback when audio is unavailable.
  Future<void> _startProtocol() async {
    final state = ref.read(elicitationControllerProvider);
    if (state.running || state.completed) return;
    ref.read(elicitationControllerProvider.notifier).start();
    try {
      await _player.playFor(state.current.key);
    } catch (_) {
      // Visual instruction stays on screen; audio failure never blocks.
    }
  }

  Future<void> _replayInstruction() async {
    final key = ref.read(elicitationControllerProvider).current.key;
    try {
      await _player.playFor(key);
    } catch (_) {
      // Same tolerance as _startProtocol.
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    unawaited(_audio?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When the sequence completes, hand the §5.1 capture windows to the
    // session and move on to analysis.
    ref.listen<ElicitationState>(elicitationControllerProvider, (prev, next) {
      if (!next.completed || (prev?.completed ?? false)) return;
      _tickTimer?.cancel();
      ref.read(sessionProvider.notifier).recordProtocolTimings(next.timings);
      context.push('/processing');
    });

    final state = ref.watch(elicitationControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('ध्वनि प्रेरण')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppStepIndicator(
                current: 4,
                total: 7,
                label: 'चरण 4/7 • ध्वनि प्रेरण (Elicitation)',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'प्रोटोकॉल ${state.protocolIndex + 1}/3',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    'कुल समय: ${state.overallElapsedSeconds} / '
                    '~${EarlyEchoConstants.elicitationTotalSeconds} सेकंड',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value:
                    (state.overallElapsedSeconds /
                            EarlyEchoConstants.elicitationTotalSeconds)
                        .clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ProtocolCard(
                  protocol: state.current,
                  elapsedSeconds: state.elapsedSeconds,
                  running: state.running,
                  onReplayInstruction: state.running
                      ? _replayInstruction
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              _WaveformBars(
                active: state.running,
                seed: state.overallElapsedSeconds,
              ),
              const SizedBox(height: 14),
              if (state.completed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'सभी गतिविधियाँ पूर्ण — विश्लेषण की ओर बढ़ रहे हैं…',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                )
              else if (state.running)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'रिकॉर्डिंग चल रही है — गतिविधि जारी रखें, टाइमर अपने '
                    'आप आगे बढ़ेगा।',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: _startProtocol,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    state.protocolIndex == 0
                        ? 'रिकॉर्डिंग शुरू करें'
                        : 'अगली गतिविधि शुरू करें',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative waveform placeholder — real microphone levels land with the
/// native capture pipeline. Bar heights follow a sine curve seeded by the
/// elapsed seconds, so it animates once per tick without a perpetual
/// animation that would block tests.
class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.active, required this.seed});

  final bool active;
  final int seed;

  static const _barCount = 42;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: active ? 'रिकॉर्डिंग तरंग सक्रिय' : 'रिकॉर्डिंग तरंग रुकी हुई',
      child: AppSurface(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderColor: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barCount, (index) {
              final level = active
                  ? 0.12 +
                        0.88 * (0.5 + 0.5 * math.sin(seed * 2.4 + index * 0.55))
                  : 0.04;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  height: 4 + (level * 32),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(
                      alpha: active ? 0.85 : 0.28,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
