import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../data/models/biomarker_result.dart';
import '../../../data/models/session_features.dart';
import '../../../data/models/session_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_ui.dart';
import 'biomarker_chip.dart';

/// Step 6 of the screening flow — the scored RED/YELLOW/GREEN result.
///
/// Reads the analysed [BiomarkerResult] + feature vector off
/// [sessionProvider], shows the risk banner, Hindi explanation and the
/// per-biomarker flags. A COMPLETE result is persisted to SQLite once and
/// queued for cloud sync; the consent audit row is linked to the new
/// session id. An INCOMPLETE analysis shows quality reasons and a retry
/// path — never a definitive result.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _persisted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _persistIfComplete());
  }

  Future<void> _persistIfComplete() async {
    if (_persisted) return;
    final session = ref.read(sessionProvider);
    final result = session.biomarkerResult;
    final features = session.features;
    final profile = session.childProfile;
    if (result == null || features == null || profile == null) return;
    if (result.incomplete) return;
    _persisted = true;

    final raw = session.pipelineResponse;
    final model = SessionModel(
      id: const Uuid().v4(),
      anganwadiId: profile.anganwadiId,
      workerName: profile.workerName,
      childName: profile.childName,
      childAgeMonths: profile.childAgeMonths,
      sessionDate: DateTime.now(),
      riskLevel: result.riskLevel,
      vttlMs: features.vttlMs,
      pfvStd: features.pfvStd,
      cvrRatio: features.cvrRatio,
      vttlFlagged: result.vttlFlagged,
      pfvFlagged: result.pfvFlagged,
      cvrFlagged: result.cvrFlagged,
      audioSourceUsed: raw['audio_source_used']?.toString() ?? 'UNKNOWN',
      stateCode: profile.stateCode,
      districtCode: profile.districtCode,
      decisionTrace: {
        'steps': raw['decision_trace'] ?? const [],
        'frames_processed': raw['frames_processed'] ?? 0,
        'transition_count': raw['transition_count'] ?? 0,
      },
    );

    final repository = ref.read(sessionRepositoryProvider);
    try {
      await repository.saveSession(model);
      final consentLogId = session.consentLogId;
      if (consentLogId != null) {
        await repository.attachConsentLogToSession(consentLogId, model.id);
      }
      await ref.read(syncProvider.notifier).refreshPendingCount();
    } catch (_) {
      // A persistence failure must never blank the result screen; the
      // session stays queued and the next launch re-attempts the write.
    }
  }

  void _goHome() {
    ref.read(sessionProvider.notifier).reset();
    context.go('/');
  }

  void _retry() {
    // Consent stands for a same-day rescreen; only the capture re-runs.
    context.pushReplacement('/elicitation');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocaleProvider);
    final session = ref.watch(sessionProvider);
    final result = session.biomarkerResult;
    final features = session.features;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_result', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 6,
                total: 7,
                label: AppStrings.stepLabel(
                  6,
                  7,
                  AppStrings.tr('step6_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: result == null || features == null
                      ? _NoResult(onHome: _goHome, l10n: l10n)
                      : result.incomplete
                      ? _IncompleteResult(
                          reasons: result.qualityReasons,
                          onRetry: _retry,
                          l10n: l10n,
                        )
                      : _ScoredResult(
                          result: result,
                          features: features,
                          onReferral: () => context.push('/referral'),
                          l10n: l10n,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _goHome,
                icon: const Icon(Icons.home_rounded),
                label: Text(AppStrings.tr('result_home', l10n)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.onHome, required this.l10n});

  final VoidCallback onHome;
  final Locale? l10n;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const AppIconBadge(icon: Icons.hourglass_empty_rounded, size: 64),
          const SizedBox(height: 18),
          Text(
            AppStrings.tr('result_none_title', l10n),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            AppStrings.tr('result_none_body', l10n),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _IncompleteResult extends StatelessWidget {
  const _IncompleteResult({
    required this.reasons,
    required this.onRetry,
    required this.l10n,
  });

  final List<String> reasons;
  final VoidCallback onRetry;
  final Locale? l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RiskBanner(
          color: EarlyEchoTheme.riskYellow,
          icon: Icons.replay_rounded,
          title: AppStrings.tr('result_incomplete_title', l10n),
          subtitle: AppStrings.tr('result_incomplete_body', l10n),
        ),
        const SizedBox(height: 16),
        if (reasons.isNotEmpty)
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.tr('result_quality', l10n),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final reason in reasons)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.replay_rounded),
          label: Text(AppStrings.tr('result_rescreen', l10n)),
        ),
      ],
    );
  }
}

class _ScoredResult extends StatelessWidget {
  const _ScoredResult({
    required this.result,
    required this.features,
    required this.onReferral,
    required this.l10n,
  });

  final BiomarkerResult result;
  final SessionFeatures features;
  final VoidCallback onReferral;
  final Locale? l10n;

  @override
  Widget build(BuildContext context) {
    final (color, icon, titleKey, explKey) = switch (result.riskLevel) {
      RiskLevel.green => (
        EarlyEchoTheme.riskGreen,
        Icons.check_circle_rounded,
        'result_green',
        'result_green_expl',
      ),
      RiskLevel.yellow => (
        EarlyEchoTheme.riskYellow,
        Icons.warning_amber_rounded,
        'result_yellow',
        'result_yellow_expl',
      ),
      RiskLevel.red => (
        EarlyEchoTheme.riskRed,
        Icons.error_rounded,
        'result_red',
        'result_red_expl',
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RiskBanner(
          color: color,
          icon: icon,
          title: AppStrings.tr(titleKey, l10n),
          subtitle: AppStrings.tr(explKey, l10n),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: BiomarkerChip(
                name: 'VTTL',
                value: '${features.vttlMs.toStringAsFixed(0)} ms',
                flagged: result.vttlFlagged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BiomarkerChip(
                name: 'CVR',
                value: features.cvrRatio.toStringAsFixed(3),
                flagged: result.cvrFlagged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: BiomarkerChip(
                name: 'PFV',
                value: '${features.pfvStd.toStringAsFixed(1)} ST',
                flagged: result.pfvFlagged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (result.riskLevel == RiskLevel.red)
          FilledButton.icon(
            onPressed: onReferral,
            icon: const Icon(Icons.description_outlined),
            label: Text(AppStrings.tr('result_referral', l10n)),
          ),
      ],
    );
  }
}

class _RiskBanner extends StatelessWidget {
  const _RiskBanner({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      color: color.withValues(alpha: 0.12),
      borderColor: color,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
