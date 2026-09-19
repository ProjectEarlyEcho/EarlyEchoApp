import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/video_pipeline_service.dart';
import 'app_ui.dart';

/// Live, local-only child-framing preview used during elicitation.
///
/// The texture comes directly from the native CameraX pipeline. When native
/// video is unavailable (including widget tests and non-Android platforms), a
/// neutral framing placeholder keeps the screening flow usable.
class VideoCapturePreview extends StatefulWidget {
  const VideoCapturePreview({
    required this.active,
    required this.locale,
    super.key,
  });

  final bool active;
  final Locale? locale;

  @override
  State<VideoCapturePreview> createState() => _VideoCapturePreviewState();
}

class _VideoCapturePreviewState extends State<VideoCapturePreview> {
  int? _textureId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final textureId = await VideoPipelineService.initializePreview();
      if (mounted) setState(() => _textureId = textureId);
    } on VideoPipelineException {
      // A camera is optional quality context and never blocks screening.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = widget.active && _textureId != null;
    return Semantics(
      label: AppStrings.tr(
        live ? 'el_video_live' : 'el_video_idle',
        widget.locale,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_textureId case final textureId?)
              Texture(textureId: textureId)
            else
              AppSurface(
                color: scheme.surfaceContainerHighest,
                borderColor: scheme.outlineVariant,
                child: Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    color: scheme.onSurfaceVariant,
                    size: 34,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.56),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      live
                          ? Icons.fiber_manual_record_rounded
                          : Icons.videocam_outlined,
                      color: live ? Colors.red.shade200 : Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      AppStrings.tr(
                        live ? 'el_video_live' : 'el_video_idle',
                        widget.locale,
                      ),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
