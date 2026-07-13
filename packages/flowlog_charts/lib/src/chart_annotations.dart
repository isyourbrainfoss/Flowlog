import 'dart:math' as math;

import 'chart_interaction.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Coffee-themed colors for annotation markers.
abstract final class FlowlogAnnotationColors {
  static const channel = Color(0xFFE8A54B);
  static const note = Color(0xFF5B8DB8);
  static const axisLabel = Color(0xFFD4C9BC);
}

/// Maps a chart [localX] coordinate to elapsed milliseconds.
int chartElapsedMsFromLocalX({
  required double localX,
  required double chartWidth,
  required ChartViewport viewport,
}) {
  const leftPad = 25.0;
  const rightPad = 35.0;
  final plotWidth = math.max(1, chartWidth - leftPad - rightPad);
  final fraction = ((localX - leftPad) / plotWidth).clamp(0.0, 1.0);
  return viewport.visibleStartMs +
      (fraction * viewport.visibleDurationMs).round();
}

/// Paints vertical annotation markers over a shot chart.
void paintShotAnnotations(
  Canvas canvas,
  Rect plotRect,
  ChartViewport viewport, {
  required List<ShotAnnotation> annotations,
}) {
  if (annotations.isEmpty) {
    return;
  }

  final linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  final labelStyle = const TextStyle(
    color: FlowlogAnnotationColors.axisLabel,
    fontSize: 9,
    fontWeight: FontWeight.w600,
  );

  for (final annotation in annotations) {
    if (annotation.elapsedMs < viewport.visibleStartMs ||
        annotation.elapsedMs > viewport.visibleEndMs) {
      continue;
    }

    final normalizedTime =
        (annotation.elapsedMs - viewport.visibleStartMs) / viewport.visibleDurationMs;
    final x = plotRect.left + normalizedTime.clamp(0.0, 1.0) * plotRect.width;

    final color = annotation.type == ShotAnnotationType.channel
        ? FlowlogAnnotationColors.channel
        : FlowlogAnnotationColors.note;
    linePaint.color = color.withValues(alpha: 0.85);

    canvas.drawLine(
      Offset(x, plotRect.top),
      Offset(x, plotRect.bottom),
      linePaint,
    );

    final markerPath = Path()
      ..moveTo(x, plotRect.top + 4)
      ..lineTo(x + 4, plotRect.top + 10)
      ..lineTo(x, plotRect.top + 16)
      ..lineTo(x - 4, plotRect.top + 10)
      ..close();
    canvas.drawPath(markerPath, Paint()..color = color);

    final labelPainter = TextPainter(
      text: TextSpan(text: annotation.label, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: plotRect.width * 0.35);

    final labelX = (x + 6).clamp(plotRect.left, plotRect.right - labelPainter.width);
    labelPainter.paint(canvas, Offset(labelX, plotRect.top + 18));
  }
}