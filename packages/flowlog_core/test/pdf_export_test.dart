import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('computeShotPdfSummary', () {
    test('summarizes minimal_shot fixture', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final summary = computeShotPdfSummary(shot);

      expect(summary.durationMs, 28500);
      expect(summary.sampleCount, 2);
      expect(summary.peakPressureBar, 9.0);
      expect(summary.maxFlowGs, 1.2);
      expect(summary.finalWeightG, 18.5);
      expect(summary.brewRatio, 2.0);
    });
  });

  group('shotPdfReportLines', () {
    test('includes metadata and statistics for minimal_shot', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final lines = shotPdfReportLines(shot);

      expect(lines, contains('Flowlog Shot Report'));
      expect(lines, contains('Shot ID: shot-minimal-001'));
      expect(lines, contains('Started: 2026-06-29T10:00:00.000Z'));
      expect(lines, contains('Ended: 2026-06-29T10:00:28.500Z'));
      expect(lines, contains('Dose: 18.0 g'));
      expect(lines, contains('Yield: 36.0 g'));
      expect(lines, contains('Bean: bean-house-blend'));
      expect(lines, contains('Flavour profile: chocolate 5, nutty 5'));
      expect(lines, contains('Duration: 28.5 s'));
      expect(lines, contains('Peak pressure: 9.0 bar'));
      expect(lines, contains('Max flow: 1.2 g/s'));
      expect(lines, contains('Brew ratio: 2.0:1'));
      expect(lines, contains('Minimal fixture shot for tests and mock replay.'));
    });
  });

  group('exportShotToPdf', () {
    test('produces a valid PDF byte stream', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final bytes = await exportShotToPdf(shot);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.last, equals(0x0A)); // PDF documents end with newline.
      expect(String.fromCharCodes(bytes), contains('Flowlog Shot Report'));
    });

    test('produces stable output size for the same shot', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final first = await exportShotToPdf(shot);
      final second = await exportShotToPdf(shot);

      expect(first.length, second.length);
    });

    test('changes when shot metadata changes', () async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final altered = shot.copyWith(notes: 'Updated notes for PDF export test.');

      expect(
        await exportShotToPdf(shot),
        isNot(equals(await exportShotToPdf(altered))),
      );
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final json = jsonDecode(File(_fixturePath(relativePath)).readAsStringSync())
      as Map<String, dynamic>;
  return Shot.fromJson(json);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) {
      return file.path;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}