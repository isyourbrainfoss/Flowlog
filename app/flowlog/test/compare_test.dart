import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/library/compare.dart';
import 'package:flowlog/screens/library_screen.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helpers.dart';

void main() {
  group('CompareScreen', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('prompts to select shots when fewer than two are chosen', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await repository.insertShot(shot);
      await repository.insertShot(
        shot.copyWith(
          id: 'shot-minimal-002',
          startedAt: DateTime.utc(2026, 6, 29, 11),
        ),
      );

      await _pumpCompareScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('Select 2 or more shots to compare'), findsOneWidget);
      expect(find.byKey(const Key('compare_overlay_chart')), findsNothing);
    });

    testWidgets('overlays two selected shots with distinct legend labels', (
      tester,
    ) async {
      final baseline = _loadFixtureShot('shots/minimal_shot.json');
      final comparison = baseline.copyWith(
        id: 'shot-minimal-002',
        startedAt: DateTime.utc(2026, 6, 29, 11),
        samples: [
          const ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0, flowGs: 0),
          const ShotSample(
            elapsedMs: 15000,
            pressureBar: 8.0,
            weightG: 17.0,
            flowGs: 1.0,
          ),
        ],
      );

      await repository.insertShot(baseline);
      await repository.insertShot(comparison);

      await _pumpCompareScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('compare_select_shot-minimal-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('compare_select_shot-minimal-002')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('compare_overlay_chart')), findsOneWidget);
      expect(find.textContaining('Shot 1'), findsOneWidget);
      expect(find.textContaining('Shot 2'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('Overlay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clear all deselects shots and hides chart', (tester) async {
      final baseline = _loadFixtureShot('shots/minimal_shot.json');
      final comparison = baseline.copyWith(
        id: 'shot-minimal-002',
        startedAt: DateTime.utc(2026, 6, 29, 11),
      );

      await repository.insertShot(baseline);
      await repository.insertShot(comparison);

      await _pumpCompareScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('compare_select_shot-minimal-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('compare_select_shot-minimal-002')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('compare_overlay_chart')), findsOneWidget);

      await tester.tap(find.byKey(const Key('compare_clear_all')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('compare_overlay_chart')), findsNothing);
      expect(find.text('Select 2 or more shots to compare'), findsOneWidget);
    });

    testWidgets('delta highlight toggle updates chart state', (tester) async {
      final baseline = _loadFixtureShot('shots/minimal_shot.json');
      final comparison = baseline.copyWith(
        id: 'shot-minimal-002',
        startedAt: DateTime.utc(2026, 6, 29, 11),
        samples: [
          const ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0, flowGs: 0),
          const ShotSample(
            elapsedMs: 15000,
            pressureBar: 8.0,
            weightG: 17.0,
            flowGs: 1.0,
          ),
        ],
      );

      await repository.insertShot(baseline);
      await repository.insertShot(comparison);

      await _pumpCompareScreen(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('compare_select_shot-minimal-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('compare_select_shot-minimal-002')));
      await tester.pumpAndSettle();

      final chartFinder = find.byKey(const Key('compare_overlay_chart'));
      var chart = tester.widget<CompareOverlayChart>(chartFinder);
      expect(chart.showDeltaHighlight, isFalse);

      await tester.tap(find.byKey(const Key('compare_delta_toggle')));
      await tester.pumpAndSettle();

      chart = tester.widget<CompareOverlayChart>(chartFinder);
      expect(chart.showDeltaHighlight, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('LibraryScreen', () {
    testWidgets('exposes Compare tab in library', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LibraryScreen()),
      );
      await pumpForAsync(tester, frames: 8);

      expect(find.byKey(const Key('library_tab_compare')), findsOneWidget);

      await tester.tap(find.byKey(const Key('library_tab_compare')));
      await pumpForAsync(tester, frames: 8);

      expect(find.byType(CompareScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpCompareScreen(
  WidgetTester tester, {
  required ShotRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CompareScreen(shotRepository: repository),
    ),
  );
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