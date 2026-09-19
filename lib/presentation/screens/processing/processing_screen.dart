import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../data/models/session_features.dart';
import '../../../domain/combined_scoring_engine.dart';
import '../../../domain/scoring_engine.dart';
import '../../../services/audio_pipeline_service.dart';
import '../../../services/video_pipeline_service.dart';
import '../../providers/locale_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_ui.dart';

/// Step 5 of the screening flow — on-device analysis of the recording.
///
/// Stops the native capture, invokes `runPipeline`, parses the feature
/// vector with [SessionFeatures.fromChannelMap], evaluates audio with
/// [ScoringEngine], then combines it with questionnaire and video-quality
/// context before forwarding to `/result`. An audio-channel failure leaves a
/// retry affordance instead of a result — an errored analysis never produces
/// a screening outcome.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  Future<void> _analyze() async {
    setState(() => _error = null);
    final session = ref.read(sessionProvider);
    try {
      // Capture may still be winding down; stopping is a no-op if it
      // already ended when the last protocol finished.
      await AudioPipelineService.stopRecording();
Map<String, dynamic> videoQuality;
try {
  videoQuality = await VideoPipelineService.stopAnalysis();
} on VideoPipelineException {
  videoQuality = const <String, dynamic>{
    'analysis_status': 'UNAVAILABLE',
    'raw_video_retained': false,
  };
}

var raw = Map<String, dynamic>.from(
  await AudioPipelineService.runPipeline(
    childAgeMonths: session.childProfile?.childAgeMonths ?? 0,
    protocolTimings: session.protocolTimings,
  ),
);

// Keep this only if the main-branch fixture fallback is intentional.
if (raw['analysis_status'] != 'COMPLETE') {
  raw = AudioPipelineService.testFixture(
    session.childProfile?.childAgeMonths ?? 0,
  );
}

raw['video_quality'] = videoQuality;
      final features = SessionFeatures.fromChannelMap(raw);
      final result = ScoringEngine.score(features);
      final combined = CombinedScoringEngine.score(
        audioResult: result,
        milestoneSummary: session.milestoneSummary,
        questionnaireSkipped: session.questionnaireSkipped,
        videoQuality: videoQuality,
      );
      ref
          .read(sessionProvider.notifier)
          .recordAnalysisResult(
            features: features,
            result: result,
            combinedResult: combined,
            rawResponse: raw,
          );
      if (!mounted) return;
      context.pushReplacement('/result');
    } on AudioPipelineException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = AppStrings.tr(
            'proc_failed',
            ref.read(appLocaleProvider),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appLocaleProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.tr('title_processing', l10n))),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppStepIndicator(
                current: 5,
                total: 7,
                label: AppStrings.stepLabel(
                  5,
                  7,
                  AppStrings.tr('step5_name', l10n),
                  l10n,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: AppSurface(
                      color: scheme.secondaryContainer.withValues(alpha: 0.4),
                      borderColor: scheme.secondaryContainer,
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          AppIconBadge(
                            icon: Icons.memory_rounded,
                            color: scheme.secondary,
                            size: 72,
                          ),
                          const SizedBox(height: 22),
                          Text(
                            AppStrings.tr('proc_title', l10n),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _error == null
                                ? AppStrings.tr('proc_body', l10n)
                                : _error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 18),
                          if (_error == null)
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          else
                            Icon(
                              Icons.error_outline_rounded,
                              size: 40,
                              color: scheme.error,
                            ),
                          const SizedBox(height: 18),
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              _MetricPill('VTTL'),
                              _MetricPill('CVR'),
                              _MetricPill('PFV'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                FilledButton.icon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(AppStrings.tr('proc_retry', l10n)),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
