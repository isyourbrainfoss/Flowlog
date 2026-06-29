import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('beanFillProgress', () {
    test('returns zero when yield and elapsed are zero', () {
      expect(
        beanFillProgress(yieldG: 0, elapsedMs: 0),
        0,
      );
    });

    test('averages normalized yield and elapsed progress', () {
      expect(
        beanFillProgress(
          yieldG: 18,
          elapsedMs: 15000,
          targetYieldG: 36,
          targetDurationMs: 30000,
        ),
        closeTo(0.5, 0.001),
      );
    });

    test('clamps progress to one when targets are exceeded', () {
      expect(
        beanFillProgress(
          yieldG: 50,
          elapsedMs: 40000,
          targetYieldG: 36,
          targetDurationMs: 30000,
        ),
        1,
      );
    });
  });

  group('personal best taste score helpers', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('fetchBestTasteScore ignores null taste scores', () async {
      await repository.insertShot(
        Shot(
          id: 'shot-a',
          startedAt: DateTime.parse('2026-06-29T10:00:00.000Z'),
          tasteScore: 6,
        ),
      );
      await repository.insertShot(
        Shot(
          id: 'shot-b',
          startedAt: DateTime.parse('2026-06-29T11:00:00.000Z'),
        ),
      );

      expect(await fetchBestTasteScore(repository), 6);
    });

    test('isPersonalBestTasteScore treats first scored shot as a PB', () {
      expect(
        isPersonalBestTasteScore(tasteScore: 7, previousBest: null),
        isTrue,
      );
      expect(
        isPersonalBestTasteScore(tasteScore: 7, previousBest: 7),
        isFalse,
      );
      expect(
        isPersonalBestTasteScore(tasteScore: 8, previousBest: 7),
        isTrue,
      );
      expect(
        isPersonalBestTasteScore(tasteScore: null, previousBest: 7),
        isFalse,
      );
    });

    test('celebratePersonalBestTasteScore bursts only on a new high score', () async {
      final confetti = ConfettiController();
      addTearDown(confetti.dispose);

      await repository.insertShot(
        Shot(
          id: 'shot-old',
          startedAt: DateTime.parse('2026-06-29T10:00:00.000Z'),
          tasteScore: 7,
        ),
      );

      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: Shot(
          id: 'shot-tied',
          startedAt: DateTime.parse('2026-06-29T11:00:00.000Z'),
          tasteScore: 7,
        ),
        confettiController: confetti,
      );
      expect(confetti.burstGeneration, 0);

      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: Shot(
          id: 'shot-new-pb',
          startedAt: DateTime.parse('2026-06-29T12:00:00.000Z'),
          tasteScore: 9,
        ),
        confettiController: confetti,
      );
      expect(confetti.burstGeneration, 1);
    });
  });

  group('BeanFillIcon', () {
    testWidgets('renders fill semantics from progress', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BeanFillIcon(progress: 0.42),
          ),
        ),
      );

      expect(find.byKey(const Key('bean_fill_icon')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('bean_fill_icon'))),
        matchesSemantics(label: 'Bean fill 42 percent'),
      );
    });
  });

  group('RecordingBeanFillIndicator', () {
    testWidgets('is hidden when session is idle', (tester) async {
      final controller = LiveShotController(
        sampleAdapter: MockReplayAdapter(
          fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
          speed: 0,
        ),
        onTare: () async {},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingBeanFillIndicator(controller: controller),
          ),
        ),
      );

      expect(find.byKey(const Key('bean_fill_icon')), findsNothing);
    });

    testWidgets('shows fill progress while recording', (tester) async {
      final controller = LiveShotController(
        sampleAdapter: MockReplayAdapter(
          fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
          speed: 0,
        ),
        onTare: () async {},
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordingBeanFillIndicator(controller: controller),
          ),
        ),
      );

      await tester.runAsync(() async {
        await controller.start();
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();

      expect(find.byKey(const Key('bean_fill_icon')), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);
    });
  });

  group('ConfettiOverlay', () {
    testWidgets('shows confetti layer after controller burst', (tester) async {
      final confetti = ConfettiController();
      addTearDown(confetti.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ConfettiOverlay(
            controller: confetti,
            child: const Text('live'),
          ),
        ),
      );

      expect(find.byKey(const Key('confetti_overlay')), findsNothing);

      confetti.burst();
      await tester.pump();

      expect(find.byKey(const Key('confetti_overlay')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();
    });
  });

  group('LiveScreen delight integration', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows bean fill indicator during recording', (tester) async {
      final harness = await _pumpLiveScreen(tester);

      expect(find.byKey(const Key('bean_fill_icon')), findsNothing);

      await _startSession(tester, harness.controller);

      expect(find.byKey(const Key('bean_fill_icon')), findsOneWidget);
    });

    testWidgets('bursts confetti when star shot sets a taste PB', (tester) async {
      await repository.insertShot(
        Shot(
          id: 'shot-existing',
          startedAt: DateTime.parse('2026-06-29T09:00:00.000Z'),
          tasteScore: 6,
        ),
      );

      final harness = await _pumpLiveScreen(
        tester,
        repository: repository,
        shotIdGenerator: () => 'shot-pb-test',
      );

      await _startAndStopSession(tester, harness.controller);

      await tester.tap(find.byKey(const Key('star_shot_fab')));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(
        find.byKey(const Key('metadata_taste_slider')),
      );
      await tester.drag(
        find.byKey(const Key('metadata_taste_slider')),
        Offset((slider.max - slider.value) * 20, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('metadata_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('confetti_overlay')), findsOneWidget);
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
        shotIdGenerator: shotIdGenerator,
      ),
    ),
  );

  return _LiveHarness(controller: controller);
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