import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/audio_pipeline_service.dart';
import '../../../services/elicitation_audio_service.dart';
import '../../providers/locale_provider.dart';
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
  bool _captureStarted = false;

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
  ///
  /// The first protocol also opens microphone capture through the native
  /// pipeline; permission denial or capture failure never blocks the
  /// guided sequence — an empty capture simply yields an INCOMPLETE
  /// analysis with a retry prompt downstream.
  Future<void> _startProtocol() async {
    final state = ref.read(elicitationControllerProvider);
    if (state.running || state.completed) return;
    if (!_captureStarted) {
      try {
        await AudioPipelineService.requestPermission();
        await AudioPipelineService.startRecording(
          childAgeMonths:
              ref.read(sessionProvider).childProfile?.childAgeMonths ?? 0,
        );
        _captureStarted = true;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.tr(
                  'el_mic_unavailable',
                  ref.read(appLocaleProvider),
                ),
              ),
            ),
          );
        }
      }
    }
    ref.read(elicitationControllerProvider.notifier).start();
    try {
      await _player.playFor(state.current.key);
    } catch (_) {
      // Visual instruction stays on screen; audio failure never blocks.
    }
  }

  void _skipProtocol() {
    ref.read(elicitationControllerProvider.notifier).skip();
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
      // Capture teardown is best-effort — a missing mic or channel must
      // never surface as an unhandled async error here.
      unawaited(
        Future(() async {
          try {
            await AudioPipelineService.stopRecording();
          } catch (_) {}
        }),
      );
      ref.read(sessionProvider.notifier).recordProtocolTimings(next.timings);
      context.push('/processing');
    });

    final l10n = ref.watch(appLocaleProvider);
    final state = ref.watch(elicitationControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_elicitation', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 4,
                total: 7,
                label: AppStrings.stepLabel(
                  4,
                  7,
                  AppStrings.tr('step4_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.trf('el_protocol_progress', l10n, {
                        'n': '${state.protocolIndex + 1}',
                      }),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    AppStrings.trf('el_total_time', l10n, {
                      'elapsed': '${state.overallElapsedSeconds}',
                      'total': '${EarlyEchoConstants.elicitationTotalSeconds}',
                    }),
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
                  locale: l10n,
                  onReplayInstruction: state.running
                      ? _replayInstruction
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              _WaveformBars(
                active: state.running,
                seed: state.overallElapsedSeconds,
                locale: l10n,
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
                          AppStrings.tr('el_all_done', l10n),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ],
                  ),
                )
              else if (state.running)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        AppStrings.tr('el_recording_note', l10n),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _skipProtocol,
                      icon: const Icon(Icons.skip_next_rounded),
                      label: Text(AppStrings.tr('el_skip_activity', l10n)),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _skipProtocol,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: Text(AppStrings.tr('el_skip_activity', l10n)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _startProtocol,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          state.protocolIndex == 0
                              ? AppStrings.tr('el_start', l10n)
                              : AppStrings.tr('el_next_activity', l10n),
                        ),
                      ),
                    ),
                  ],
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
  const _WaveformBars({
    required this.active,
    required this.seed,
    required this.locale,
  });

  final bool active;
  final int seed;
  final Locale? locale;

  static const _barCount = 42;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: active
          ? AppStrings.tr('waveform_active', locale)
          : AppStrings.tr('waveform_idle', locale),
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
