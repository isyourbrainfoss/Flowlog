import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/library/simulator.dart';
import 'package:flowlog/screens/library_screen.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps until [SimulatorScreen] finishes loading.
///
/// Uses [WidgetTester.runAsync] so bundled fixture loads from [rootBundle]
/// can complete across widget tests in this file.
Future<void> settleSimulator(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    for (var attempt = 0; attempt < 60; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      if (find.byKey(const Key('simulator_screen')).evaluate().isNotEmpty) {
        return;
      }
    }
    fail('Timed out waiting for simulator_screen');
  });
  await tester.pump();
}

void main() {
  group('predictFlowGs', () {
    test('returns zero for near-zero pressure', () {
      expect(predictFlowGs(0), 0);
      expect(predictFlowGs(0.1), 0);
    });

    test('increases monotonically with pressure', () {
      expect(predictFlowGs(3), lessThan(predictFlowGs(6)));
      expect(predictFlowGs(6), lessThan(predictFlowGs(9)));
      expect(predictFlowGs(9), lessThan(predictFlowGs(12)));
    });

    test('buildPredictedFlowSamples maps pressure to flow', () {
      const profile = [
        ShotSample(elapsedMs: 0, pressureBar: 0),
        ShotSample(elapsedMs: 1000, pressureBar: 5),
        ShotSample(elapsedMs: 2000, pressureBar: 10),
      ];

      final predicted = buildPredictedFlowSamples(profile);

      expect(predicted, hasLength(3));
      expect(predicted[1].flowGs, predictFlowGs(5));
      expect(predicted[2].flowGs, greaterThan(predicted[1].flowGs!));
    });

    test('summarizePredictedFlow reports peak and average', () {
      final samples = buildPredictedFlowSamples(const [
        ShotSample(elapsedMs: 0, pressureBar: 2),
        ShotSample(elapsedMs: 1000, pressureBar: 8),
        ShotSample(elapsedMs: 2000, pressureBar: 10),
      ]);

      final summary = summarizePredictedFlow(samples);

      expect(summary.peakPressureBar, 10);
      expect(summary.peakFlowGs, predictFlowGs(10));
      expect(summary.averageFlowGs, greaterThan(0));
      expect(summary.averageFlowGs, lessThan(summary.peakFlowGs));
    });
  });

  group('profileFromKeyframes', () {
    test('expands keyframes into a saved profile', () {
      const keyframes = [
        PressureKeyframe(elapsedMs: 0, pressureBar: 0),
        PressureKeyframe(elapsedMs: 6000, pressureBar: 6),
        PressureKeyframe(elapsedMs: 12000, pressureBar: 9),
      ];

      final profile = profileFromKeyframes(keyframes, name: 'Test curve');

      expect(profile.name, 'Test curve');
      expect(profile.pressureSamples, isNotEmpty);
      expect(profile.pressureSamples.last.pressureBar, closeTo(9, 0.01));
    });
  });

  group('SimulatorScreen', () {
    late FlowlogDatabase db;
    late ProfileRepository profileRepository;
    late ShotRepository shotRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      profileRepository = ProfileRepository(db);
      shotRepository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('smoke test shows editor, metrics, and chart with demo profile', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await profileRepository.insertProfile(
        SavedProfile.fromShot(
          shot,
          id: 'demo-profile',
          name: 'Starter profile',
          createdAt: DateTime.utc(2026, 6, 29),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SimulatorScreen(profileRepository: profileRepository),
        ),
      );
      await settleSimulator(tester);

      expect(find.byKey(const Key('simulator_screen')), findsOneWidget);
      expect(find.byKey(const Key('simulator_profile_editor')), findsOneWidget);
      expect(find.byKey(const Key('simulator_predicted_flow')), findsOneWidget);
      expect(find.byKey(const Key('simulator_flow_chart')), findsOneWidget);
      expect(find.textContaining('Starter profile'), findsOneWidget);
      expect(find.textContaining('g/s'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('loads saved profile when repository has data', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final profile = SavedProfile.fromShot(
        shot,
        id: 'profile-saved',
        name: 'Saved 9-bar profile',
      );
      await profileRepository.insertProfile(profile);

      await tester.pumpWidget(
        MaterialApp(
          home: SimulatorScreen(profileRepository: profileRepository),
        ),
      );
      await settleSimulator(tester);

      expect(find.text('Saved 9-bar profile'), findsOneWidget);
      expect(find.textContaining('Starter profile'), findsNothing);
    });

    test('higher keyframe pressures yield higher predicted peak flow', () {
      final lowKeyframes = const [
        PressureKeyframe(elapsedMs: 0, pressureBar: 0),
        PressureKeyframe(elapsedMs: 6000, pressureBar: 2),
        PressureKeyframe(elapsedMs: 12000, pressureBar: 3),
        PressureKeyframe(elapsedMs: 18000, pressureBar: 4),
        PressureKeyframe(elapsedMs: 28000, pressureBar: 5),
      ];
      final highKeyframes = const [
        PressureKeyframe(elapsedMs: 0, pressureBar: 0),
        PressureKeyframe(elapsedMs: 6000, pressureBar: 6),
        PressureKeyframe(elapsedMs: 12000, pressureBar: 8),
        PressureKeyframe(elapsedMs: 18000, pressureBar: 10),
        PressureKeyframe(elapsedMs: 28000, pressureBar: 12),
      ];

      final lowSummary = summarizePredictedFlow(
        buildPredictedFlowSamples(expandKeyframesToProfile(lowKeyframes)),
      );
      final highSummary = summarizePredictedFlow(
        buildPredictedFlowSamples(expandKeyframesToProfile(highKeyframes)),
      );

      expect(highSummary.peakFlowGs, greaterThan(lowSummary.peakFlowGs));
      expect(highSummary.peakPressureBar, greaterThan(lowSummary.peakPressureBar));
    });

    testWidgets('PressureProfileEditor remove point deletes selected keyframe', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 280,
                child: _ProfileEditorHarness(
                  initialKeyframes: const [
                    PressureKeyframe(elapsedMs: 0, pressureBar: 0),
                    PressureKeyframe(elapsedMs: 6000, pressureBar: 4),
                    PressureKeyframe(elapsedMs: 12000, pressureBar: 6),
                    PressureKeyframe(elapsedMs: 18000, pressureBar: 8),
                    PressureKeyframe(elapsedMs: 28000, pressureBar: 9),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final harness =
          tester.state<_ProfileEditorHarnessState>(find.byType(_ProfileEditorHarness));
      expect(harness.keyframes, hasLength(5));

      final editorRect =
          tester.getRect(find.byKey(const Key('simulator_profile_editor')));
      const leftPad = 40.0;
      const rightPad = 16.0;
      const topPad = 12.0;
      const bottomPad = 24.0;
      final plotWidth = editorRect.width - leftPad - rightPad;
      final plotHeight = editorRect.height - topPad - bottomPad;

      final middlePoint = Offset(
        editorRect.left + leftPad + (12000 / 28000) * plotWidth,
        editorRect.top + topPad + plotHeight - (6 / 12) * plotHeight,
      );

      final gesture = await tester.startGesture(middlePoint);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('simulator_remove_point')), findsOneWidget);

      await tester.tap(find.byKey(const Key('simulator_remove_point')));
      await tester.pumpAndSettle();

      expect(harness.keyframes, hasLength(4));
      expect(
        harness.keyframes.any((keyframe) => keyframe.elapsedMs == 12000),
        isFalse,
      );
    });

    testWidgets('PressureProfileEditor drag updates keyframe pressure', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 200,
                child: _ProfileEditorHarness(
                  initialKeyframes: const [
                    PressureKeyframe(elapsedMs: 0, pressureBar: 0),
                    PressureKeyframe(elapsedMs: 6000, pressureBar: 4),
                    PressureKeyframe(elapsedMs: 12000, pressureBar: 6),
                    PressureKeyframe(elapsedMs: 18000, pressureBar: 8),
                    PressureKeyframe(elapsedMs: 28000, pressureBar: 9),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final harness =
          tester.state<_ProfileEditorHarnessState>(find.byType(_ProfileEditorHarness));
      final beforePressure = harness.keyframes.last.pressureBar;

      final editorRect =
          tester.getRect(find.byKey(const Key('simulator_profile_editor')));
      const leftPad = 40.0;
      const rightPad = 16.0;
      const topPad = 12.0;
      const bottomPad = 24.0;
      final plotWidth = editorRect.width - leftPad - rightPad;
      final plotHeight = editorRect.height - topPad - bottomPad;

      final start = Offset(
        editorRect.left + leftPad + plotWidth,
        editorRect.top + topPad + plotHeight - (9 / 12) * plotHeight,
      );

      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(harness.keyframes.last.pressureBar, greaterThan(beforePressure));
    });

    testWidgets('import shot loads keyframes from saved shot', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await shotRepository.insertShot(shot);
      await profileRepository.insertProfile(
        SavedProfile.fromShot(
          shot,
          id: 'demo-profile',
          name: 'Starter profile',
          createdAt: DateTime.utc(2026, 6, 29),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SimulatorScreen(
            profileRepository: profileRepository,
            shotRepository: shotRepository,
          ),
        ),
      );
      await settleSimulator(tester);

      await tester.tap(find.byKey(const Key('simulator_import_shot')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(Key('simulator_import_shot_${shot.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(shot.id), findsOneWidget);
      expect(find.byKey(const Key('simulator_profile_editor')), findsOneWidget);
    });

    testWidgets('export profile persists keyframes to repository', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await profileRepository.insertProfile(
        SavedProfile.fromShot(
          shot,
          id: 'demo-profile',
          name: 'Starter profile',
          createdAt: DateTime.utc(2026, 6, 29),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SimulatorScreen(
            profileRepository: profileRepository,
            shotRepository: shotRepository,
          ),
        ),
      );
      await settleSimulator(tester);

      await tester.tap(find.byKey(const Key('simulator_export_profile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.showKeyboard(
        find.byKey(const Key('simulator_profile_name_field')),
      );
      await tester.enterText(
        find.byKey(const Key('simulator_profile_name_field')),
        'Exported curve',
      );
      await tester.tap(find.byKey(const Key('simulator_profile_name_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final profiles = await profileRepository.listProfiles();
      expect(profiles.any((profile) => profile.name == 'Exported curve'), isTrue);
    });
  });

  group('LibraryScreen', () {
    testWidgets('exposes Simulator tab in library', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LibraryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library_tab_simulator')), findsOneWidget);

      await tester.tap(find.byKey(const Key('library_tab_simulator')));
      await tester.pumpAndSettle();

      expect(find.byType(SimulatorScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ProfileEditorHarness extends StatefulWidget {
  const _ProfileEditorHarness({required this.initialKeyframes});

  final List<PressureKeyframe> initialKeyframes;

  @override
  State<_ProfileEditorHarness> createState() => _ProfileEditorHarnessState();
}

class _ProfileEditorHarnessState extends State<_ProfileEditorHarness> {
  late List<PressureKeyframe> keyframes = widget.initialKeyframes;

  @override
  Widget build(BuildContext context) {
    return PressureProfileEditor(
      keyframes: keyframes,
      durationMs: 28000,
      onKeyframesChanged: (updated) => setState(() => keyframes = updated),
    );
  }
}

Shot _loadFixtureShot(String relativePath) {
  final json =
      jsonDecode(File(_fixturePath(relativePath)).readAsStringSync())
          as Map<String, dynamic>;
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