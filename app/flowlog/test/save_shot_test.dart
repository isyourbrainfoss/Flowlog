import 'dart:convert';
import 'dart:io';

import 'package:flowlog/location/brew_gps.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helpers.dart';

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

  group('defaultMetadataFromSamples', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('includes current coffeejack turn settings', () async {
      final coffeejackStore = CoffeejackSettingsStore(
        settingsPath:
            '${Directory.systemTemp.path}/coffeejack_default_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await coffeejackStore.save(
        const CoffeejackSettings(
          rewindTurnsBeforeFill: 9,
          slowPreinfusionTurns: 5,
        ),
      );

      final metadata = await defaultMetadataFromSamples(
        const [
          ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
          ShotSample(elapsedMs: 1000, pressureBar: 9, weightG: 36),
        ],
        coffeejackSettingsStore: coffeejackStore,
      );

      expect(metadata.coffeejackRewindTurns, 9);
      expect(metadata.coffeejackPreinfusionTurns, 5);
    });

    test('applies default dose and last grind setting', () async {
      final prior = _loadFixtureShot().copyWith(
        id: 'prior-shot',
        grindSetting: 14.5,
        startedAt: DateTime.utc(2026, 6, 28),
      );
      await repository.insertShot(prior);

      final metadata = await defaultMetadataFromSamples(
        const [
          ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
          ShotSample(elapsedMs: 1000, pressureBar: 9, weightG: 36),
        ],
        shotRepository: repository,
      );

      expect(metadata.doseG, kDefaultBrewDoseG);
      expect(metadata.grindSetting, 14.5);
      expect(metadata.yieldG, 36);
    });

    test('uses default grind when no prior brew exists', () async {
      final metadata = await defaultMetadataFromSamples(
        const [
          ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
          ShotSample(elapsedMs: 1000, pressureBar: 9, weightG: 36),
        ],
        shotRepository: repository,
      );

      expect(metadata.grindSetting, kDefaultBrewGrindSetting);
    });
  });

  group('displayMetadataForShot', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('fills missing dose, grind, yield, temp, and turns for history display',
        () async {
      final coffeejackStore = CoffeejackSettingsStore(
        settingsPath:
            '${Directory.systemTemp.path}/coffeejack_display_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      await coffeejackStore.save(
        const CoffeejackSettings(
          rewindTurnsBeforeFill: 10,
          slowPreinfusionTurns: 6,
        ),
      );
      final prior = _loadFixtureShot().copyWith(
        id: 'prior-shot',
        grindSetting: 14.5,
        startedAt: DateTime.utc(2026, 6, 28),
      );
      await repository.insertShot(prior);

      final shot = Shot(
        id: 'sparse-shot',
        startedAt: DateTime.utc(2026, 6, 29),
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0, tempC: 92.0),
          ShotSample(elapsedMs: 1000, pressureBar: 9, weightG: 36.2, tempC: 93.5),
        ],
      );

      final metadata = await displayMetadataForShot(
        shot,
        shotRepository: repository,
        coffeejackSettingsStore: coffeejackStore,
      );

      expect(metadata.doseG, kDefaultBrewDoseG);
      expect(metadata.grindSetting, 14.5);
      expect(metadata.yieldG, 36.2);
      expect(metadata.waterTempC, 93.5);
      expect(metadata.coffeejackRewindTurns, 10);
      expect(metadata.coffeejackPreinfusionTurns, 6);
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

  group('runAutoSaveFlow', () {
    late FlowlogDatabase db;
    late ShotRepository repository;
    late BeanRepository beanRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
      beanRepository = BeanRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('auto-saves on stop and shows snackbar with actions', (
      tester,
    ) async {
      Shot? savedShot;
      final harness = await _pumpLiveScreen(
        tester,
        repository: repository,
        beanRepository: beanRepository,
        onShotSaved: (shot) => savedShot = shot,
        shotIdGenerator: () => 'shot-widget-test',
      );

      await _startAndStopSession(tester, harness.controller);

      expect(find.byKey(const Key('shot_saved_snackbar')), findsOneWidget);
      expect(find.textContaining('Shot saved'), findsOneWidget);
      expect(find.textContaining('peak'), findsOneWidget);
      expect(find.byKey(const Key('brew_complete_banner')), findsOneWidget);
      expect(find.byKey(const Key('shot_add_notes_action')), findsOneWidget);
      expect(find.byKey(const Key('shot_discard_action')), findsOneWidget);
      expect(savedShot, isNotNull);
      expect(savedShot!.id, 'shot-widget-test');
      expect(savedShot!.samples, harness.controller.samples);

      final loaded = await repository.getShotWithSamples('shot-widget-test');
      expect(loaded, savedShot);
    });

    testWidgets('add notes opens metadata sheet and updates saved shot', (
      tester,
    ) async {
      final harness = await _pumpLiveScreen(
        tester,
        repository: repository,
        beanRepository: beanRepository,
        shotIdGenerator: () => 'shot-notes-test',
      );

      await _startAndStopSession(tester, harness.controller);

      final shot = await repository.getShotWithSamples('shot-notes-test');
      expect(shot, isNotNull);
      final context = tester.element(find.byType(LiveScreen));
      ShotMetadata? saved;
      showMetadataSheet(
        context,
        initial: ShotMetadata.fromShot(shot!),
        beanRepository: beanRepository,
      ).then((value) => saved = value);
      await pumpUntilFound(tester, find.text('Shot metadata'));

      await tester.enterText(find.byKey(const Key('metadata_yield')), '36');
      await tester.tap(find.text('Flavour tags'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('metadata_save')));
      await tester.tap(find.byKey(const Key('metadata_save')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      await saveShot(
        repository: repository,
        shot: saved!.applyTo(shot),
      );

      final loaded = await repository.getShotWithSamples('shot-notes-test');
      expect(loaded?.doseG, 18);
      expect(loaded?.yieldG, 36);
    });

    test('buildShotFromSession stores GPS coordinates and location label', () {
      const samples = [
        ShotSample(elapsedMs: 0, pressureBar: 0),
        ShotSample(elapsedMs: 1000, pressureBar: 9),
      ];

      final shot = buildShotFromSession(
        samples: samples,
        startedAt: DateTime.utc(2026, 7, 5, 10),
        endedAt: DateTime.utc(2026, 7, 5, 10, 0, 30),
        location: 'Test cafe',
        latitude: 59.33,
        longitude: 18.07,
        id: 'shot-gps-test',
      );

      expect(shot.location, 'Test cafe');
      expect(shot.latitude, closeTo(59.33, 0.001));
      expect(shot.longitude, closeTo(18.07, 0.001));
    });

    testWidgets('discard removes auto-saved shot from repository', (
      tester,
    ) async {
      final harness = await _pumpLiveScreen(
        tester,
        repository: repository,
        beanRepository: beanRepository,
        shotIdGenerator: () => 'shot-discard-test',
      );

      await _startAndStopSession(tester, harness.controller);
      expect(find.text('Discard'), findsOneWidget);
      final saved = await repository.getShotWithSamples('shot-discard-test');
      expect(saved, isNotNull);
      await repository.deleteShot(saved!.id);

      final loaded = await repository.getShotWithSamples('shot-discard-test');
      expect(loaded, isNull);
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

Future<BrewGpsPosition?> _nullGpsPosition() async => null;

Future<_LiveHarness> _pumpLiveScreen(
  WidgetTester tester, {
  ShotRepository? repository,
  BeanRepository? beanRepository,
  void Function(Shot shot)? onShotSaved,
  ShotIdGenerator shotIdGenerator = generateShotId,
  BrewLocationStore? brewLocationStore,
  BrewGpsCapture? brewGpsCapture,
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

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MaterialApp(
      home: LiveScreen(
        controller: controller,
        shotRepository: repository,
        beanRepository: beanRepository,
        onShotSaved: onShotSaved,
        shotIdGenerator: shotIdGenerator,
        brewLocationStore: brewLocationStore,
        brewGpsCapture:
            brewGpsCapture ?? BrewGpsCapture(debugOverride: _nullGpsPosition),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _startAndStopSession(
  WidgetTester tester,
  LiveShotController controller,
) async {
  await _startSession(tester, controller);
  await tester.runAsync(() async {
    await controller.stop();
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await pumpUntilFound(tester, find.byKey(const Key('shot_saved_snackbar')));
}

String _formatElapsed(int elapsedMs) {
  final totalSeconds = elapsedMs ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
}