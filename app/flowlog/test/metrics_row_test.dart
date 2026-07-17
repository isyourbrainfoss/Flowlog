import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveMetrics', () {
    test('computes projected yield from weight and flow', () {
      const current = ShotSample(
        elapsedMs: 10000,
        pressureBar: 8.0,
        weightG: 20.0,
        flowGs: 2.0,
      );

      final metrics = LiveMetrics.fromSamples(sample: current);

      expect(metrics.pressureBar, 8.0);
      expect(metrics.flowGs, 2.0);
      expect(metrics.elapsedMs, 10000);
      expect(metrics.projectedYieldG, closeTo(60.0, 0.01));
      expect(metrics.pressureTrend, MetricTrend.neutral);
    });

    test('derives trends from previous sample', () {
      const previous = ShotSample(
        elapsedMs: 5000,
        pressureBar: 7.0,
        weightG: 10.0,
        flowGs: 2.5,
      );
      const current = ShotSample(
        elapsedMs: 6000,
        pressureBar: 8.5,
        weightG: 12.5,
        flowGs: 2.0,
      );

      final metrics = LiveMetrics.fromSamples(
        sample: current,
        previous: previous,
      );

      expect(metrics.pressureTrend, MetricTrend.up);
      expect(metrics.flowTrend, MetricTrend.down);
      expect(metrics.elapsedTrend, MetricTrend.up);
      expect(metrics.projectedYieldTrend, MetricTrend.down);
    });

    test('computes flow when fixture samples lack flowGs', () {
      final fixtureSamples = _loadFixtureSamples('sensor_streams/demo_shot.jsonl');
      expect(fixtureSamples.any((sample) => sample.flowGs != null), isFalse);

      final midIndex = fixtureSamples.length ~/ 2;
      final metrics = LiveMetrics.fromSamples(
        sample: fixtureSamples[midIndex],
        previous: fixtureSamples[midIndex - 1],
      );

      expect(metrics.flowGs, isNotNull);
      expect(metrics.projectedYieldG, isNotNull);
    });
  });

  group('LiveMetricsRow', () {
    testWidgets('renders all metric labels and values from LiveMetrics', (
      tester,
    ) async {
      const metrics = LiveMetrics(
        pressureBar: 9.2,
        weightG: 28.0,
        flowGs: 1.8,
        elapsedMs: 18500,
        projectedYieldG: 34.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMetricsRow(metrics: metrics),
          ),
        ),
      );

      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Flow'), findsOneWidget);
      expect(find.text('Elapsed'), findsOneWidget);
      expect(find.text('Proj. yield'), findsOneWidget);
      expect(find.text('9.2 bar'), findsOneWidget);
      expect(find.text('28.0 g'), findsOneWidget);
      expect(find.text('1.8 g/s'), findsOneWidget);
      expect(find.text('0:18'), findsOneWidget);
      expect(find.text('34.5 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('builds metrics from ShotSample input', (tester) async {
      const sample = ShotSample(
        elapsedMs: 12000,
        pressureBar: 8.0,
        weightG: 24.0,
        flowGs: 2.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMetricsRow(sample: sample),
          ),
        ),
      );

      expect(find.text('8.0 bar'), findsOneWidget);
      expect(find.text('24.0 g'), findsOneWidget);
      expect(find.text('2.0 g/s'), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      // Projected yield at 12s with 24g @ 2 g/s toward 30s target.
      expect(find.text('60.0 g'), findsOneWidget);
    });

    testWidgets('shows trend arrows when values change', (tester) async {
      const previous = ShotSample(
        elapsedMs: 4000,
        pressureBar: 6.0,
        weightG: 8.0,
        flowGs: 3.0,
      );
      const current = ShotSample(
        elapsedMs: 5000,
        pressureBar: 9.0,
        weightG: 11.0,
        flowGs: 2.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMetricsRow(
              sample: current,
              previousSample: previous,
            ),
          ),
        ),
      );

      // Pressure↑ weight↑ flow↓ elapsed↑ proj.yield↓
      expect(find.byIcon(Icons.arrow_drop_up), findsNWidgets(3));
      expect(find.byIcon(Icons.arrow_drop_down), findsNWidgets(2));
      expect(find.byIcon(Icons.remove), findsNothing);
    });

    testWidgets('shows neutral arrows on first sample', (tester) async {
      const sample = ShotSample(
        elapsedMs: 1000,
        pressureBar: 1.0,
        weightG: 0.5,
        flowGs: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMetricsRow(sample: sample),
          ),
        ),
      );

      // Pressure, weight, flow, elapsed, proj. yield
      expect(find.byIcon(Icons.remove), findsNWidgets(5));
      expect(find.byIcon(Icons.arrow_drop_up), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('updates displayed values when sample changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    LiveMetricsRow(
                      sample: _rowSample,
                      previousSample: _rowPreviousSample,
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _rowPreviousSample = _rowSample;
                          _rowSample = const ShotSample(
                            elapsedMs: 8000,
                            pressureBar: 9.5,
                            weightG: 28.0,
                            flowGs: 1.5,
                          );
                        });
                      },
                      child: const Text('advance'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('7.0 bar'), findsOneWidget);
      expect(find.text('0:06'), findsOneWidget);

      await tester.tap(find.text('advance'));
      await tester.pump();

      expect(find.text('9.5 bar'), findsOneWidget);
      expect(find.text('0:08'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_up), findsWidgets);
    });

    testWidgets('renders placeholder dashes for missing values', (tester) async {
      const metrics = LiveMetrics(elapsedMs: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveMetricsRow(metrics: metrics),
          ),
        ),
      );

      // Pressure, weight, flow, proj. yield (elapsed is 0:00)
      expect(find.text('—'), findsNWidgets(4));
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('does not overflow in a very narrow viewport', (tester) async {
      const metrics = LiveMetrics(
        pressureBar: 9.2,
        flowGs: 1.8,
        elapsedMs: 18500,
        projectedYieldG: 34.5,
        pressureTrend: MetricTrend.up,
        flowTrend: MetricTrend.down,
      );

      await tester.binding.setSurfaceSize(const Size(120, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                child: LiveMetricsRow(metrics: metrics),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('9.2 bar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

ShotSample _rowSample = const ShotSample(
  elapsedMs: 6000,
  pressureBar: 7.0,
  weightG: 18.0,
  flowGs: 2.0,
);
ShotSample? _rowPreviousSample = const ShotSample(
  elapsedMs: 5000,
  pressureBar: 6.5,
  weightG: 16.0,
  flowGs: 2.2,
);

List<ShotSample> _loadFixtureSamples(String relativePath) {
  final file = File(_fixturePath(relativePath));
  final lines = file.readAsLinesSync();
  final samples = <ShotSample>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final json = jsonDecode(trimmed) as Map<String, dynamic>;
    samples.add(ShotSample.fromJson(json));
  }

  return samples;
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