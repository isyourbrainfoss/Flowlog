import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog/screens/history_screen.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShotRepository.listShots filters', () {
    late FlowlogDatabase db;
    late ShotRepository shotRepository;
    late BeanRepository beanRepository;
    late TagRepository tagRepository;

    setUp(() async {
      db = FlowlogDatabase.inMemory();
      shotRepository = ShotRepository(db);
      beanRepository = BeanRepository(db);
      tagRepository = TagRepository(db);
      await _seedFilterFixtures(
        shotRepository: shotRepository,
        beanRepository: beanRepository,
        tagRepository: tagRepository,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('filters by bean id substring', () async {
      final shots = await shotRepository.listShots(
        filters: const ShotListFilters(beanQuery: 'ethiopia'),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-ethiopia']);
    });

    test('filters by linked bean name', () async {
      final shots = await shotRepository.listShots(
        filters: const ShotListFilters(beanQuery: 'house'),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-house']);
    });

    test('filters by date range', () async {
      final shots = await shotRepository.listShots(
        filters: ShotListFilters(
          startedOnOrAfter: DateTime.utc(2026, 6, 28),
          startedOnOrBefore: DateTime.utc(2026, 6, 28, 23, 59, 59, 999),
        ),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-house']);
    });

    test('filters by minimum taste score', () async {
      final shots = await shotRepository.listShots(
        filters: const ShotListFilters(minTasteScore: 8),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-ethiopia']);
    });

    test('filters by minimum peak pressure', () async {
      final shots = await shotRepository.listShots(
        includeSamples: true,
        filters: const ShotListFilters(minPeakPressureBar: 8.5),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-ethiopia']);
    });

    test('combines multiple filters', () async {
      final shots = await shotRepository.listShots(
        includeSamples: true,
        filters: ShotListFilters(
          beanQuery: 'ethiopia',
          minTasteScore: 8,
          minPeakPressureBar: 8.0,
        ),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-ethiopia']);
    });

    test('filters by tag id', () async {
      final shots = await shotRepository.listShots(
        filters: const ShotListFilters(tagIds: {'tag-practice'}),
      );

      expect(shots.map((shot) => shot.id).toList(), ['shot-ethiopia']);
    });

    test('filters by multiple tag ids with OR semantics', () async {
      final shots = await shotRepository.listShots(
        filters: const ShotListFilters(tagIds: {'tag-practice', 'tag-dial-in'}),
      );

      expect(
        shots.map((shot) => shot.id).toList(),
        containsAll(['shot-ethiopia', 'shot-house']),
      );
      expect(shots, hasLength(2));
    });
  });

  group('HistoryScreen filters', () {
    late FlowlogDatabase db;
    late ShotRepository shotRepository;
    late BeanRepository beanRepository;
    late TagRepository tagRepository;

    setUp(() async {
      db = FlowlogDatabase.inMemory();
      shotRepository = ShotRepository(db);
      beanRepository = BeanRepository(db);
      tagRepository = TagRepository(db);
      await _seedFilterFixtures(
        shotRepository: shotRepository,
        beanRepository: beanRepository,
        tagRepository: tagRepository,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows all seeded shots before filtering', (tester) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      expect(find.byType(HistoryShotCard), findsNWidgets(2));
    });

    testWidgets('bean filter updates visible history cards', (tester) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('history_filter_bean')),
        'ethiopia',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_shot_card_shot-ethiopia')), findsOneWidget);
      expect(find.byKey(const Key('history_shot_card_shot-house')), findsNothing);
    });

    testWidgets('taste filter updates visible history cards', (tester) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_filter_taste_min')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_shot_card_shot-ethiopia')), findsOneWidget);
      expect(find.byKey(const Key('history_shot_card_shot-house')), findsNothing);
    });

    testWidgets('peak pressure filter updates visible history cards', (
      tester,
    ) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('history_filter_peak_min')),
        '8.5',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_shot_card_shot-ethiopia')), findsOneWidget);
      expect(find.byKey(const Key('history_shot_card_shot-house')), findsNothing);
    });

    testWidgets('shows filtered empty state when nothing matches', (
      tester,
    ) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('history_filter_bean')),
        'missing-bean',
      );
      await tester.pumpAndSettle();

      expect(find.text('No shots match your filters'), findsOneWidget);
      expect(find.byType(HistoryShotCard), findsNothing);
    });

    testWidgets('clear filters restores full history list', (tester) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('history_filter_bean')),
        'ethiopia',
      );
      await tester.pumpAndSettle();
      expect(find.byType(HistoryShotCard), findsOneWidget);

      await tester.tap(find.byKey(const Key('history_filter_clear')));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryShotCard), findsNWidgets(2));
    });

    testWidgets('tag filter updates visible history cards', (tester) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_filter_tag_tag-practice')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history_shot_card_shot-ethiopia')), findsOneWidget);
      expect(find.byKey(const Key('history_shot_card_shot-house')), findsNothing);
    });
  });
}

Future<void> _seedFilterFixtures({
  required ShotRepository shotRepository,
  required BeanRepository beanRepository,
  required TagRepository tagRepository,
}) async {
  await tagRepository.upsertTag(const Tag(id: 'tag-practice', name: 'Practice'));
  await tagRepository.upsertTag(const Tag(id: 'tag-dial-in', name: 'Dial-in'));
  await beanRepository.upsertBean(
    const Bean(id: 'bean-ethiopia', name: 'Ethiopia Yirgacheffe'),
  );
  await beanRepository.upsertBean(
    const Bean(id: 'bean-house', name: 'House Blend'),
  );

  await shotRepository.insertShot(
    Shot(
      id: 'shot-ethiopia',
      startedAt: DateTime.utc(2026, 6, 29, 10),
      beanId: 'bean-ethiopia',
      tasteScore: 9,
      samples: const [
        ShotSample(elapsedMs: 0, pressureBar: 0),
        ShotSample(elapsedMs: 15000, pressureBar: 9.2),
      ],
    ),
  );
  await tagRepository.setTagsForShot('shot-ethiopia', ['tag-practice']);

  await shotRepository.insertShot(
    Shot(
      id: 'shot-house',
      startedAt: DateTime.utc(2026, 6, 28, 8),
      beanId: 'bean-house',
      tasteScore: 6,
      samples: const [
        ShotSample(elapsedMs: 0, pressureBar: 0),
        ShotSample(elapsedMs: 15000, pressureBar: 7.5),
      ],
    ),
  );
  await tagRepository.setTagsForShot('shot-house', ['tag-dial-in']);
}

Future<void> _pumpHistoryScreen(
  WidgetTester tester, {
  required ShotRepository shotRepository,
  required TagRepository tagRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HistoryScreen(
        shotRepository: shotRepository,
        tagRepository: tagRepository,
      ),
    ),
  );
}