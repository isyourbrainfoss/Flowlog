import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pure check: has live weight reached the early-stop warn level?
bool shouldFireYieldWarn({
  required double? weightG,
  required double warnAtG,
  required double targetYieldG,
  required bool alreadyFired,
}) {
  if (alreadyFired || weightG == null) {
    return false;
  }
  if (warnAtG <= 0 || targetYieldG <= 0) {
    return false;
  }
  return weightG >= warnAtG;
}

/// Plays a short pleasant cue for the yield early-stop heads-up.
Future<void> playYieldWarnCue({
  Future<void> Function()? onSound,
  Future<void> Function()? onHaptic,
}) async {
  await (onSound ?? () => SystemSound.play(SystemSoundType.alert))();
  await (onHaptic ?? HapticFeedback.mediumImpact)();
}

/// Live cup weight with a fill bar toward the target yield.
///
/// Shows a large gram readout, progress toward [targetYieldG], a mark at the
/// early-stop [warnAtG], and an optional alert banner when near target.
class LiveYieldProgress extends StatelessWidget {
  const LiveYieldProgress({
    required this.weightG,
    required this.targetYieldG,
    required this.warnAtG,
    this.showWarnBanner = false,
    this.height = 12,
    super.key,
  });

  final double? weightG;
  final double targetYieldG;
  final double warnAtG;
  final bool showWarnBanner;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weight = weightG;
    final target = targetYieldG <= 0 ? 36.0 : targetYieldG;
    final warn = warnAtG.clamp(0.0, target);
    final progress = weight == null ? 0.0 : (weight / target).clamp(0.0, 1.0);
    final atWarn = weight != null && weight >= warn;
    final atTarget = weight != null && weight >= target;
    final fillColor = atTarget
        ? cs.tertiary
        : atWarn
            ? cs.secondary
            : cs.primary;

    return Column(
      key: const Key('live_yield_progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showWarnBanner) ...[
          Material(
            key: const Key('live_yield_warn_banner'),
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: cs.onSecondaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Near target — wind back now\n'
                      'Aim to finish near ${target.toStringAsFixed(0)} g',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Cup',
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              weight == null ? '— g' : '${weight.toStringAsFixed(1)} g',
              key: const Key('live_yield_weight_digit'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w700,
                color: atWarn ? cs.secondary : cs.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '/ ${target.toStringAsFixed(0)} g',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final warnX = (warn / target).clamp(0.0, 1.0) * width;

            return SizedBox(
              height: height + 8,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      color: cs.surfaceContainerHighest,
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(height / 2),
                        color: fillColor,
                      ),
                    ),
                  ),
                  // Early-stop mark
                  Positioned(
                    left: warnX.clamp(0.0, width - 2),
                    child: Container(
                      key: const Key('live_yield_warn_mark'),
                      width: 2,
                      height: height + 6,
                      color: cs.secondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(
              '0',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                'warn ${warn.toStringAsFixed(0)} g',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              target.toStringAsFixed(0),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
