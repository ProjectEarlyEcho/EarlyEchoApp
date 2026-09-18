import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../widgets/app_ui.dart';

/// One timed elicitation activity from the screening protocol.
///
/// [key] is the contract key recorded into `protocol_timings` and used to
/// pick the bundled Hindi instruction clip (`rattle`, `toy_hide`,
/// `imitate`). [instruction] is the exact worker-facing Hindi prompt.
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
    title: 'रैटल',
    instruction: 'इस बच्चे को रैटल की आवाज़ सुनाएँ',
    icon: Icons.toys_rounded,
    durationSeconds: EarlyEchoConstants.rattleProtocolSeconds,
  ),
  ElicitationProtocol(
    key: 'toy_hide',
    title: 'खिलौना छुपाना',
    instruction: 'यह रहा! यह रहा खिलौना!',
    icon: Icons.visibility_rounded,
    durationSeconds: EarlyEchoConstants.toyHideProtocolSeconds,
  ),
  ElicitationProtocol(
    key: 'imitate',
    title: 'अनुकरण',
    instruction: 'आ... आ... आ...',
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
    this.onReplayInstruction,
  });

  final ElicitationProtocol protocol;
  final int elapsedSeconds;
  final bool running;

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
                  protocol.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  protocol.instruction,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (onReplayInstruction != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onReplayInstruction,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('निर्देश फिर सुनाएँ'),
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
                            'सेकंड शेष',
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
                      ? 'रिकॉर्डिंग चल रही है'
                      : 'शुरू करने को तैयार',
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
