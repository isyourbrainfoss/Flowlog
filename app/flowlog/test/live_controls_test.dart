import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveShotController', () {
    late MockDecentScaleTransport scaleTransport;
    late DecentScaleBleAdapter scaleAdapter;
    late MockReplayAdapter replayAdapter;
    late LiveShotController controller;

    setUp(() {
      scaleTransport = MockDecentScaleTransport();
      scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
      replayAdapter = MockReplayAdapter(
        fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
        speed: 0,
      );
      controller = LiveShotController(
        sampleAdapter: replayAdapter,
        onTare: () => scaleAdapter.tare(),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('start sends tare to scale transport', () async {
      await controller.start();

      expect(scaleTransport.writtenCommands, isNotEmpty);
      expect(scaleTransport.writtenCommands.first, DecentScaleCommands.tare());
    });

    test('start begins recording via ShotSession', () async {
      await controller.start();

      expect(controller.sessionState, ShotSessionState.recording);
    });

    test('stop finalizes session to stopped state', () async {
      await controller.start();
      await controller.stop();

      expect(controller.sessionState, ShotSessionState.stopped);
    });

    test('pause and resume toggle recording state', () async {
      await controller.start();

      controller.pause();
      expect(controller.sessionState, ShotSessionState.paused);

      controller.resume();
      expect(controller.sessionState, ShotSessionState.recording);
    });

    test('collects fixture samples while recording', () async {
      final expectedCount = File(_fixturePath('sensor_streams/demo_shot.jsonl'))
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .length;

      await controller.start();
      await Future<void>.delayed(Duration.zero);
      await controller.stop();

      expect(controller.sampleCount, expectedCount);
    });
  });

  group('LiveControls', () {
    late MockDecentScaleTransport scaleTransport;
    late DecentScaleBleAdapter scaleAdapter;
    late MockReplayAdapter replayAdapter;
    late LiveShotController controller;

    setUp(() {
      scaleTransport = MockDecentScaleTransport();
      scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
      replayAdapter = MockReplayAdapter(
        fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
        speed: 0,
      );
      controller = LiveShotController(
        sampleAdapter: replayAdapter,
        onTare: () => scaleAdapter.tare(),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    Future<void> pumpControls(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveControls(controller: controller),
          ),
        ),
      );
    }

    testWidgets('start brew button begins recording', (tester) async {
      await pumpControls(tester);

      expect(find.byKey(const Key('live_brew')), findsOneWidget);
      expect(find.text('Start brew'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_brew')));
        await tester.pumpAndSettle();
      });

      expect(controller.sessionState, ShotSessionState.recording);
      expect(find.text('Stop brew'), findsOneWidget);
      expect(scaleTransport.writtenCommands, isNotEmpty);
      expect(scaleTransport.writtenCommands.first, DecentScaleCommands.tare());
    });

    testWidgets('stop brew button finalizes session', (tester) async {
      await pumpControls(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_brew')));
        await tester.pumpAndSettle();
      });

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_brew')));
        await tester.pumpAndSettle();
      });

      expect(controller.sessionState, ShotSessionState.stopped);
      expect(find.text('Start brew'), findsOneWidget);
    });
  });
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