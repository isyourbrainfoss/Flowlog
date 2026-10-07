import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/live_pressure_bar.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Formats brew elapsed time as `m:ss` for the brew HUD.
String formatBrewElapsed(int? elapsedMs) {
  final ms = elapsedMs ?? 0;
  final totalSec = (ms / 1000).floor();
  final minutes = totalSec ~/ 60;
  final seconds = totalSec % 60;
  return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Formats live flow for the brew HUD (`— g/s` when unknown).
String formatBrewFlow(double? flowGs) {
  if (flowGs == null) {
    return '— g/s';
  }
  return '${flowGs.toStringAsFixed(1)} g/s';
}

/// Immersive high-focus layout while a brew is active (shell hides tabs).
///
/// Only the plot, live digits, cup/pressure bars, and the stop control.
class LiveBrewHud extends StatelessWidget {
  const LiveBrewHud({
    super.key,
    required this.controller,
    required this.samples,
    required this.latestSample,
    required this.fallbackChartHeight,
    required this.samplesNotifier,
    required this.annotationsNotifier,
    required this.interactionController,
    required this.targetPressureSamples,
    required this.liveWeightG,
    required this.targetYieldG,
    required this.warnAtG,
    required this.showYieldWarnBanner,
    required this.weightHealth,
    required this.targetPressure,
    required this.onRearmWeight,
  });

  final LiveShotController controller;
  final List<ShotSample> samples;
  final ShotSample? latestSample;

  /// Chart height when the layout gives the plot unbounded height.
  final double fallbackChartHeight;
  final ValueNotifier<List<ShotSample>> samplesNotifier;
  final ValueNotifier<List<ShotAnnotation>> annotationsNotifier;
  final ChartInteractionController interactionController;
  final List<ShotSample> targetPressureSamples;

  /// Last known cup weight when the newest sample has none.
  final double? liveWeightG;
  final double targetYieldG;
  final double warnAtG;
  final bool showYieldWarnBanner;
  final WeightStreamHealth weightHealth;
  final double? targetPressure;
  final VoidCallback onRearmWeight;

  @override
  Widget build(BuildContext context) {
    final digitStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w700,
    );
    return Column(
      key: const ValueKey('live-brew-layout'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: LayoutBuilder(
              builder: (context, chartConstraints) {
                final h = chartConstraints.maxHeight.isFinite
                    ? chartConstraints.maxHeight
                    : fallbackChartHeight;
                return DualCurveChart(
                  height: h,
                  samplesNotifier: samplesNotifier,
                  annotationsNotifier: annotationsNotifier,
                  interactionController: interactionController,
                  denseTimeAxis: true,
                  targetPressureSamples: targetPressureSamples,
                );
              },
            ),
          ),
        ),
        Material(
          elevation: 2,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LiveYieldProgress(
                    weightG: latestSample?.weightG ?? liveWeightG,
                    targetYieldG: targetYieldG,
                    warnAtG: warnAtG,
                    showWarnBanner: showYieldWarnBanner,
                    compact: true,
                    height: 10,
                    weightHealth: weightHealth,
                    onRearmWeight: onRearmWeight,
                  ),
                  const SizedBox(height: 6),
                  LivePressureDeviationBar(
                    currentPressure: latestSample?.pressureBar,
                    targetPressure: targetPressure,
                    compact: true,
                    height: 10,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatBrewElapsed(latestSample?.elapsedMs),
                          key: const Key('live_elapsed_digit'),
                          textAlign: TextAlign.center,
                          style: digitStyle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          formatBrewFlow(latestFlowGs(samples)),
                          key: const Key('live_flow_digit'),
                          textAlign: TextAlign.center,
                          style: digitStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LiveControls(
                    controller: controller,
                    prominent: true,
                    compact: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
