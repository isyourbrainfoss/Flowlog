import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

final _golden = jsonDecode(
  File(_fixturePath('sensor_streams/flow_rate_golden.json')).readAsStringSync(),
) as Map<String, dynamic>;

final _goldenConfig = _golden['config'] as Map<String, dynamic>;
final _calculator = FlowRateCalculator(
  maxGapMs: _goldenConfig['maxGapMs'] as int,
  windowSize: _goldenConfig['windowSize'] as int,
);

void main() {
  group('FlowRateCalculator', () {
    for (final caseEntry in _goldenCases(_golden)) {
      test('golden: ${caseEntry['name']}', () {
        final samples = _inputSamples(caseEntry);
        final expected = _expectedFlowRates(caseEntry);

        final actual = _calculator.compute(samples);

        expect(actual, hasLength(expected.length));
        for (var i = 0; i < expected.length; i++) {
          expect(actual[i].elapsedMs, samples[i].elapsedMs);
          expect(actual[i].weightG, samples[i].weightG);
          expect(actual[i].pressureBar, samples[i].pressureBar);
          _expectFlow(actual[i].flowGs, expected[i]);
        }
      });
    }

    test('computeFlowRates uses default calculator settings', () {
      const samples = [
        ShotSample(elapsedMs: 0, weightG: 0.0),
        ShotSample(elapsedMs: 1000, weightG: 1.0),
        ShotSample(elapsedMs: 2000, weightG: 2.0),
      ];

      final actual = computeFlowRates(samples);
      final expected = _calculator.compute(samples);

      expect(actual, expected);
    });

    test('empty input returns empty output', () {
      expect(_calculator.compute([]), isEmpty);
      expect(computeFlowRates([]), isEmpty);
    });

    test('long gap resets smoothing buffer', () {
      const samples = [
        ShotSample(elapsedMs: 0, weightG: 0.0),
        ShotSample(elapsedMs: 1000, weightG: 2.0),
        ShotSample(elapsedMs: 6000, weightG: 2.1),
        ShotSample(elapsedMs: 7000, weightG: 3.1),
      ];

      final result = _calculator.compute(samples);

      expect(result[2].flowGs, 0.0);
      expect(result[3].flowGs, closeTo(1.0, 1e-9));
    });
  });
}

List<Map<String, dynamic>> _goldenCases(Map<String, dynamic> golden) {
  return (golden['cases'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .toList();
}

List<ShotSample> _inputSamples(Map<String, dynamic> caseEntry) {
  return (caseEntry['samples'] as List<dynamic>)
      .map((entry) => _sampleFromGolden(entry as Map<String, dynamic>))
      .toList();
}

List<double?> _expectedFlowRates(Map<String, dynamic> caseEntry) {
  return (caseEntry['samples'] as List<dynamic>)
      .map((entry) {
        final expected = (entry as Map<String, dynamic>)['expectedFlowGs'];
        return expected == null ? null : (expected as num).toDouble();
      })
      .toList();
}

ShotSample _sampleFromGolden(Map<String, dynamic> json) {
  return ShotSample(
    elapsedMs: json['elapsedMs'] as int,
    pressureBar: (json['pressureBar'] as num?)?.toDouble(),
    weightG: (json['weightG'] as num?)?.toDouble(),
  );
}

void _expectFlow(double? actual, double? expected) {
  if (expected == null) {
    expect(actual, isNull);
    return;
  }

  expect(actual, isNotNull);
  expect(actual, closeTo(expected, 1e-9));
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