import 'package:flutter/material.dart';

/// Live pressure vs target: large digit + horizontal deviation bar.
///
/// Center (green) on the bar is the target. Left/right red = too low / high.
class LivePressureDeviationBar extends StatelessWidget {
  const LivePressureDeviationBar({
    required this.currentPressure,
    required this.targetPressure,
    this.range = 2.5, // ± range around target
    this.height = 10.0,
    this.showReadout = true,
    this.compact = false,
    super.key,
  });

  final double? currentPressure;
  final double? targetPressure;

  /// Deviation range shown on each side of target (in bar).
  final double range;

  final double height;

  /// When true, shows "Pressure" label and a large live bar digit above the bar.
  final bool showReadout;

  /// Denser layout for immersive brew.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final hasCurrent = currentPressure != null;
    final hasTarget = targetPressure != null;
    final current = currentPressure ?? 0.0;
    final target = targetPressure ?? 9.0;

    final deviation = hasTarget ? current - target : 0.0;
    final normalized = hasTarget
        ? ((deviation + range) / (2 * range)).clamp(0.0, 1.0)
        : (current / 12.0).clamp(0.0, 1.0);

    final isDeviating = hasTarget && hasCurrent && deviation.abs() > 0.5;
    final markerColor = !hasCurrent
        ? cs.outline
        : isDeviating
            ? Colors.red
            : Colors.black;

    final bar = SizedBox(
      key: const Key('live_pressure_deviation_bar'),
      height: height + 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: hasTarget
                  ? const LinearGradient(
                      colors: [
                        Colors.red,
                        Colors.orange,
                        Colors.green,
                        Colors.orange,
                        Colors.red,
                      ],
                      stops: [0.0, 0.35, 0.5, 0.65, 1.0],
                    )
                  : null,
              color: hasTarget ? null : cs.surfaceContainerHighest,
              border: Border.all(
                color: cs.outline.withValues(alpha: 0.3),
              ),
            ),
          ),
          if (!hasTarget)
            FractionallySizedBox(
              widthFactor: normalized,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(height / 2),
                  color: cs.primary,
                ),
              ),
            ),
          if (hasTarget) ...[
            Container(
              height: height,
              width: 2,
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Align(
              alignment: Alignment((normalized * 2 - 1).toDouble(), 0),
              child: Container(
                width: 3,
                height: height + 4,
                decoration: BoxDecoration(
                  color: markerColor,
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!showReadout) {
      return bar;
    }

    return Column(
      key: const Key('live_pressure_progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Pressure',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasCurrent ? '${current.toStringAsFixed(1)} bar' : '— bar',
                key: const Key('live_pressure_digit'),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: (compact
                        ? theme.textTheme.headlineSmall
                        : theme.textTheme.headlineMedium)
                    ?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  color: isDeviating ? Colors.red.shade700 : cs.onSurface,
                ),
              ),
            ),
            if (targetPressure != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/ ${targetPressure!.toStringAsFixed(1)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        bar,
      ],
    );
  }
}
