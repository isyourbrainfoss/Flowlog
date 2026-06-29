import 'dart:convert';
import 'dart:io';

import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DualCurveChart', () {
    late List<ShotSample> fixtureSamples;

    setUp(() {
      fixtureSamples = _loadFixtureSamples('sensor_streams/demo_shot.jsonl');
    });

    testWidgets('renders static fixture samples without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: DualCurveChart(samples: fixtureSamples),
            ),
          ),
        ),
      );

      expect(find.byType(DualCurveChart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DualCurveChart),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DualCurveChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Flow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders synthetic sample list', (tester) async {
      final samples = <ShotSample>[
        const ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
        const ShotSample(elapsedMs: 5000, pressureBar: 9, weightG: 18),
        const ShotSample(elapsedMs: 10000, pressureBar: 8, weightG: 30),
        const ShotSample(elapsedMs: 15000, pressureBar: 2, weightG: 36),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DualCurveChart(samples: samples, height: 180),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DualCurveChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('updates from ValueNotifier mock stream', (tester) async {
      final notifier = ValueNotifier<List<ShotSample>>([]);

      await tester.pumpWidget(
        MaterialApp(
          home: DualCurveChart(samplesNotifier: notifier),
        ),
      );

      expect(find.text('Waiting for samples…'), findsNothing);

      for (var i = 0; i < 20; i++) {
        notifier.value = fixtureSamples.sublist(0, i + 1);
        await tester.pump();
      }

      expect(
        find.descendant(
          of: find.byType(DualCurveChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      notifier.dispose();
    });

    testWidgets('mock stream reaches full fixture length', (tester) async {
      final notifier = ValueNotifier<List<ShotSample>>([]);
      final streamed = <List<ShotSample>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: DualCurveChart(samplesNotifier: notifier),
        ),
      );

      for (var i = 0; i < fixtureSamples.length; i++) {
        notifier.value = fixtureSamples.sublist(0, i + 1);
        streamed.add(List<ShotSample>.from(notifier.value));
        await tester.pump();
      }

      expect(streamed.last, hasLength(fixtureSamples.length));
      expect(streamed.last.last.elapsedMs, 28000);
      expect(streamed.last.last.weightG, closeTo(36.32, 0.01));

      notifier.dispose();
    });

    testWidgets('renders annotation markers', (tester) async {
      const samples = [
        ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
        ShotSample(elapsedMs: 10000, pressureBar: 9, weightG: 30),
      ];
      const annotations = [
        ShotAnnotation(
          elapsedMs: 5000,
          label: 'Channel 1',
          type: ShotAnnotationType.channel,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DualCurveChart(
            samples: samples,
            annotations: annotations,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(DualCurveChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows target legend when target pressure samples provided', (
      tester,
    ) async {
      final target = <ShotSample>[
        const ShotSample(elapsedMs: 0, pressureBar: 0),
        const ShotSample(elapsedMs: 10000, pressureBar: 9),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DualCurveChart(
            samples: const [],
            targetPressureSamples: target,
          ),
        ),
      );

      expect(find.text('Target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('prepares flow rates when fixture lacks flowGs', () {
      expect(fixtureSamples.any((sample) => sample.flowGs != null), isFalse);

      final prepared = DualCurveChartPainter(
        samples: computeFlowRates(fixtureSamples),
      ).samples;

      expect(prepared.any((sample) => sample.flowGs != null), isTrue);
      expect(
        prepared.lastWhere((sample) => sample.weightG != null).flowGs,
        isNotNull,
      );
    });
  });
}

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