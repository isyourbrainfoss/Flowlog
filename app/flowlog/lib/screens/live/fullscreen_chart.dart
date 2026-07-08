import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/widgets/fullscreen_plot.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Opens a fullscreen live chart route sharing the active notifiers.
Future<void> openLiveFullscreenChart(
  BuildContext context, {
  required LiveShotController controller,
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
        controller: controller,
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
    required this.controller,
    required this.samplesNotifier,
    required this.annotationsNotifier,
    required this.interactionController,
    this.targetPressureSamples = const [],
    this.onAnnotateAtElapsedMs,
    super.key,
  });

  final LiveShotController controller;
  final ValueNotifier<List<ShotSample>> samplesNotifier;
  final ValueNotifier<List<ShotAnnotation>> annotationsNotifier;
  final ChartInteractionController interactionController;
  final List<ShotSample> targetPressureSamples;
  final void Function(int elapsedMs)? onAnnotateAtElapsedMs;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final controlsReserve = landscape ? 52.0 : 76.0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('live_fullscreen_chart'),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, controlsReserve),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxHeight,
                    child: DualCurveChart(
                      key: const Key('live_fullscreen_dual_chart'),
                      height: constraints.maxHeight,
                    samplesNotifier: samplesNotifier,
                    annotationsNotifier: annotationsNotifier,
                    interactionController: interactionController,
                    denseTimeAxis: true,
                    enableCrosshair: true,
                    targetPressureSamples: targetPressureSamples,
                    onAnnotateAtElapsedMs: onAnnotateAtElapsedMs,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: const Key('live_fullscreen_close'),
                  tooltip: 'Minimize chart',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.fullscreen_exit),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: landscape ? 4 : 8,
              child: LiveControls(
                controller: controller,
                prominent: !landscape,
                compact: landscape,
              ),
            ),
          ],
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
    return FullscreenPlotButton(
      onPressed: onPressed,
      buttonKey: const Key('live_fullscreen_open'),
    );
  }
}