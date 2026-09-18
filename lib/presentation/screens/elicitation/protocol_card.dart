import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../widgets/app_ui.dart';

/// One timed elicitation activity from the screening protocol.
///
/// [key] is the contract key recorded into `protocol_timings` and used to
/// pick the bundled Hindi instruction clip (`rattle`, `toy_hide`,
/// `imitate`). [title] and [instruction] are [AppStrings] keys resolved
/// into the worker's language at render time.
class ElicitationProtocol {
  const ElicitationProtocol({
    required this.key,
    required this.title,
    required this.instruction,
    required this.icon,
    required this.durationSeconds,
  });

  final String key;
  final String title;
  final String instruction;
  final IconData icon;
  final int durationSeconds;
}

/// The three sequential protocols — rattle, toy hide/reveal, "aaa"
/// imitation — in screening order. Durations come straight from
/// [EarlyEchoConstants] so the UI can never drift from the contract.
const elicitationProtocols = <ElicitationProtocol>[
  ElicitationProtocol(
    key: 'rattle',
    title: 'proto_rattle_title',
    instruction: 'proto_rattle_instruction',
    icon: Icons.toys_rounded,
    durationSeconds: EarlyEchoConstants.rattleProtocolSeconds,
  ),
  ElicitationProtocol(
    key: 'toy_hide',
    title: 'proto_toy_title',
    instruction: 'proto_toy_instruction',
    icon: Icons.visibility_rounded,
    durationSeconds: EarlyEchoConstants.toyHideProtocolSeconds,
  ),
  ElicitationProtocol(
    key: 'imitate',
    title: 'proto_imitate_title',
    instruction: 'proto_imitate_instruction',
    icon: Icons.record_voice_over_rounded,
    durationSeconds: EarlyEchoConstants.imitationProtocolSeconds,
  ),
];

/// Card for the currently active protocol — pictogram, the Hindi
/// instruction, an explicit countdown, and a status pill.
class ProtocolCard extends StatelessWidget {
  const ProtocolCard({
    super.key,
    required this.protocol,
    required this.elapsedSeconds,
    required this.running,
    required this.locale,
    this.onReplayInstruction,
  });

  final ElicitationProtocol protocol;
  final int elapsedSeconds;
  final bool running;

  /// The app's display language for the card's title, instruction and
  /// status labels.
  final Locale? locale;

  /// Replays the spoken Hindi instruction; hidden when null.
  final VoidCallback? onReplayInstruction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = (protocol.durationSeconds - elapsedSeconds).clamp(
      0,
      protocol.durationSeconds,
    );
    final progress = (elapsedSeconds / protocol.durationSeconds).clamp(
      0.0,
      1.0,
    );
    return AppSurface(
      color: scheme.surface,
      padding: const EdgeInsets.all(28),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIconBadge(
                  icon: protocol.icon,
                  color: scheme.secondary,
                  size: 70,
                ),
                const SizedBox(height: 18),
                Text(
                  AppStrings.tr(protocol.title, locale),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.tr(protocol.instruction, locale),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (onReplayInstruction != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onReplayInstruction,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(AppStrings.tr('proto_replay', locale)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          strokeCap: StrokeCap.round,
                          backgroundColor: scheme.primaryContainer,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$remaining',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          Text(
                            AppStrings.tr('proto_seconds_left', locale),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppPill(
                  label: running
                      ? AppStrings.tr('proto_recording', locale)
                      : AppStrings.tr('proto_ready', locale),
                  color: running ? const Color(0xFFC43D42) : scheme.primary,
                  icon: running
                      ? Icons.fiber_manual_record_rounded
                      : Icons.play_circle_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
