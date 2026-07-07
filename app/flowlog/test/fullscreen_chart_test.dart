import 'dart:io';

import 'dart:convert';

import 'package:flowlog/screens/history/history_fullscreen_chart.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens and closes fullscreen live chart route', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scaleTransport = MockDecentScaleTransport();
    final scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
    final replayAdapter = MockReplayAdapter(
      fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
      speed: 0,
    );
    final controller = LiveShotController(
      sampleAdapter: replayAdapter,
      onTare: () => scaleAdapter.tare(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: LiveScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('live_fullscreen_open')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live_fullscreen_chart')), findsOneWidget);
    expect(find.byKey(const Key('live_fullscreen_dual_chart')), findsOneWidget);
    expect(find.byKey(const Key('live_brew')), findsOneWidget);
    expect(find.byType(DualCurveChart), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_fullscreen_close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live_fullscreen_chart')), findsNothing);
    expect(find.byKey(const Key('live_fullscreen_open')), findsOneWidget);
  });

  testWidgets('history fullscreen chart does not overflow on phone size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final shot = _loadFixtureShot('shots/minimal_shot.json');

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => openHistoryFullscreenChart(
                    context,
                    shot: shot,
                  ),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_fullscreen_chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history fullscreen chart avoids overflow with crosshair legend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final shot = _loadFixtureShot('shots/minimal_shot.json');

    await tester.pumpWidget(
      MaterialApp(
        home: HistoryFullscreenChartScreen(shot: shot),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_fullscreen_dual_chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Shot _loadFixtureShot(String relativePath) {
  final file = File(_fixturePath(relativePath));
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Shot.fromJson(json);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
    '../../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}