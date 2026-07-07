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
    final scheme = Theme.of(context).colorScheme;
    final durationMs = _chartDurationMs(widget.shot);

    return Scaffold(
      key: const Key('history_fullscreen_chart'),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxHeight,
                    child: DualCurveChart(
                      key: const Key('history_fullscreen_dual_chart'),
                      height: constraints.maxHeight,
                      samples: widget.shot.samples,
                      annotations: widget.shot.annotations,
                      maxDurationMs: durationMs,
                      interactionController: _interactionController,
                      enableCrosshair: true,
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
                  key: const Key('history_fullscreen_close'),
                  tooltip: 'Minimize chart',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.fullscreen_exit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _chartDurationMs(Shot shot) {
    if (shot.endedAt != null) {
      return shot.endedAt!.difference(shot.startedAt).inMilliseconds;
    }
    if (shot.samples.isEmpty) {
      return null;
    }
    return shot.samples.last.elapsedMs;
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
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        key: const Key('history_fullscreen_open'),
        tooltip: 'Fullscreen chart',
        onPressed: onPressed,
        icon: const Icon(Icons.fullscreen),
      ),
    );
  }
}