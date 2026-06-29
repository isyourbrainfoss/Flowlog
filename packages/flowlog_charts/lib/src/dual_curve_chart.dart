import 'dart:math' as math;
import 'dart:ui' as ui;

import 'chart_interaction.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Coffee-themed chart colors aligned with [FlowlogColors] in the app theme.
abstract final class FlowlogChartColors {
  static const pressureLow = Color(0xFF6B9E5A);
  static const pressureHigh = Color(0xFFE8A54B);
  static const pressureLine = Color(0xFFD4923A);

  static const weightLine = Color(0xFF5B8DB8);
  static const flowLine = Color(0xFF4ECDC4);

  static const grid = Color(0xFF8A7B6E);
  static const axisLabel = Color(0xFFD4C9BC);
  static const background = Color(0xFF241C16);
}

/// Live dual-axis chart for espresso pressure, weight, and flow.
///
/// Provide either a static [samples] list or a live [samplesNotifier] stream.
/// When [enableInteraction] is true (default), supports pinch/zoom, pan, and
/// swipe (or [ChartInteractionController.setViewMode]) for overlay/split/flow-only.
class DualCurveChart extends StatefulWidget {
  const DualCurveChart({
    super.key,
    this.samples,
    this.samplesNotifier,
    this.height = 220,
    this.maxDurationMs,
    this.showPressure = true,
    this.showWeight = true,
    this.showFlow = true,
    this.backgroundColor = FlowlogChartColors.background,
    this.enableInteraction = true,
    this.interactionController,
    this.initialViewMode = ChartViewMode.overlay,
  }) : assert(
          samples != null || samplesNotifier != null,
          'Provide samples or samplesNotifier',
        );

  /// Static sample list (e.g. replayed or saved shot).
  final List<ShotSample>? samples;

  /// Live sample stream; rebuilds when the notifier changes.
  final ValueNotifier<List<ShotSample>>? samplesNotifier;

  /// Chart height in logical pixels.
  final double height;

  /// Optional fixed X-axis duration; defaults to latest sample time.
  final int? maxDurationMs;

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
  final Color backgroundColor;

  /// Pinch/zoom, pan, and swipe view-mode gestures.
  final bool enableInteraction;

  /// Optional external controller for view mode and viewport.
  final ChartInteractionController? interactionController;

  /// Initial layout when no external controller is supplied.
  final ChartViewMode initialViewMode;

  @override
  State<DualCurveChart> createState() => _DualCurveChartState();
}

class _DualCurveChartState extends State<DualCurveChart> {
  late ChartInteractionController _interactionController;
  bool _ownsInteractionController = false;

  @override
  void initState() {
    super.initState();
    _ownsInteractionController = widget.interactionController == null;
    _interactionController = widget.interactionController ??
        ChartInteractionController(viewMode: widget.initialViewMode);
    _interactionController.addListener(_onInteractionChanged);
  }

  @override
  void didUpdateWidget(covariant DualCurveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionController != widget.interactionController) {
      _interactionController.removeListener(_onInteractionChanged);
      if (_ownsInteractionController) {
        _interactionController.dispose();
      }
      _ownsInteractionController = widget.interactionController == null;
      _interactionController = widget.interactionController ??
          ChartInteractionController(viewMode: widget.initialViewMode);
      _interactionController.addListener(_onInteractionChanged);
    }
  }

  @override
  void dispose() {
    _interactionController.removeListener(_onInteractionChanged);
    if (_ownsInteractionController) {
      _interactionController.dispose();
    }
    super.dispose();
  }

  void _onInteractionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.samplesNotifier != null) {
      return ValueListenableBuilder<List<ShotSample>>(
        valueListenable: widget.samplesNotifier!,
        builder: (context, value, _) => _buildChart(value),
      );
    }
    return _buildChart(widget.samples!);
  }

  Widget _buildChart(List<ShotSample> rawSamples) {
    final prepared = _prepareSamples(rawSamples);
    final totalDurationMs = _resolveTotalDurationMs(prepared);

    if (widget.enableInteraction) {
      _interactionController.syncTotalDuration(
        totalDurationMs,
        followEndWhenZoomedOut: widget.samplesNotifier != null,
      );
    }

    final viewMode = widget.enableInteraction
        ? _interactionController.viewMode
        : ChartViewMode.overlay;
    final viewport = widget.enableInteraction
        ? _interactionController.viewport
        : ChartViewport(totalDurationMs: totalDurationMs);

    final visibility = _visibilityForMode(
      viewMode: viewMode,
      showPressure: widget.showPressure,
      showWeight: widget.showWeight,
      showFlow: widget.showFlow,
    );

    return RepaintBoundary(
      child: Semantics(
        label: _semanticsLabel(viewMode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plotWidth = _plotWidth(constraints.maxWidth);
                  final chartBody = viewMode == ChartViewMode.split
                      ? _SplitCharts(
                          samples: prepared,
                          maxDurationMs: widget.maxDurationMs,
                          viewport: viewport,
                          visibility: visibility,
                          backgroundColor: widget.backgroundColor,
                        )
                      : _OverlayChart(
                          samples: prepared,
                          maxDurationMs: widget.maxDurationMs,
                          viewport: viewport,
                          visibility: visibility,
                          backgroundColor: widget.backgroundColor,
                        );

                  if (!widget.enableInteraction) {
                    return chartBody;
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _interactionController.onScaleStart,
                    onScaleUpdate: (details) => _interactionController
                        .onScaleUpdate(details, plotWidth),
                    onScaleEnd: _interactionController.onScaleEnd,
                    child: chartBody,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _Legend(
              showPressure: visibility.showPressure,
              showWeight: visibility.showWeight,
              showFlow: visibility.showFlow,
              viewMode: viewMode,
            ),
          ],
        ),
      ),
    );
  }

  static List<ShotSample> _prepareSamples(List<ShotSample> raw) {
    if (raw.isEmpty) {
      return raw;
    }

    final hasFlow = raw.any((sample) => sample.flowGs != null);
    if (hasFlow) {
      return List<ShotSample>.from(raw);
    }

    return computeFlowRates(raw);
  }

  int _resolveTotalDurationMs(List<ShotSample> samples) {
    var total = widget.maxDurationMs ?? 30000;
    for (final sample in samples) {
      total = math.max(total, sample.elapsedMs);
    }
    if (widget.maxDurationMs != null) {
      total = math.max(total, widget.maxDurationMs!);
    }
    return math.max(total, 1);
  }

  static double _plotWidth(double width) {
    return math.max(
      1,
      width - DualCurveChartPainter.leftPad - DualCurveChartPainter.rightPad,
    );
  }

  static String _semanticsLabel(ChartViewMode mode) {
    return switch (mode) {
      ChartViewMode.overlay => 'Espresso shot chart, overlay view',
      ChartViewMode.split => 'Espresso shot chart, split view',
      ChartViewMode.flowOnly => 'Espresso shot chart, flow only',
    };
  }
}

class _SeriesVisibility {
  const _SeriesVisibility({
    required this.showPressure,
    required this.showWeight,
    required this.showFlow,
  });

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
}

_SeriesVisibility _visibilityForMode({
  required ChartViewMode viewMode,
  required bool showPressure,
  required bool showWeight,
  required bool showFlow,
}) {
  return switch (viewMode) {
    ChartViewMode.overlay => _SeriesVisibility(
        showPressure: showPressure,
        showWeight: showWeight,
        showFlow: showFlow,
      ),
    ChartViewMode.split => _SeriesVisibility(
        showPressure: showPressure,
        showWeight: showWeight,
        showFlow: showFlow,
      ),
    ChartViewMode.flowOnly => _SeriesVisibility(
        showPressure: false,
        showWeight: false,
        showFlow: showFlow,
      ),
  };
}

class _OverlayChart extends StatelessWidget {
  const _OverlayChart({
    required this.samples,
    required this.maxDurationMs,
    required this.viewport,
    required this.visibility,
    required this.backgroundColor,
  });

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final _SeriesVisibility visibility;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DualCurveChartPainter(
        samples: samples,
        maxDurationMs: maxDurationMs,
        viewport: viewport,
        showPressure: visibility.showPressure,
        showWeight: visibility.showWeight,
        showFlow: visibility.showFlow,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

class _SplitCharts extends StatelessWidget {
  const _SplitCharts({
    required this.samples,
    required this.maxDurationMs,
    required this.viewport,
    required this.visibility,
    required this.backgroundColor,
  });

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final _SeriesVisibility visibility;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[];
    if (visibility.showPressure) {
      panels.add(
        _SplitPanel(
          label: 'Pressure',
          samples: samples,
          maxDurationMs: maxDurationMs,
          viewport: viewport,
          backgroundColor: backgroundColor,
          painter: DualCurveChartPainter(
            samples: samples,
            maxDurationMs: maxDurationMs,
            viewport: viewport,
            showPressure: true,
            showWeight: false,
            showFlow: false,
            backgroundColor: backgroundColor,
            compact: true,
            axisUnitLabel: 'bar',
          ),
        ),
      );
    }
    if (visibility.showWeight) {
      panels.add(
        _SplitPanel(
          label: 'Weight',
          samples: samples,
          maxDurationMs: maxDurationMs,
          viewport: viewport,
          backgroundColor: backgroundColor,
          painter: DualCurveChartPainter(
            samples: samples,
            maxDurationMs: maxDurationMs,
            viewport: viewport,
            showPressure: false,
            showWeight: true,
            showFlow: false,
            backgroundColor: backgroundColor,
            compact: true,
            axisUnitLabel: 'g',
          ),
        ),
      );
    }
    if (visibility.showFlow) {
      panels.add(
        _SplitPanel(
          label: 'Flow',
          samples: samples,
          maxDurationMs: maxDurationMs,
          viewport: viewport,
          backgroundColor: backgroundColor,
          painter: DualCurveChartPainter(
            samples: samples,
            maxDurationMs: maxDurationMs,
            viewport: viewport,
            showPressure: false,
            showWeight: false,
            showFlow: true,
            backgroundColor: backgroundColor,
            compact: true,
            axisUnitLabel: 'g/s',
          ),
        ),
      );
    }

    if (panels.isEmpty) {
      return CustomPaint(
        painter: DualCurveChartPainter(
          samples: samples,
          maxDurationMs: maxDurationMs,
          viewport: viewport,
          backgroundColor: backgroundColor,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < panels.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Expanded(child: panels[i]),
        ],
      ],
    );
  }
}

class _SplitPanel extends StatelessWidget {
  const _SplitPanel({
    required this.label,
    required this.samples,
    required this.maxDurationMs,
    required this.viewport,
    required this.backgroundColor,
    required this.painter,
  });

  final String label;
  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final Color backgroundColor;
  final DualCurveChartPainter painter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FlowlogChartColors.axisLabel,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: CustomPaint(painter: painter),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.showPressure,
    required this.showWeight,
    required this.showFlow,
    required this.viewMode,
  });

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
  final ChartViewMode viewMode;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (showPressure) {
      items.add(
        _LegendItem(
          color: FlowlogChartColors.pressureLine,
          label: 'Pressure',
        ),
      );
    }
    if (showWeight) {
      items.add(
        _LegendItem(color: FlowlogChartColors.weightLine, label: 'Weight'),
      );
    }
    if (showFlow) {
      items.add(_LegendItem(color: FlowlogChartColors.flowLine, label: 'Flow'));
    }

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: items,
          ),
        ),
        Text(
          _viewModeLabel(viewMode),
          style: const TextStyle(
            color: FlowlogChartColors.axisLabel,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  static String _viewModeLabel(ChartViewMode mode) {
    return switch (mode) {
      ChartViewMode.overlay => 'Overlay',
      ChartViewMode.split => 'Split',
      ChartViewMode.flowOnly => 'Flow only',
    };
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: FlowlogChartColors.axisLabel,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Paints pressure, weight, and flow curves over elapsed shot time.
class DualCurveChartPainter extends CustomPainter {
  DualCurveChartPainter({
    required this.samples,
    this.maxDurationMs,
    ChartViewport? viewport,
    this.showPressure = true,
    this.showWeight = true,
    this.showFlow = true,
    this.backgroundColor = FlowlogChartColors.background,
    this.compact = false,
    this.axisUnitLabel,
  }) : viewport = viewport ??
            ChartViewport(
              totalDurationMs: math.max(
                1,
                maxDurationMs ?? _fallbackDuration(samples),
              ),
            );

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
  final Color backgroundColor;
  final bool compact;
  final String? axisUnitLabel;

  static const leftPad = 40.0;
  static const rightPad = 40.0;
  static const topPad = 12.0;
  static const bottomPad = 24.0;

  static int _fallbackDuration(List<ShotSample> samples) {
    if (samples.isEmpty) {
      return 30000;
    }
    return samples.last.elapsedMs;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(1, size.width - leftPad - rightPad),
      math.max(1, size.height - topPad - bottomPad),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    _drawGrid(canvas, plotRect);

    if (samples.isEmpty) {
      _drawEmptyLabel(canvas, plotRect);
      return;
    }

    final scales = _ChartScales.fromSamples(
      samples,
      maxDurationMs: maxDurationMs,
      viewport: viewport,
    );

    _drawAxes(canvas, plotRect, scales);

    if (showPressure) {
      _drawPressure(canvas, plotRect, scales);
    }
    if (showWeight) {
      _drawSeries(
        canvas,
        plotRect,
        scales,
        valueSelector: (sample) => sample.weightG,
        maxValue: scales.weightMax,
        color: FlowlogChartColors.weightLine,
        strokeWidth: 2,
      );
    }
    if (showFlow) {
      _drawSeries(
        canvas,
        plotRect,
        scales,
        valueSelector: (sample) => sample.flowGs,
        maxValue: scales.flowMax,
        color: FlowlogChartColors.flowLine,
        strokeWidth: 1.5,
        dashed: true,
      );
    }
  }

  void _drawGrid(Canvas canvas, Rect plotRect) {
    final gridPaint = Paint()
      ..color = FlowlogChartColors.grid.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final horizontalLines = compact ? 2 : 4;
    for (var i = 0; i <= horizontalLines; i++) {
      final y = plotRect.top + (plotRect.height / horizontalLines) * i;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
    }

    const verticalLines = 5;
    for (var i = 0; i <= verticalLines; i++) {
      final x = plotRect.left + (plotRect.width / verticalLines) * i;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Rect plotRect, _ChartScales scales) {
    final textStyle = TextStyle(
      color: FlowlogChartColors.axisLabel,
      fontSize: compact ? 9 : 10,
    );

    if (compact) {
      final unit = axisUnitLabel ?? 'bar';
      _drawAxisLabel(
        canvas,
        unit,
        Offset(4, plotRect.top),
        textStyle,
      );
    } else {
      _drawAxisLabel(
        canvas,
        'bar',
        Offset(4, plotRect.top),
        textStyle,
      );
      _drawAxisLabel(
        canvas,
        'g',
        Offset(plotRect.right + 6, plotRect.top),
        textStyle,
      );
      _drawAxisLabel(
        canvas,
        'g/s',
        Offset(plotRect.right + 6, plotRect.center.dy),
        textStyle,
      );
    }

    final durationLabel = _formatDuration(scales.visibleEndMs);
    _drawAxisLabel(
      canvas,
      durationLabel,
      Offset(plotRect.right - 28, plotRect.bottom + 6),
      textStyle,
    );
  }

  void _drawEmptyLabel(Canvas canvas, Rect plotRect) {
    _paintText(
      canvas,
      'Waiting for samples…',
      Offset(plotRect.left, plotRect.center.dy - 6),
      const TextStyle(
        color: FlowlogChartColors.axisLabel,
        fontSize: 12,
      ),
      maxWidth: plotRect.width,
      align: TextAlign.center,
    );
  }

  void _drawPressure(Canvas canvas, Rect plotRect, _ChartScales scales) {
    final points = <Offset>[];
    for (final sample in samples) {
      final pressure = sample.pressureBar;
      if (pressure == null) {
        continue;
      }
      points.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: sample.elapsedMs,
        value: pressure,
        maxValue: scales.pressureMax,
      ));
    }

    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, plotRect.bottom)
      ..lineTo(points.first.dx, plotRect.bottom)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(plotRect.left, plotRect.bottom),
        Offset(plotRect.left, plotRect.top),
        [
          FlowlogChartColors.pressureLow.withValues(alpha: 0.35),
          FlowlogChartColors.pressureHigh.withValues(alpha: 0.45),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = FlowlogChartColors.pressureLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawSeries(
    Canvas canvas,
    Rect plotRect,
    _ChartScales scales, {
    required double? Function(ShotSample sample) valueSelector,
    required double maxValue,
    required Color color,
    required double strokeWidth,
    bool dashed = false,
  }) {
    final points = <Offset>[];
    for (final sample in samples) {
      final value = valueSelector(sample);
      if (value == null) {
        continue;
      }
      points.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: sample.elapsedMs,
        value: value,
        maxValue: maxValue,
      ));
    }

    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (dashed) {
      _drawDashedPath(canvas, path, paint);
      return;
    }

    canvas.drawPath(path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 4.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  Offset _pointFor(
    Rect plotRect,
    _ChartScales scales, {
    required int elapsedMs,
    required double value,
    required double maxValue,
  }) {
    final normalizedTime =
        (elapsedMs - scales.timeOffsetMs) / scales.timeSpanMs;
    final x = plotRect.left + normalizedTime.clamp(0.0, 1.0) * plotRect.width;
    final y = plotRect.bottom -
        (value / maxValue).clamp(0.0, 1.0) * plotRect.height;
    return Offset(x, y);
  }

  void _drawAxisLabel(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    _paintText(canvas, text, offset, style);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.start,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    if (maxWidth != null) {
      painter.layout(maxWidth: maxWidth);
    } else {
      painter.layout();
    }

    painter.paint(canvas, offset);
  }

  String _formatDuration(int elapsedMs) {
    final seconds = (elapsedMs / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) {
      return '${remainingSeconds}s';
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant DualCurveChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.maxDurationMs != maxDurationMs ||
        oldDelegate.viewport != viewport ||
        oldDelegate.showPressure != showPressure ||
        oldDelegate.showWeight != showWeight ||
        oldDelegate.showFlow != showFlow ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.compact != compact ||
        oldDelegate.axisUnitLabel != axisUnitLabel;
  }
}

class _ChartScales {
  const _ChartScales({
    required this.timeOffsetMs,
    required this.timeSpanMs,
    required this.visibleEndMs,
    required this.pressureMax,
    required this.weightMax,
    required this.flowMax,
  });

  final int timeOffsetMs;
  final int timeSpanMs;
  final int visibleEndMs;
  final double pressureMax;
  final double weightMax;
  final double flowMax;

  factory _ChartScales.fromSamples(
    List<ShotSample> samples, {
    int? maxDurationMs,
    required ChartViewport viewport,
  }) {
    var pressureMax = 12.0;
    var weightMax = 50.0;
    var flowMax = 5.0;

    final windowStart = viewport.visibleStartMs;
    final windowEnd = viewport.visibleEndMs;

    for (final sample in samples) {
      if (sample.elapsedMs < windowStart || sample.elapsedMs > windowEnd) {
        continue;
      }
      if (sample.pressureBar != null) {
        pressureMax = math.max(pressureMax, sample.pressureBar! * 1.1);
      }
      if (sample.weightG != null) {
        weightMax = math.max(weightMax, sample.weightG! * 1.1);
      }
      if (sample.flowGs != null) {
        flowMax = math.max(flowMax, sample.flowGs! * 1.1);
      }
    }

    return _ChartScales(
      timeOffsetMs: viewport.visibleStartMs,
      timeSpanMs: math.max(viewport.visibleDurationMs, 1),
      visibleEndMs: viewport.visibleEndMs,
      pressureMax: pressureMax,
      weightMax: weightMax,
      flowMax: flowMax,
    );
  }
}