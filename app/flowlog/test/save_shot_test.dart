import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildShotFromSession', () {
    test('applies metadata and copies samples', () {
      const samples = [
        ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
        ShotSample(elapsedMs: 1000, pressureBar: 9, weightG: 18),
      ];
      const startedAt = '2026-06-29T10:00:00.000Z';
      const metadata = ShotMetadata(
        doseG: 18,
        yieldG: 36,
        beanId: 'bean-house-blend',
        tasteScore: 8,
        flavourTags: ['chocolate'],
      );

      final shot = buildShotFromSession(
        samples: samples,
        startedAt: DateTime.parse(startedAt),
        endedAt: DateTime.parse('2026-06-29T10:00:28.500Z'),
        metadata: metadata,
        id: 'shot-test-001',
      );

      expect(shot.id, 'shot-test-001');
      expect(shot.startedAt, DateTime.parse(startedAt));
      expect(shot.endedAt, DateTime.parse('2026-06-29T10:00:28.500Z'));
      expect(shot.doseG, 18);
      expect(shot.yieldG, 36);
      expect(shot.beanId, 'bean-house-blend');
      expect(shot.tasteScore, 8);
      expect(shot.flavourTags, ['chocolate']);
      expect(shot.samples, samples);
    });
  });

  group('saveShot', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('persists shot with samples to in-memory database', () async {
      final shot = _loadFixtureShot();

      await saveShot(repository: repository, shot: shot);

      final loaded = await repository.getShotWithSamples(shot.id);
      expect(loaded, shot);
    });
  });

  group('StarShotFab', () {
    testWidgets('is visible on Live tab', (tester) async {
      await _pumpLiveScreen(tester);

      expect(find.byKey(const Key('star_shot_fab')), findsOneWidget);
      expect(find.text('Star shot'), findsOneWidget);
    });

    testWidgets('is disabled until session is stopped with samples', (
      tester,
    ) async {
      final harness = await _pumpLiveScreen(tester);

      final fab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('star_shot_fab')),
      );
      expect(fab.onPressed, isNull);

      await _startAndStopSession(tester, harness.controller);

      expect(harness.controller.canSaveShot, isTrue);
      final enabledFab = tester.widget<FloatingActionButton>(
        find.byKey(const Key('star_shot_fab')),
      );
      expect(enabledFab.onPressed, isNotNull);
    });
  });

  group('runStarShotSaveFlow', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('opens metadata sheet, saves shot, and shows snackbar', (
      tester,
    ) async {
      Shot? savedShot;
      final harness = await _pumpLiveScreen(
        tester,
        repository: repository,
        onShotSaved: (shot) => savedShot = shot,
        shotIdGenerator: () => 'shot-widget-test',
      );

      await _startAndStopSession(tester, harness.controller);

      await tester.tap(find.byKey(const Key('star_shot_fab')));
      await tester.pumpAndSettle();

      expect(find.text('Shot metadata'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('metadata_dose')), '18');
      await tester.enterText(find.byKey(const Key('metadata_yield')), '36');
      await tester.tap(find.byKey(const Key('metadata_save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shot_saved_snackbar')), findsOneWidget);
      expect(find.text('Shot saved'), findsOneWidget);
      expect(savedShot, isNotNull);
      expect(savedShot!.id, 'shot-widget-test');
      expect(savedShot!.samples, harness.controller.samples);
      expect(savedShot!.doseG, 18);
      expect(savedShot!.yieldG, 36);

      final loaded = await repository.getShotWithSamples('shot-widget-test');
      expect(loaded, savedShot);
    });
  });

  group('LiveScreen integration', () {
    testWidgets('wires DualCurveChart to session samples notifier', (
      tester,
    ) async {
      final harness = await _pumpLiveScreen(tester);

      expect(find.byType(DualCurveChart), findsOneWidget);

      await _startSession(tester, harness.controller);

      final chart = tester.widget<DualCurveChart>(find.byType(DualCurveChart));
      expect(chart.samplesNotifier, isNotNull);
      expect(chart.samplesNotifier!.value, isNotEmpty);
    });

    testWidgets('wires LiveMetricsRow to latest sample', (tester) async {
      final harness = await _pumpLiveScreen(tester);

      await _startSession(tester, harness.controller);

      final latest = harness.controller.samples.last;
      expect(find.textContaining('bar'), findsWidgets);
      expect(find.text(_formatElapsed(latest.elapsedMs)), findsOneWidget);
    });

    testWidgets('preserves samples when resizing across layout breakpoints', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final harness = await _pumpLiveScreen(tester);
      await _startSession(tester, harness.controller);
      await tester.pump(const Duration(milliseconds: 200));

      final samplesBefore = harness.controller.sampleCount;
      expect(samplesBefore, greaterThan(0));

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpAndSettle();

      expect(harness.controller.sampleCount, samplesBefore);
      expect(find.text('$samplesBefore samples'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _LiveHarness {
  const _LiveHarness({required this.controller});

  final LiveShotController controller;
}

Future<_LiveHarness> _pumpLiveScreen(
  WidgetTester tester, {
  ShotRepository? repository,
  void Function(Shot shot)? onShotSaved,
  ShotIdGenerator shotIdGenerator = generateShotId,
}) async {
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
      home: LiveScreen(
        controller: controller,
        shotRepository: repository,
        onShotSaved: onShotSaved,
        shotIdGenerator: shotIdGenerator,
      ),
    ),
  );

  return _LiveHarness(controller: controller);
}

Shot _loadFixtureShot() {
  final file = File(_fixturePath('shots/minimal_shot.json'));
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

Future<void> _startSession(
  WidgetTester tester,
  LiveShotController controller,
) async {
  await tester.runAsync(() async {
    await controller.start();
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

Future<void> _startAndStopSession(
  WidgetTester tester,
  LiveShotController controller,
) async {
  await _startSession(tester, controller);
  await tester.runAsync(() async {
    await controller.stop();
  });
  await tester.pumpAndSettle();
}

String _formatElapsed(int elapsedMs) {
  final totalSeconds = elapsedMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
}