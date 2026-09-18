import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_ui.dart';

/// One biomarker reading on the result screen: value plus a
/// ✓ सामान्य / ⚠ चिन्हित status, colored like the risk banner.
class BiomarkerChip extends ConsumerWidget {
  const BiomarkerChip({
    super.key,
    required this.name,
    required this.value,
    required this.flagged,
  });

  final String name;
  final String value;
  final bool flagged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocaleProvider);
    final color = flagged ? EarlyEchoTheme.riskRed : EarlyEchoTheme.riskGreen;
    return AppSurface(
      color: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: color),
              ),
              const SizedBox(width: 6),
              Icon(
                flagged
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_rounded,
                size: 16,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            flagged
                ? AppStrings.tr('chip_flagged', l10n)
                : AppStrings.tr('chip_normal', l10n),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
