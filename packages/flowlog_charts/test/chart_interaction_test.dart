import 'dart:convert';
import 'dart:io';

import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChartViewport', () {
    test('pans within total duration', () {
      final viewport = ChartViewport(totalDurationMs: 28000);
      viewport.zoomAt(focalFraction: 0, scaleFactor: 2);

      viewport.panByMs(5000);

      expect(viewport.visibleStartMs, 5000);
      expect(viewport.visibleEndMs, 19000);
    });

    test('clamps pan at edges', () {
      final viewport = ChartViewport(
        totalDurationMs: 28000,
        visibleDurationMs: 10000,
      );

      viewport.panByMs(-5000);
      expect(viewport.visibleStartMs, 0);

      viewport.panByMs(50000);
      expect(viewport.visibleStartMs, 18000);
    });

    test('zooms in around focal point', () {
      final viewport = ChartViewport(totalDurationMs: 28000);

      viewport.zoomAt(focalFraction: 0.5, scaleFactor: 2);

      expect(viewport.visibleDurationMs, 14000);
      expect(viewport.visibleStartMs, 7000);
      expect(viewport.isFullyZoomedOut, isFalse);
    });

    test('reset restores full shot window', () {
      final viewport = ChartViewport(totalDurationMs: 28000);
      viewport.zoomAt(focalFraction: 0.25, scaleFactor: 4);
      viewport.panByMs(3000);

      viewport.reset();

      expect(viewport.visibleStartMs, 0);
      expect(viewport.visibleDurationMs, 28000);
      expect(viewport.isFullyZoomedOut, isTrue);
    });
  });

  group('ChartInteractionController', () {
    test('cycles view modes forward and backward', () {
      final controller = ChartInteractionController();

      controller.cycleViewMode();
      expect(controller.viewMode, ChartViewMode.split);

      controller.cycleViewMode();
      expect(controller.viewMode, ChartViewMode.flowOnly);

      controller.cycleViewMode(forward: false);
      expect(controller.viewMode, ChartViewMode.split);
    });

    test('syncTotalDuration follows live end when zoomed out', () {
      final controller = ChartInteractionController();
      controller.syncTotalDuration(10000);
      expect(controller.viewport.isFullyZoomedOut, isTrue);

      controller.syncTotalDuration(20000, followEndWhenZoomedOut: true);

      expect(controller.viewport.visibleEndMs, 20000);
      expect(controller.viewport.visibleStartMs, 0);
    });
  });

  group('DualCurveChart interaction', () {
    late List<ShotSample> fixtureSamples;

    setUp(() {
      fixtureSamples = _loadFixtureSamples('sensor_streams/demo_shot.jsonl');
    });

    Future<ChartInteractionController> pumpChart(
      WidgetTester tester, {
      ChartInteractionController? controller,
    }) async {
      final interactionController =
          controller ?? ChartInteractionController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DualCurveChart(
                samples: fixtureSamples,
                interactionController: interactionController,
              ),
            ),
          ),
        ),
      );

      return interactionController;
    }

    testWidgets('defaults to overlay view mode label', (tester) async {
      await pumpChart(tester);

      expect(find.text('Overlay'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('Flow'), findsOneWidget);
    });

    testWidgets('enum toggle switches to split panels', (tester) async {
      final controller = ChartInteractionController();
      await pumpChart(tester, controller: controller);

      controller.setViewMode(ChartViewMode.split);
      await tester.pump();

      expect(find.text('Split'), findsOneWidget);
      expect(find.text('Pressure'), findsNWidgets(2));
      expect(find.text('Weight'), findsNWidgets(2));
      expect(find.text('Flow'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(DualCurveChart),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('flow-only mode hides pressure and weight legend', (tester) async {
      final controller = ChartInteractionController();
      await pumpChart(tester, controller: controller);

      controller.setViewMode(ChartViewMode.flowOnly);
      await tester.pump();

      expect(find.text('Flow only'), findsOneWidget);
      expect(find.text('Pressure'), findsNothing);
      expect(find.text('Weight'), findsNothing);
      expect(find.text('Flow'), findsOneWidget);
    });

    testWidgets('pan gesture updates viewport start when zoomed in', (
      tester,
    ) async {
      final controller = ChartInteractionController();
      await pumpChart(tester, controller: controller);

      controller.viewport.zoomAt(focalFraction: 0, scaleFactor: 2);
      await tester.pump();

      final startMs = controller.viewport.visibleStartMs;
      final gesture = await tester.startGesture(const Offset(220, 120));
      await tester.pump();
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.viewport.visibleStartMs, greaterThan(startMs));
      expect(controller.viewport.isFullyZoomedOut, isFalse);
    });

    testWidgets('scale gesture zooms visible window', (tester) async {
      final controller = ChartInteractionController();
      await pumpChart(tester, controller: controller);

      final initialDuration = controller.viewport.visibleDurationMs;
      const focal = Offset(220, 120);
      const plotWidth = 320.0;

      controller.onScaleStart(
        ScaleStartDetails(
          focalPoint: focal,
          localFocalPoint: focal,
          pointerCount: 2,
        ),
      );
      controller.onScaleUpdate(
        ScaleUpdateDetails(
          focalPoint: focal,
          localFocalPoint: focal,
          scale: 2,
          horizontalScale: 2,
          verticalScale: 2,
          rotation: 0,
          pointerCount: 2,
          focalPointDelta: Offset.zero,
        ),
        plotWidth,
      );
      await tester.pump();

      expect(
        controller.viewport.visibleDurationMs,
        lessThan(initialDuration),
      );
    });

    testWidgets('view mode chips switch layout', (tester) async {
      final controller = ChartInteractionController();
      await pumpChart(tester, controller: controller);

      expect(controller.viewMode, ChartViewMode.overlay);

      await tester.tap(find.byKey(const Key('chart_view_mode_split')));
      await tester.pump();

      expect(controller.viewMode, ChartViewMode.split);
      expect(find.byKey(const Key('chart_view_mode_flowOnly')), findsOneWidget);
    });

    testWidgets('horizontal swipe cycles view mode when zoomed out', (
      tester,
    ) async {
      final controller = ChartInteractionController();
      await pumpChart(tester, controller: controller);

      expect(controller.viewMode, ChartViewMode.overlay);

      final gesture = await tester.startGesture(const Offset(300, 120));
      await tester.pump();
      await gesture.moveBy(const Offset(-180, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(controller.viewMode, ChartViewMode.split);
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