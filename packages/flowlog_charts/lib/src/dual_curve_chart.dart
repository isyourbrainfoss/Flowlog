import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/foundation.dart';
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
class DualCurveChart extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    if (samplesNotifier != null) {
      return ValueListenableBuilder<List<ShotSample>>(
        valueListenable: samplesNotifier!,
        builder: (context, value, _) => _buildChart(value),
      );
    }
    return _buildChart(samples!);
  }

  Widget _buildChart(List<ShotSample> rawSamples) {
    final prepared = _prepareSamples(rawSamples);

    return RepaintBoundary(
      child: Semantics(
        label: 'Espresso shot chart',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: height,
              width: double.infinity,
              child: CustomPaint(
                painter: DualCurveChartPainter(
                  samples: prepared,
                  maxDurationMs: maxDurationMs,
                  showPressure: showPressure,
                  showWeight: showWeight,
                  showFlow: showFlow,
                  backgroundColor: backgroundColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _Legend(
              showPressure: showPressure,
              showWeight: showWeight,
              showFlow: showFlow,
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
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.showPressure,
    required this.showWeight,
    required this.showFlow,
  });

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;

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

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: items,
    );
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
    this.showPressure = true,
    this.showWeight = true,
    this.showFlow = true,
    this.backgroundColor = FlowlogChartColors.background,
  });

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
  final Color backgroundColor;

  static const _leftPad = 40.0;
  static const _rightPad = 40.0;
  static const _topPad = 12.0;
  static const _bottomPad = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      _leftPad,
      _topPad,
      math.max(1, size.width - _leftPad - _rightPad),
      math.max(1, size.height - _topPad - _bottomPad),
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

    const horizontalLines = 4;
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
      fontSize: 10,
    );

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

    final durationLabel = _formatDuration(scales.timeMaxMs);
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
    final x = plotRect.left +
        (elapsedMs / scales.timeMaxMs).clamp(0.0, 1.0) * plotRect.width;
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
        oldDelegate.showPressure != showPressure ||
        oldDelegate.showWeight != showWeight ||
        oldDelegate.showFlow != showFlow ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _ChartScales {
  const _ChartScales({
    required this.timeMaxMs,
    required this.pressureMax,
    required this.weightMax,
    required this.flowMax,
  });

  final int timeMaxMs;
  final double pressureMax;
  final double weightMax;
  final double flowMax;

  factory _ChartScales.fromSamples(
    List<ShotSample> samples, {
    int? maxDurationMs,
  }) {
    var pressureMax = 12.0;
    var weightMax = 50.0;
    var flowMax = 5.0;
    var timeMaxMs = maxDurationMs ?? 30000;

    for (final sample in samples) {
      if (sample.pressureBar != null) {
        pressureMax = math.max(pressureMax, sample.pressureBar! * 1.1);
      }
      if (sample.weightG != null) {
        weightMax = math.max(weightMax, sample.weightG! * 1.1);
      }
      if (sample.flowGs != null) {
        flowMax = math.max(flowMax, sample.flowGs! * 1.1);
      }
      timeMaxMs = math.max(timeMaxMs, sample.elapsedMs);
    }

    if (maxDurationMs != null) {
      timeMaxMs = math.max(timeMaxMs, maxDurationMs);
    }

    return _ChartScales(
      timeMaxMs: math.max(timeMaxMs, 1),
      pressureMax: pressureMax,
      weightMax: weightMax,
      flowMax: flowMax,
    );
  }
}