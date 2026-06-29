import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../flowlog_version.dart';
import '../models/shot.dart';
import '../models/shot_sample.dart';

/// Summary statistics included in a single-shot PDF report.
@immutable
class ShotPdfSummary {
  const ShotPdfSummary({
    required this.durationMs,
    required this.sampleCount,
    this.peakPressureBar,
    this.maxFlowGs,
    this.finalWeightG,
    this.brewRatio,
  });

  final int? durationMs;
  final int sampleCount;
  final double? peakPressureBar;
  final double? maxFlowGs;
  final double? finalWeightG;
  final double? brewRatio;
}

/// Computes summary statistics from [shot] metadata and samples.
ShotPdfSummary computeShotPdfSummary(Shot shot) {
  final samples = List<ShotSample>.from(shot.samples)
    ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));

  double? peakPressureBar;
  double? maxFlowGs;
  double? finalWeightG;

  for (final sample in samples) {
    final pressure = sample.pressureBar;
    if (pressure != null) {
      peakPressureBar = peakPressureBar == null
          ? pressure
          : math.max(peakPressureBar, pressure);
    }

    final flow = sample.flowGs;
    if (flow != null) {
      maxFlowGs = maxFlowGs == null ? flow : math.max(maxFlowGs, flow);
    }

    if (sample.weightG != null) {
      finalWeightG = sample.weightG;
    }
  }

  final durationMs = _shotDurationMs(shot, samples);
  final brewRatio = shot.doseG != null &&
          shot.yieldG != null &&
          shot.doseG! > 0
      ? shot.yieldG! / shot.doseG!
      : null;

  return ShotPdfSummary(
    durationMs: durationMs,
    sampleCount: samples.length,
    peakPressureBar: peakPressureBar,
    maxFlowGs: maxFlowGs,
    finalWeightG: finalWeightG,
    brewRatio: brewRatio,
  );
}

/// Builds deterministic plain-text lines used in the PDF body.
List<String> shotPdfReportLines(Shot shot) {
  final summary = computeShotPdfSummary(shot);
  final lines = <String>[
    'Flowlog Shot Report',
    'Flowlog core $flowlogCoreVersion',
    '',
    'Metadata',
    'Shot ID: ${shot.id}',
    'Started: ${_formatTimestamp(shot.startedAt)}',
  ];

  if (shot.endedAt != null) {
    lines.add('Ended: ${_formatTimestamp(shot.endedAt!)}');
  }
  if (shot.doseG != null) {
    lines.add('Dose: ${_formatGrams(shot.doseG!)}');
  }
  if (shot.yieldG != null) {
    lines.add('Yield: ${_formatGrams(shot.yieldG!)}');
  }
  if (shot.grindSetting != null) {
    lines.add('Grind: ${_formatNumber(shot.grindSetting!)}');
  }
  if (shot.beanId != null) {
    lines.add('Bean: ${shot.beanId}');
  }
  if (shot.waterTempC != null) {
    lines.add('Water temp: ${_formatTemp(shot.waterTempC!)}');
  }
  if (shot.tasteScore != null) {
    lines.add('Taste score: ${shot.tasteScore}/10');
  }
  if (shot.flavourTags.isNotEmpty) {
    lines.add('Flavour tags: ${shot.flavourTags.join(', ')}');
  }

  lines
    ..add('')
    ..add('Statistics')
    ..add('Duration: ${_formatDuration(summary.durationMs)}')
    ..add('Samples: ${summary.sampleCount}');

  if (summary.peakPressureBar != null) {
    lines.add('Peak pressure: ${_formatPressure(summary.peakPressureBar!)}');
  }
  if (summary.maxFlowGs != null) {
    lines.add('Max flow: ${_formatFlow(summary.maxFlowGs!)}');
  }
  if (summary.finalWeightG != null) {
    lines.add('Final weight (samples): ${_formatGrams(summary.finalWeightG!)}');
  }
  if (summary.brewRatio != null) {
    lines.add('Brew ratio: ${_formatBrewRatio(summary.brewRatio!)}');
  }

  if (shot.notes != null && shot.notes!.trim().isNotEmpty) {
    lines
      ..add('')
      ..add('Notes')
      ..add(shot.notes!.trim());
  }

  return lines;
}

/// Generates a single-shot PDF report with metadata and a text stats summary.
Future<Uint8List> exportShotToPdf(Shot shot) async {
  final document = pw.Document(
    title: 'Flowlog Shot Report',
    creator: 'Flowlog $flowlogCoreVersion',
  );

  final bodyStyle = pw.TextStyle(fontSize: 11);
  final headingStyle = pw.TextStyle(
    fontSize: 18,
    fontWeight: pw.FontWeight.bold,
  );
  final sectionStyle = pw.TextStyle(
    fontSize: 13,
    fontWeight: pw.FontWeight.bold,
  );

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) {
        final children = <pw.Widget>[
          pw.Text('Flowlog Shot Report', style: headingStyle),
          pw.SizedBox(height: 16),
        ];

        for (final line in shotPdfReportLines(shot).skip(2)) {
          if (line.isEmpty) {
            children.add(pw.SizedBox(height: 8));
            continue;
          }

          if (line == 'Metadata' || line == 'Statistics' || line == 'Notes') {
            children
              ..add(pw.SizedBox(height: 4))
              ..add(pw.Text(line, style: sectionStyle))
              ..add(pw.SizedBox(height: 4));
            continue;
          }

          children.add(pw.Text(line, style: bodyStyle));
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        );
      },
    ),
  );

  return document.save();
}

int? _shotDurationMs(Shot shot, List<ShotSample> samples) {
  if (shot.endedAt != null) {
    return shot.endedAt!.difference(shot.startedAt).inMilliseconds;
  }
  if (samples.isEmpty) {
    return null;
  }
  return samples.last.elapsedMs;
}

String _formatTimestamp(DateTime value) =>
    value.toUtc().toIso8601String();

String _formatGrams(double value) => '${value.toStringAsFixed(1)} g';

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

String _formatTemp(double value) => '${value.toStringAsFixed(1)} C';

String _formatPressure(double value) => '${value.toStringAsFixed(1)} bar';

String _formatFlow(double value) => '${value.toStringAsFixed(1)} g/s';

String _formatDuration(int? durationMs) {
  if (durationMs == null) {
    return 'n/a';
  }
  return '${(durationMs / 1000).toStringAsFixed(1)} s';
}

String _formatBrewRatio(double value) => '${value.toStringAsFixed(1)}:1';