import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Repeat shot', () {
    late FlowlogDatabase database;
    late ShotRepository shotRepository;
    late ProfileRepository profileRepository;
    late RepeatShotController repeatController;
    late LiveShotController liveController;

    setUp(() {
      database = FlowlogDatabase.inMemory();
      shotRepository = ShotRepository(database);
      profileRepository = ProfileRepository(database);
      repeatController = RepeatShotController();
      final scaleAdapter = DecentScaleBleAdapter(
        transport: MockDecentScaleTransport(),
      );
      liveController = LiveShotController(
        sampleAdapter: MockReplayAdapter(
          fixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
          speed: 0,
        ),
        onTare: () => scaleAdapter.tare(),
      );
    });

    tearDown(() async {
      await database.close();
      repeatController.dispose();
      liveController.dispose();
    });

    test('RepeatShotPrefill maps shot metadata and pressure samples', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final prefill = RepeatShotPrefill.fromShot(shot);

      expect(prefill.metadata.doseG, shot.doseG);
      expect(prefill.metadata.yieldG, shot.yieldG);
      expect(prefill.metadata.grindSetting, shot.grindSetting);
      expect(prefill.metadata.beanId, shot.beanId);
      expect(prefill.targetPressureSamples, isNotEmpty);
    });

    testWidgets('shot detail repeat saves profile and switches to live', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      AppTab? switchedTab;

      await tester.pumpWidget(
        MaterialApp(
          home: FlowlogShellScope(
            switchTab: (tab) => switchedTab = tab,
            child: RepeatShotScope(
              controller: repeatController,
              child: ShotDetailScreen(
                shot: shot,
                profileRepository: profileRepository,
                repeatShotController: repeatController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('repeat_shot_button')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('repeat_shot_button')));
      await tester.pumpAndSettle();

      expect(switchedTab, AppTab.live);
      expect(repeatController.prefill, isNotNull);
      expect(repeatController.prefill!.metadata.doseG, shot.doseG);
      expect(repeatController.prefill!.targetPressureSamples, isNotEmpty);

      final profiles = await profileRepository.listProfiles(includeSamples: true);
      expect(profiles, hasLength(1));
      expect(profiles.single.sourceShotId, shot.id);
      expect(profiles.single.pressureSamples, isNotEmpty);
    });

    testWidgets('live screen shows target overlay when prefill is active', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      repeatController.setPrefill(RepeatShotPrefill.fromShot(shot));

      await tester.pumpWidget(
        MaterialApp(
          home: RepeatShotScope(
            controller: repeatController,
            child: LiveScreen(
              controller: liveController,
              shotRepository: shotRepository,
              profileRepository: profileRepository,
              repeatShotController: repeatController,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Target:'), findsOneWidget);

      final chart = tester.widget<DualCurveChart>(find.byType(DualCurveChart));
      expect(chart.targetPressureSamples, isNotEmpty);
    });

    testWidgets('metadata sheet prefill uses repeat profile metadata', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final prefill = RepeatShotPrefill.fromShot(shot);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () {
                    showMetadataSheet(context, initial: prefill.metadata);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Dose: 18.0 g'), findsOneWidget);
    });

    testWidgets('live repeat button saves profile from stopped session', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: RepeatShotScope(
            controller: repeatController,
            child: LiveScreen(
              controller: liveController,
              shotRepository: shotRepository,
              profileRepository: profileRepository,
              repeatShotController: repeatController,
            ),
          ),
        ),
      );
      await tester.pump();

      await _startAndStopSession(tester, liveController);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(liveController.canSaveShot, isTrue);
      await tester.ensureVisible(find.byKey(const Key('repeat_shot_button')));
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('repeat_shot_button')));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(repeatController.prefill, isNotNull);
      expect(repeatController.prefill!.targetPressureSamples, isNotEmpty);

      final profiles = await profileRepository.listProfiles(includeSamples: true);
      expect(profiles, hasLength(1));
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final json =
      jsonDecode(File(_fixturePath(relativePath)).readAsStringSync())
          as Map<String, dynamic>;
  return Shot.fromJson(json);
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