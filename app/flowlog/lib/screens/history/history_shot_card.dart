import 'dart:math' as math;

import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Summary card for a saved shot in the history list.
class HistoryShotCard extends StatelessWidget {
  const HistoryShotCard({
    super.key,
    required this.shot,
    this.onTap,
  });

  final Shot shot;

  /// Called when the card is tapped; defaults to [openShotDetail].
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Card(
      key: Key('history_shot_card_${shot.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap ?? () => openShotDetail(context, shot),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              _formatStartedAt(shot.startedAt),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SparklineChart(samples: shot.samples),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCell(
                    label: 'Peak P',
                    value: _formatPeakPressure(shot.samples),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Yield',
                    value: _formatYield(shot.yieldG),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'Taste',
                    value: _formatTasteScore(shot.tasteScore),
                    labelStyle: labelStyle,
                    valueStyle: valueStyle,
                  ),
                ),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  static double? peakPressureBar(Iterable<ShotSample> samples) {
    double? peak;
    for (final sample in samples) {
      final pressure = sample.pressureBar;
      if (pressure == null) {
        continue;
      }
      peak = peak == null ? pressure : math.max(peak!, pressure);
    }
    return peak;
  }

  static String _formatStartedAt(DateTime startedAt) {
    final local = startedAt.toLocal();
    final year = local.year;
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  static String _formatPeakPressure(List<ShotSample> samples) {
    final peak = peakPressureBar(samples);
    if (peak == null) {
      return '—';
    }
    return '${peak.toStringAsFixed(1)} bar';
  }

  static String _formatYield(double? yieldG) {
    if (yieldG == null) {
      return '—';
    }
    return '${yieldG.toStringAsFixed(1)} g';
  }

  static String _formatTasteScore(int? tasteScore) {
    if (tasteScore == null) {
      return '—';
    }
    return '$tasteScore/10';
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 2),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}