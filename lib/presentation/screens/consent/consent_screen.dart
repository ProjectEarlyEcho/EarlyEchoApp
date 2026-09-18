import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../services/consent_audio_service.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_ui.dart';

/// Step 3 of the screening flow — recorded parent consent.
///
/// Plays the bundled Hindi consent statement, then asks the worker to
/// confirm "माता-पिता ने सहमति दी". The confirm button stays disabled until
/// the audio has been played at least once, and no other affordance leads
/// forward — the consent gate. On confirm a timestamped row is written to
/// `consent_logs` (with `session_id` NULL; it is backfilled when the
/// session row is created), the timestamp + log id land on
/// [sessionProvider], and the flow advances to elicitation.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  ConsentAudioPlayer? _audio;
  bool _audioPlayed = false;
  bool _isPlaying = false;
  bool _confirming = false;
  String? _error;

  /// Lazily resolved so the field can also be stopped from [dispose]
  /// without reading providers during teardown.
  ConsentAudioPlayer get _player {
    final existing = _audio;
    if (existing != null) return existing;
    final created = ref.read(consentAudioPlayerProvider);
    _audio = created;
    return created;
  }

  Future<void> _toggleAudio() async {
    final audio = _player;
    if (_isPlaying) {
      await audio.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    setState(() {
      _isPlaying = true;
      _error = null;
    });
    try {
      await audio.play();
      if (mounted) setState(() => _audioPlayed = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppStrings.tr(
            'consent_audio_error',
            ref.read(appLocaleProvider),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _confirmConsent() async {
    if (_confirming) return;
    setState(() {
      _confirming = true;
      _error = null;
    });

    final profile = ref.read(sessionProvider).childProfile;
    final log = ConsentLog(
      id: const Uuid().v4(),
      sessionId: null,
      anganwadiId: profile?.anganwadiId,
      workerName: profile?.workerName,
      consentedAt: DateTime.now(),
    );

    try {
      await ref.read(sessionRepositoryProvider).logConsent(log);
    } catch (_) {
      if (mounted) {
        setState(() {
          _confirming = false;
          _error = AppStrings.tr(
            'consent_save_error',
            ref.read(appLocaleProvider),
          );
        });
      }
      return;
    }
    if (!mounted) return;

    ref
        .read(sessionProvider.notifier)
        .recordConsent(consentedAt: log.consentedAt, consentLogId: log.id);
    context.push('/elicitation');
  }

  @override
  void dispose() {
    unawaited(_audio?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_consent', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 3,
                total: 7,
                label: AppStrings.stepLabel(
                  3,
                  7,
                  AppStrings.tr('step3_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        AppSurface(
                          color: scheme.primaryContainer.withValues(alpha: 0.4),
                          borderColor: scheme.primaryContainer,
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            children: [
                              AppIconBadge(
                                icon: _isPlaying
                                    ? Icons.volume_up_rounded
                                    : Icons.record_voice_over_outlined,
                                color: scheme.primary,
                                size: 72,
                              ),
                              const SizedBox(height: 22),
                              Text(
                                AppStrings.tr('consent_heading', l10n),
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                AppStrings.tr('consent_body', l10n),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 22),
                              if (_isPlaying) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(height: 10),
                                Text(
                                  AppStrings.tr('consent_playing', l10n),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: _toggleAudio,
                                  icon: const Icon(Icons.stop_rounded),
                                  label: Text(
                                    AppStrings.tr('consent_stop', l10n),
                                  ),
                                ),
                              ] else
                                OutlinedButton.icon(
                                  onPressed: _toggleAudio,
                                  icon: Icon(
                                    _audioPlayed
                                        ? Icons.replay_rounded
                                        : Icons.play_arrow_rounded,
                                  ),
                                  label: Text(
                                    _audioPlayed
                                        ? AppStrings.tr('consent_replay', l10n)
                                        : AppStrings.tr('consent_play', l10n),
                                  ),
                                ),
                              if (_audioPlayed) ...[
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      AppStrings.tr('consent_played', l10n),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: scheme.primary),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          AppSurface(
                            color: scheme.errorContainer,
                            borderColor: scheme.error,
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: scheme.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.tr('consent_privacy', l10n),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _audioPlayed && !_confirming
                    ? _confirmConsent
                    : null,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(AppStrings.tr('consent_confirm', l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
