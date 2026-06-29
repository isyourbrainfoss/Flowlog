import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('ShotDetectSettings', () {
    test('default flow threshold is 0.2 g/s', () {
      const settings = ShotDetectSettings();
      expect(settings.flowThresholdGs, 0.2);
    });

    test('threshold is configurable', () {
      const settings = ShotDetectSettings(flowThresholdGs: 1.5);
      expect(settings.flowThresholdGs, 1.5);
    });
  });

  group('ShotDetector', () {
    const detector = ShotDetector();

    test('empty input returns not detected', () {
      final result = detector.detect([]);

      expect(result.detected, isFalse);
      expect(result.shotStartElapsedMs, isNull);
      expect(result.samples, isEmpty);
    });

    test('synthetic samples rebase at first flow above threshold', () {
      const samples = [
        ShotSample(elapsedMs: 0, weightG: 0.0),
        ShotSample(elapsedMs: 1000, weightG: 0.0),
        ShotSample(elapsedMs: 2000, weightG: 0.1),
        ShotSample(elapsedMs: 3000, weightG: 1.1),
        ShotSample(elapsedMs: 4000, weightG: 2.1),
      ];

      final result = detector.detect(samples);

      expect(result.detected, isTrue);
      expect(result.shotStartElapsedMs, 3000);
      expect(result.samples, hasLength(2));
      expect(result.samples.first.elapsedMs, 0);
      expect(result.samples.last.elapsedMs, 1000);
      expect(result.samples.first.flowGs, closeTo(0.3666666666666667, 1e-9));
      expect(result.samples.last.flowGs, closeTo(0.7, 1e-9));
    });

    test('higher threshold delays shot start', () {
      const samples = [
        ShotSample(elapsedMs: 0, weightG: 0.0),
        ShotSample(elapsedMs: 1000, weightG: 0.3),
        ShotSample(elapsedMs: 2000, weightG: 2.3),
      ];

      final lowThreshold = ShotDetector(
        settings: const ShotDetectSettings(flowThresholdGs: 0.2),
      ).detect(samples);
      final highThreshold = ShotDetector(
        settings: const ShotDetectSettings(flowThresholdGs: 1.0),
      ).detect(samples);

      expect(lowThreshold.detected, isTrue);
      expect(lowThreshold.shotStartElapsedMs, 1000);

      expect(highThreshold.detected, isTrue);
      expect(highThreshold.shotStartElapsedMs, 2000);
      expect(highThreshold.samples.first.flowGs, closeTo(1.15, 1e-9));
    });

    test('returns not detected when flow never exceeds threshold', () {
      const samples = [
        ShotSample(elapsedMs: 0, weightG: 0.0),
        ShotSample(elapsedMs: 1000, weightG: 0.01),
        ShotSample(elapsedMs: 2000, weightG: 0.02),
      ];

      final result = detector.detect(samples);

      expect(result.detected, isFalse);
      expect(result.shotStartElapsedMs, isNull);
      expect(result.samples, hasLength(3));
      expect(result.samples.every((sample) => sample.flowGs != null), isTrue);
    });

    test('demo_shot.jsonl detects shot start and rebases to t=0', () {
      final samples = _loadDemoShot();
      final result = detector.detect(samples);

      expect(result.detected, isTrue);
      expect(result.shotStartElapsedMs, 5600);
      expect(result.samples.first.elapsedMs, 0);
      expect(result.samples.first.flowGs, closeTo(2.1, 1e-9));
      expect(result.samples.last.elapsedMs, samples.last.elapsedMs - 5600);
    });

    test('detectShotStart convenience uses configurable threshold', () {
      const samples = [
        ShotSample(elapsedMs: 0, weightG: 0.0),
        ShotSample(elapsedMs: 1000, weightG: 0.5),
      ];

      final result = detectShotStart(samples, flowThresholdGs: 0.6);

      expect(result.detected, isFalse);
    });
  });
}

List<ShotSample> _loadDemoShot() {
  return File(_fixturePath('sensor_streams/demo_shot.jsonl'))
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty)
      .map((line) => ShotSample.fromJson(jsonDecode(line) as Map<String, dynamic>))
      .toList();
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