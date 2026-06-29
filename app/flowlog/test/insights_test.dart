import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/library/insights.dart';
import 'package:flowlog/screens/library_screen.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeInsights', () {
    test('aggregates peak pressure by roast, taste by bean, and daily counts', () {
      const lightBean = Bean(
        id: 'bean-light',
        name: 'Ethiopia',
        roastLevel: 'light',
      );
      const darkBean = Bean(
        id: 'bean-dark',
        name: 'Sumatra',
        roastLevel: 'dark',
      );

      final shots = [
        Shot(
          id: 'shot-1',
          startedAt: DateTime.utc(2026, 6, 28, 10),
          beanId: 'bean-light',
          tasteScore: 8,
          samples: const [
            ShotSample(elapsedMs: 0, pressureBar: 0),
            ShotSample(elapsedMs: 1000, pressureBar: 8.0),
          ],
        ),
        Shot(
          id: 'shot-2',
          startedAt: DateTime.utc(2026, 6, 29, 10),
          beanId: 'bean-light',
          tasteScore: 6,
          samples: const [
            ShotSample(elapsedMs: 0, pressureBar: 0),
            ShotSample(elapsedMs: 1000, pressureBar: 10.0),
          ],
        ),
        Shot(
          id: 'shot-3',
          startedAt: DateTime.utc(2026, 6, 29, 12),
          beanId: 'bean-dark',
          tasteScore: 9,
          samples: const [
            ShotSample(elapsedMs: 0, pressureBar: 0),
            ShotSample(elapsedMs: 1000, pressureBar: 6.0),
          ],
        ),
      ];

      final snapshot = computeInsights(
        shots: shots,
        beans: const [lightBean, darkBean],
      );

      expect(snapshot.avgPeakPressureByRoast, hasLength(2));
      expect(snapshot.avgPeakPressureByRoast.first.label, 'light');
      expect(snapshot.avgPeakPressureByRoast.first.value, closeTo(9.0, 0.001));
      expect(snapshot.avgPeakPressureByRoast.first.sampleCount, 2);

      expect(snapshot.avgTasteByBean, hasLength(2));
      final ethiopia = snapshot.avgTasteByBean
          .firstWhere((entry) => entry.label == 'Ethiopia');
      expect(ethiopia.value, closeTo(7.0, 0.001));
      expect(ethiopia.sampleCount, 2);

      expect(snapshot.shotCountByDay, hasLength(2));
      expect(snapshot.shotCountByDay.first.label, '2026-06-28');
      expect(snapshot.shotCountByDay.first.value, 1);
      expect(snapshot.shotCountByDay.last.label, '2026-06-29');
      expect(snapshot.shotCountByDay.last.value, 2);
    });

    test('groups unlinked shots under unknown labels', () {
      final snapshot = computeInsights(
        shots: [
          Shot(
            id: 'shot-unlinked',
            startedAt: DateTime.utc(2026, 6, 29, 10),
            samples: const [
              ShotSample(elapsedMs: 0, pressureBar: 7.0),
            ],
          ),
        ],
        beans: const [],
      );

      expect(snapshot.avgPeakPressureByRoast.single.label, 'Unknown roast');
      expect(snapshot.avgPeakPressureByRoast.single.value, 7.0);
      expect(snapshot.avgTasteByBean, isEmpty);
      expect(snapshot.shotCountByDay.single.value, 1);
    });
  });

  group('InsightsScreen', () {
    late FlowlogDatabase db;
    late ShotRepository shotRepository;
    late BeanRepository beanRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      shotRepository = ShotRepository(db);
      beanRepository = BeanRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows empty state when no shots exist', (tester) async {
      await _pumpInsightsScreen(
        tester,
        shotRepository: shotRepository,
        beanRepository: beanRepository,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('insights_empty')), findsOneWidget);
      expect(find.text('Save shots to see trends'), findsOneWidget);
    });

    testWidgets('renders trend sections from saved shots', (tester) async {
      await beanRepository.upsertBean(
        const Bean(
          id: 'bean-house-blend',
          name: 'House Blend',
          roastLevel: 'medium',
        ),
      );

      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await shotRepository.insertShot(shot);
      await shotRepository.insertShot(
        shot.copyWith(
          id: 'shot-minimal-002',
          startedAt: DateTime.utc(2026, 6, 30, 11),
          tasteScore: 9,
        ),
      );

      await _pumpInsightsScreen(
        tester,
        shotRepository: shotRepository,
        beanRepository: beanRepository,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('insights_list')), findsOneWidget);
      expect(find.byKey(const Key('insights_peak_by_roast')), findsOneWidget);
      expect(find.byKey(const Key('insights_taste_by_bean')), findsOneWidget);
      expect(find.byKey(const Key('insights_shots_over_time')), findsOneWidget);
      expect(find.text('Avg peak pressure by roast'), findsOneWidget);
      expect(find.text('Avg taste by bean'), findsOneWidget);
      expect(find.text('Shots over time'), findsOneWidget);
      expect(find.textContaining('medium'), findsWidgets);
      expect(find.textContaining('House Blend'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('LibraryScreen', () {
    testWidgets('exposes Insights tab in library', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LibraryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library_tab_insights')), findsOneWidget);

      await tester.tap(find.byKey(const Key('library_tab_insights')));
      await tester.pumpAndSettle();

      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpInsightsScreen(
  WidgetTester tester, {
  required ShotRepository shotRepository,
  required BeanRepository beanRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: InsightsScreen(
        shotRepository: shotRepository,
        beanRepository: beanRepository,
      ),
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