import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShotDetailScreen', () {
    late FlowlogDatabase db;
    late ShotRepository repository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('shows DualCurveChart and read-only metadata from fixture', (
      tester,
    ) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(
            shot: shot,
            shotRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('shot_detail_${shot.id}')), findsOneWidget);
      expect(find.byType(DualCurveChart), findsOneWidget);

      final chart = tester.widget<DualCurveChart>(find.byType(DualCurveChart));
      expect(chart.samples, shot.samples);
      expect(chart.maxDurationMs, shot.endedAt!.difference(shot.startedAt).inMilliseconds);

      expect(find.text('Metadata'), findsOneWidget);
      expect(find.text('18.0 g'), findsOneWidget);
      expect(find.text('36.0 g'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('93.0 °C'), findsOneWidget);
      expect(find.text('bean-house-blend'), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
      expect(
        find.text('Minimal fixture shot for tests and mock replay.'),
        findsOneWidget,
      );
      expect(find.text('chocolate'), findsOneWidget);
      expect(find.text('nutty'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete brew removes shot and closes detail', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await repository.insertShot(shot);

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(
            shot: shot,
            shotRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shot_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ShotDetailScreen), findsNothing);
      expect(await repository.listShots(), isEmpty);
    });
  });
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