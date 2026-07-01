import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Space below the plot area for legend and view-mode controls.
const double kLiveFullscreenChartLegendReserve = 72;

/// Opens a fullscreen live chart route sharing the active notifiers.
Future<void> openLiveFullscreenChart(
  BuildContext context, {
  required ValueNotifier<List<ShotSample>> samplesNotifier,
  required ValueNotifier<List<ShotAnnotation>> annotationsNotifier,
  required ChartInteractionController interactionController,
  List<ShotSample> targetPressureSamples = const [],
  void Function(int elapsedMs)? onAnnotateAtElapsedMs,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => LiveFullscreenChartScreen(
        samplesNotifier: samplesNotifier,
        annotationsNotifier: annotationsNotifier,
        interactionController: interactionController,
        targetPressureSamples: targetPressureSamples,
        onAnnotateAtElapsedMs: onAnnotateAtElapsedMs,
      ),
    ),
  );
}

/// Fullscreen live chart for detailed inspection while brewing.
class LiveFullscreenChartScreen extends StatelessWidget {
  const LiveFullscreenChartScreen({
    required this.samplesNotifier,
    required this.annotationsNotifier,
    required this.interactionController,
    this.targetPressureSamples = const [],
    this.onAnnotateAtElapsedMs,
    super.key,
  });

  final ValueNotifier<List<ShotSample>> samplesNotifier;
  final ValueNotifier<List<ShotAnnotation>> annotationsNotifier;
  final ChartInteractionController interactionController;
  final List<ShotSample> targetPressureSamples;
  final void Function(int elapsedMs)? onAnnotateAtElapsedMs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('live_fullscreen_chart'),
      appBar: AppBar(
        title: const Text('Live chart'),
        leading: IconButton(
          key: const Key('live_fullscreen_close'),
          tooltip: 'Close fullscreen chart',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartHeight = (constraints.maxHeight -
                      kLiveFullscreenChartLegendReserve)
                  .clamp(200.0, 900.0);
              return DualCurveChart(
                key: const Key('live_fullscreen_dual_chart'),
                height: chartHeight,
                samplesNotifier: samplesNotifier,
                annotationsNotifier: annotationsNotifier,
                interactionController: interactionController,
                targetPressureSamples: targetPressureSamples,
                onAnnotateAtElapsedMs: onAnnotateAtElapsedMs,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Expand control shown above the embedded live chart.
class LiveFullscreenChartButton extends StatelessWidget {
  const LiveFullscreenChartButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        key: const Key('live_fullscreen_open'),
        tooltip: 'Fullscreen chart',
        onPressed: onPressed,
        icon: const Icon(Icons.fullscreen),
      ),
    );
  }
}