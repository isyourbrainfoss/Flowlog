import 'dart:math' as math;

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

import 'dual_curve_chart.dart';

/// Compact pressure sparkline for history cards and summaries.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.samples,
    this.height = 48,
    this.lineColor,
    this.fillColor,
    this.backgroundColor = Colors.transparent,
  });

  final List<ShotSample> samples;
  final double height;
  final Color? lineColor;
  final Color? fillColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedLineColor = lineColor ?? FlowlogChartColors.pressureLine;

    return RepaintBoundary(
      child: Semantics(
        label: 'Pressure sparkline',
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(
              samples: samples,
              lineColor: resolvedLineColor,
              fillColor: fillColor ?? resolvedLineColor.withValues(alpha: 0.15),
              backgroundColor: backgroundColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.samples,
    required this.lineColor,
    required this.fillColor,
    required this.backgroundColor,
  });

  final List<ShotSample> samples;
  final Color lineColor;
  final Color fillColor;
  final Color backgroundColor;

  static const _horizontalPad = 2.0;
  static const _verticalPad = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundColor.a > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor,
      );
    }

    final plotRect = Rect.fromLTWH(
      _horizontalPad,
      _verticalPad,
      math.max(1, size.width - _horizontalPad * 2),
      math.max(1, size.height - _verticalPad * 2),
    );

    final points = <Offset>[];
    var maxPressure = 0.0;
    var maxElapsedMs = 1;

    for (final sample in samples) {
      final pressure = sample.pressureBar;
      if (pressure == null) {
        continue;
      }
      maxPressure = math.max(maxPressure, pressure);
      maxElapsedMs = math.max(maxElapsedMs, sample.elapsedMs);
    }

    for (final sample in samples) {
      final pressure = sample.pressureBar;
      if (pressure == null) {
        continue;
      }
      points.add(
        Offset(
          plotRect.left +
              (sample.elapsedMs / maxElapsedMs).clamp(0.0, 1.0) *
                  plotRect.width,
          plotRect.bottom -
              (pressure / math.max(maxPressure, 1.0)).clamp(0.0, 1.0) *
                  plotRect.height,
        ),
      );
    }

    if (points.isEmpty) {
      _drawFlatLine(canvas, plotRect);
      return;
    }

    if (points.length == 1) {
      _drawFlatLine(canvas, plotRect, y: points.first.dy);
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
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawFlatLine(Canvas canvas, Rect plotRect, {double? y}) {
    final lineY = y ?? plotRect.center.dy;
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(plotRect.left, lineY),
      Offset(plotRect.right, lineY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}