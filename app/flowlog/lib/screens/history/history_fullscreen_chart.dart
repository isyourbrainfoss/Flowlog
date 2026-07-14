import 'package:flowlog/widgets/fullscreen_plot.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Opens a fullscreen chart for a saved shot with crosshair inspection.
Future<void> openHistoryFullscreenChart(
  BuildContext context, {
  required Shot shot,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => HistoryFullscreenChartScreen(shot: shot),
    ),
  );
}

/// Fullscreen saved-shot chart with tap-to-probe crosshair.
class HistoryFullscreenChartScreen extends StatefulWidget {
  const HistoryFullscreenChartScreen({
    required this.shot,
    super.key,
  });

  final Shot shot;

  @override
  State<HistoryFullscreenChartScreen> createState() =>
      _HistoryFullscreenChartScreenState();
}

class _HistoryFullscreenChartScreenState
    extends State<HistoryFullscreenChartScreen> {
  late final ChartInteractionController _interactionController;

  @override
  void initState() {
    super.initState();
    _interactionController = ChartInteractionController();
  }

  @override
  void dispose() {
    _interactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = _chartDurationMs(widget.shot);

    return FullscreenPlotScaffold(
      scaffoldKey: const Key('history_fullscreen_chart'),
      closeButtonKey: const Key('history_fullscreen_close'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: DualCurveChart(
              key: const Key('history_fullscreen_dual_chart'),
              height: constraints.maxHeight,
              samples: widget.shot.samples,
              annotations: widget.shot.annotations,
              targetPressureSamples: widget.shot.targetPressureSamples,
              maxDurationMs: durationMs,
              interactionController: _interactionController,
              enableCrosshair: true,
            ),
          );
        },
      ),
    );
  }

  static int? _chartDurationMs(Shot shot) {
    int? dur;
    if (shot.endedAt != null) {
      dur = shot.endedAt!.difference(shot.startedAt).inMilliseconds;
    } else if (shot.samples.isNotEmpty) {
      dur = shot.samples.last.elapsedMs;
    }
    for (final t in shot.targetPressureSamples) {
      dur = (dur ?? 0) > t.elapsedMs ? dur : t.elapsedMs;
    }
    return dur;
  }
}

/// Expand control shown above a saved-shot chart.
class HistoryFullscreenChartButton extends StatelessWidget {
  const HistoryFullscreenChartButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FullscreenPlotButton(
      onPressed: onPressed,
      buttonKey: const Key('history_fullscreen_open'),
    );
  }
}