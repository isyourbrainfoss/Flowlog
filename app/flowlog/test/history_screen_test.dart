import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog/screens/history_screen.dart';
import 'package:flowlog/shell/shot_events.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoryScreen', () {
    late FlowlogDatabase db;
    late ShotRepository repository;
    late TagRepository tagRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
      tagRepository = TagRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows empty state when no shots are saved', (tester) async {
      await _pumpHistoryScreen(
        tester,
        shotRepository: repository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved shots yet'), findsOneWidget);
      expect(find.byType(HistoryShotCard), findsNothing);
    });

    testWidgets('lists seeded fixture shot with sparkline and metrics', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await repository.insertShot(shot);

      await _pumpHistoryScreen(
        tester,
        shotRepository: repository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('history_shot_card_${shot.id}')), findsOneWidget);
      expect(find.byType(SparklineChart), findsOneWidget);
      expect(find.text('9.0 bar'), findsOneWidget);
      expect(find.text('36.0 g'), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deletes brew from history after confirmation', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await repository.insertShot(shot);

      await _pumpHistoryScreen(
        tester,
        shotRepository: repository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('history_delete_${shot.id}')));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('history_delete_dialog_${shot.id}')), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('history_shot_card_${shot.id}')), findsNothing);
      expect(await repository.listShots(), isEmpty);
      expect(find.text('Brew deleted'), findsOneWidget);
    });

    testWidgets('navigates to shot detail when card is tapped', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await repository.insertShot(shot);

      await _pumpHistoryScreen(
        tester,
        shotRepository: repository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('history_shot_card_${shot.id}')));
      await tester.pumpAndSettle();

      expect(find.byType(ShotDetailScreen), findsOneWidget);
      expect(find.byKey(Key('shot_detail_${shot.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('refreshes list when shot events notifier fires', (
      tester,
    ) async {
      final events = ShotEventsNotifier();
      await _pumpHistoryScreen(
        tester,
        shotRepository: repository,
        tagRepository: tagRepository,
        shotEventsNotifier: events,
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved shots yet'), findsOneWidget);

      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await repository.insertShot(shot);
      events.notifyShotsChanged();
      await tester.pumpAndSettle();

      expect(find.byKey(Key('history_shot_card_${shot.id}')), findsOneWidget);
    });

    testWidgets('sorts shots by startedAt descending', (tester) async {
      final older = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        id: 'shot-older',
        startedAt: DateTime.utc(2026, 6, 28, 8),
      );
      final newer = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        id: 'shot-newer',
        startedAt: DateTime.utc(2026, 6, 29, 12),
      );

      await repository.insertShot(older);
      await repository.insertShot(newer);

      await _pumpHistoryScreen(
        tester,
        shotRepository: repository,
        tagRepository: tagRepository,
      );
      await tester.pumpAndSettle();

      final cards = tester.widgetList<HistoryShotCard>(
        find.byType(HistoryShotCard),
      );
      expect(cards.length, 2);
      expect(cards.first.shot.id, 'shot-newer');
      expect(cards.last.shot.id, 'shot-older');
    });
  });

  group('ShotRepository.listShots', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns shots ordered by startedAt desc', () async {
      final older = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        id: 'shot-older',
        startedAt: DateTime.utc(2026, 6, 28, 8),
      );
      final newer = _loadFixtureShot('shots/minimal_shot.json').copyWith(
        id: 'shot-newer',
        startedAt: DateTime.utc(2026, 6, 29, 12),
      );

      await repository.insertShot(older);
      await repository.insertShot(newer);

      final listed = await repository.listShots();
      expect(listed.map((shot) => shot.id).toList(), ['shot-newer', 'shot-older']);
    });
  });
}

Future<void> _pumpHistoryScreen(
  WidgetTester tester, {
  required ShotRepository shotRepository,
  required TagRepository tagRepository,
  ShotEventsNotifier? shotEventsNotifier,
}) async {
  final history = HistoryScreen(
    shotRepository: shotRepository,
    tagRepository: tagRepository,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: shotEventsNotifier == null
            ? history
            : ShotEventsScope(
                notifier: shotEventsNotifier,
                child: history,
              ),
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