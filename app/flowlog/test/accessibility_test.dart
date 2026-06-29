import 'dart:io';

import 'package:flowlog/main.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveControls semantics', () {
    late LiveShotController controller;

    setUp(() {
      final scaleTransport = MockDecentScaleTransport();
      final scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
      final replayAdapter = MockReplayAdapter(
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

    testWidgets('exposes recording control labels', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveControls(controller: controller),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('live_start'))).label,
        'Start recording',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('live_pause'))).label,
        'Pause recording',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('live_resume'))).label,
        'Resume recording',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('live_stop'))).label,
        'Stop recording',
      );

      handle.dispose();
    });
  });

  group('StarShotFab semantics', () {
    testWidgets('announces disabled state before a stopped session', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            floatingActionButton: StarShotFab(
              enabled: false,
              onPressed: null,
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('star_shot_fab'))).label,
        'Save star shot, unavailable until recording stops',
      );

      handle.dispose();
    });

    testWidgets('announces enabled save action', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: StarShotFab(
              enabled: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('star_shot_fab'))).label,
        'Save star shot',
      );

      handle.dispose();
    });
  });

  group('Shell navigation semantics', () {
    testWidgets('bottom bar destinations expose descriptive labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FlowlogApp());
      await tester.pumpAndSettle();

      for (final destination in appDestinations) {
        final semantics = tester.getSemantics(
          find.byTooltip(destination.semanticsLabel),
        );
        expect(semantics.label, contains(destination.semanticsLabel));
        expect(semantics.getSemanticsData().hasFlag(SemanticsFlag.isButton), isTrue);
      }

      handle.dispose();
    });

    testWidgets('sidebar destinations expose descriptive labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const FlowlogApp());
      await tester.pumpAndSettle();

      for (final destination in appDestinations) {
        final semantics = tester.getSemantics(
          find.text(destination.label),
        );
        expect(semantics.label, contains(destination.semanticsLabel));
      }

      handle.dispose();
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