import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Direction of change for a live metric compared to the previous sample.
enum MetricTrend {
  up,
  down,
  neutral,
}

/// Display-ready snapshot for the live metrics row.
@immutable
class LiveMetrics {
  const LiveMetrics({
    this.pressureBar,
    this.flowGs,
    required this.elapsedMs,
    this.projectedYieldG,
    this.pressureTrend = MetricTrend.neutral,
    this.flowTrend = MetricTrend.neutral,
    this.elapsedTrend = MetricTrend.neutral,
    this.projectedYieldTrend = MetricTrend.neutral,
  });

  static const defaultTargetDurationMs = 30000;

  final double? pressureBar;
  final double? flowGs;
  final int elapsedMs;
  final double? projectedYieldG;
  final MetricTrend pressureTrend;
  final MetricTrend flowTrend;
  final MetricTrend elapsedTrend;
  final MetricTrend projectedYieldTrend;

  /// Builds metrics from the current [sample], optionally comparing to [previous].
  factory LiveMetrics.fromSamples({
    required ShotSample sample,
    ShotSample? previous,
    int targetDurationMs = defaultTargetDurationMs,
  }) {
    final history = <ShotSample>[
      if (previous != null) previous,
      sample,
    ];
    final computed = computeFlowRates(history);
    final current = _preferProvidedFlow(sample, computed.last);
    final prior =
        previous == null ? null : _preferProvidedFlow(previous, computed.first);

    final projectedYieldG = _projectedYield(
      weightG: current.weightG,
      flowGs: current.flowGs,
      elapsedMs: current.elapsedMs,
      targetDurationMs: targetDurationMs,
    );
    final previousProjectedYieldG = prior == null
        ? null
        : _projectedYield(
            weightG: prior.weightG,
            flowGs: prior.flowGs,
            elapsedMs: prior.elapsedMs,
            targetDurationMs: targetDurationMs,
          );

    return LiveMetrics(
      pressureBar: current.pressureBar,
      flowGs: current.flowGs,
      elapsedMs: current.elapsedMs,
      projectedYieldG: projectedYieldG,
      pressureTrend: _trend(current.pressureBar, prior?.pressureBar),
      flowTrend: _trend(current.flowGs, prior?.flowGs),
      elapsedTrend: _trend(
        current.elapsedMs.toDouble(),
        prior?.elapsedMs.toDouble(),
      ),
      projectedYieldTrend: _trend(projectedYieldG, previousProjectedYieldG),
    );
  }

  static double? _projectedYield({
    required double? weightG,
    required double? flowGs,
    required int elapsedMs,
    required int targetDurationMs,
  }) {
    if (weightG == null) {
      return null;
    }

    final remainingSec =
        (targetDurationMs - elapsedMs).clamp(0, targetDurationMs) / 1000.0;
    return weightG + (flowGs ?? 0) * remainingSec;
  }

  static ShotSample _preferProvidedFlow(ShotSample original, ShotSample computed) {
    if (original.flowGs != null) {
      return original;
    }
    return computed;
  }

  static MetricTrend _trend(num? current, num? previous) {
    if (current == null || previous == null) {
      return MetricTrend.neutral;
    }

    const epsilon = 0.01;
    final delta = current - previous;
    if (delta > epsilon) {
      return MetricTrend.up;
    }
    if (delta < -epsilon) {
      return MetricTrend.down;
    }
    return MetricTrend.neutral;
  }
}

/// Floating row of live shot metrics with trend arrows.
class LiveMetricsRow extends StatelessWidget {
  const LiveMetricsRow({
    super.key,
    this.metrics,
    this.sample,
    this.previousSample,
    this.targetDurationMs = LiveMetrics.defaultTargetDurationMs,
  }) : assert(
          metrics != null || sample != null,
          'Provide metrics or sample',
        );

  /// Below this width, metrics render in a 2×2 grid instead of one row.
  @visibleForTesting
  static const compactLayoutBreakpoint = 360.0;

  /// Pre-computed metrics (takes precedence over [sample]).
  final LiveMetrics? metrics;

  /// Latest shot sample; trends are derived from [previousSample].
  final ShotSample? sample;

  /// Prior sample for trend comparison.
  final ShotSample? previousSample;

  /// Shot length used to extrapolate [LiveMetrics.projectedYieldG].
  final int targetDurationMs;

  @override
  Widget build(BuildContext context) {
    final resolved = metrics ??
        LiveMetrics.fromSamples(
          sample: sample!,
          previous: previousSample,
          targetDurationMs: targetDurationMs,
        );

    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.titleMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final tiles = <Widget>[
      _MetricTile(
        label: 'Pressure',
        value: _formatPressure(resolved.pressureBar),
        trend: resolved.pressureTrend,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
      ),
      FlowStabilityPulse(
        isStable: isFlowStable(
          flowGs: resolved.flowGs,
          flowTrendIsNeutral: resolved.flowTrend == MetricTrend.neutral,
        ),
        child: _MetricTile(
          label: 'Flow',
          value: _formatFlow(resolved.flowGs),
          trend: resolved.flowTrend,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      ),
      _MetricTile(
        label: 'Elapsed',
        value: _formatElapsed(resolved.elapsedMs),
        trend: resolved.elapsedTrend,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
      ),
      _MetricTile(
        label: 'Proj. yield',
        value: _formatYield(resolved.projectedYieldG),
        trend: resolved.projectedYieldTrend,
        labelStyle: labelStyle,
        valueStyle: valueStyle,
      ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < compactLayoutBreakpoint) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 8),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: tiles[2]),
                      const SizedBox(width: 8),
                      Expanded(child: tiles[3]),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _formatPressure(double? bar) {
    if (bar == null) {
      return '—';
    }
    return '${bar.toStringAsFixed(1)} bar';
  }

  static String _formatFlow(double? flowGs) {
    if (flowGs == null) {
      return '—';
    }
    return '${flowGs.toStringAsFixed(1)} g/s';
  }

  static String _formatElapsed(int elapsedMs) {
    final totalSeconds = elapsedMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  static String _formatYield(double? grams) {
    if (grams == null) {
      return '—';
    }
    return '${grams.toStringAsFixed(1)} g';
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.trend,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final MetricTrend trend;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendColor = switch (trend) {
      MetricTrend.up => theme.colorScheme.primary,
      MetricTrend.down => theme.colorScheme.error,
      MetricTrend.neutral => theme.colorScheme.onSurfaceVariant,
    };
    final trendIcon = switch (trend) {
      MetricTrend.up => Icons.arrow_drop_up,
      MetricTrend.down => Icons.arrow_drop_down,
      MetricTrend.neutral => Icons.remove,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final showInlineTrend = maxWidth >= 56;
        final showLabel = maxWidth >= 24;

        final trendWidget = Icon(
          trendIcon,
          size: showInlineTrend ? 18 : 14,
          color: trendColor,
        );

        return Semantics(
          label: '$label $value',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabel)
                Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              if (showLabel) const SizedBox(height: 2),
              if (showInlineTrend)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: valueStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    trendWidget,
                  ],
                )
              else ...[
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: valueStyle,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
                Center(child: trendWidget),
              ],
            ],
          ),
        );
      },
    );
  }
}