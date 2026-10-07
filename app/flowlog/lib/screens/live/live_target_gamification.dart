import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Typed view of [computeTargetGamification] for the stopped Live screen.
@immutable
class LiveTargetGamificationStats {
  const LiveTargetGamificationStats({
    this.closeness,
    this.maxStreakSec = 0,
    this.currentStreakSec = 0,
    this.penaltyCount = 0,
    this.score,
  });

  /// No target / not computed (brewing, idle, or no target curve).
  static const empty = LiveTargetGamificationStats();

  /// Computes stats for a stopped session against [targets].
  ///
  /// Skipped (returns [empty]) unless the session is stopped with samples and
  /// a target curve: the brew HUD does not show it, and the O(n) pass on
  /// every 50 ms notify would hitch the chart.
  factory LiveTargetGamificationStats.forSession({
    required ShotSessionState state,
    required List<ShotSample> samples,
    required List<ShotSample> targets,
  }) {
    final show =
        state == ShotSessionState.stopped &&
        samples.isNotEmpty &&
        targets.isNotEmpty;
    if (!show) {
      return empty;
    }
    final map = computeTargetGamification(samples, targets);
    return LiveTargetGamificationStats(
      closeness: map['closenessPercent'] as double?,
      maxStreakSec: map['maxStreakSeconds'] as int? ?? 0,
      currentStreakSec: map['currentStreakSeconds'] as int? ?? 0,
      penaltyCount: map['penaltyCount'] as int? ?? 0,
      score: map['score'] as double?,
    );
  }

  final double? closeness;
  final int maxStreakSec;
  final int currentStreakSec;
  final int penaltyCount;
  final double? score;
}

/// Compact gamification strip shown after a brew against a target curve.
///
/// Displays closeness %, current/max green streak, number of distinct
/// penalty periods, and score (less strict event-based penalties).
class LiveTargetGamification extends StatelessWidget {
  const LiveTargetGamification({super.key, required this.stats});

  final LiveTargetGamificationStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final closeness = stats.closeness;
    final score = stats.score;
    final maxStreakSec = stats.maxStreakSec;
    final currentStreakSec = stats.currentStreakSec;
    final penaltyCount = stats.penaltyCount;
    final hasTarget =
        closeness != null ||
        score != null ||
        maxStreakSec > 0 ||
        currentStreakSec > 0;

    if (!hasTarget) {
      return const SizedBox.shrink();
    }

    final closenessStr = closeness != null
        ? '${closeness.toStringAsFixed(0)}%'
        : '—';
    final scoreStr = score != null ? score.toStringAsFixed(0) : '—';
    final streakStr = currentStreakSec > 0
        ? '${currentStreakSec}s / ${maxStreakSec}s'
        : (maxStreakSec > 0 ? 'max ${maxStreakSec}s' : '—');

    final isGoodStreak = currentStreakSec >= 3;
    final streakColor = isGoodStreak
        ? Colors.green.shade700
        : theme.colorScheme.onSurfaceVariant;
    final hasPenalties = penaltyCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                _GamifPill(label: 'Close', value: closenessStr),
                _GamifPill(
                  label: 'Streak',
                  value: streakStr,
                  valueColor: streakColor,
                ),
                if (hasPenalties)
                  _GamifPill(
                    label: 'Penalties',
                    value: '$penaltyCount',
                    valueColor: theme.colorScheme.error,
                  ),
                _GamifPill(label: 'Score', value: scoreStr),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GamifPill extends StatelessWidget {
  const _GamifPill({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valueColor ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
