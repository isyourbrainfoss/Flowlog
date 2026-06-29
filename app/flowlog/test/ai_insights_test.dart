import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/library/ai_insights.dart';
import 'package:flowlog/screens/library_screen.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('suggestTweaksFromTasteNotes', () {
    test('returns empty list for blank notes', () {
      expect(suggestTweaksFromTasteNotes(''), isEmpty);
      expect(suggestTweaksFromTasteNotes('   '), isEmpty);
    });

    test('matches sour and thin keywords', () {
      final suggestions = suggestTweaksFromTasteNotes(
        'Cup tastes a bit SOUR with a thin body.',
      );

      expect(suggestions, hasLength(2));
      expect(suggestions.map((s) => s.keyword), containsAll(['sour', 'thin']));
      expect(
        suggestions.firstWhere((s) => s.keyword == 'sour').hint,
        contains('finer grind'),
      );
    });

    test('matches bitter keyword', () {
      final suggestions = suggestTweaksFromTasteNotes('Too bitter and harsh');

      expect(suggestions.map((s) => s.keyword), containsAll(['bitter', 'harsh']));
    });

    test('matches channeling keyword', () {
      final suggestions = suggestTweaksFromTasteNotes('Seeing channeling on the puck');

      expect(suggestions.single.keyword, 'channeling');
      expect(suggestions.single.hint, contains('WDT'));
    });

    test('matches watery keyword', () {
      final suggestions = suggestTweaksFromTasteNotes('Feels watery in the finish');

      expect(suggestions.single.keyword, 'watery');
    });
  });

  group('detectCurveAnomalies', () {
    test('returns empty for fewer than two samples', () {
      expect(
        detectCurveAnomalies(const [
          ShotSample(elapsedMs: 0, pressureBar: 9, flowGs: 1.0),
        ]),
        isEmpty,
      );
    });

    test('detects sudden pressure drop', () {
      final hints = detectCurveAnomalies(const [
        ShotSample(elapsedMs: 0, pressureBar: 9.0, flowGs: 1.0),
        ShotSample(elapsedMs: 1000, pressureBar: 6.0, flowGs: 1.1),
      ]);

      expect(hints, hasLength(1));
      expect(hints.single.kind, CurveAnomalyKind.suddenPressureDrop);
      expect(hints.single.title, 'Sudden pressure drop');
      expect(hints.single.elapsedMs, 1000);
    });

    test('detects flat flow plateau', () {
      final hints = detectCurveAnomalies(const [
        ShotSample(elapsedMs: 0, pressureBar: 9.0, flowGs: 1.0),
        ShotSample(elapsedMs: 2000, pressureBar: 8.5, flowGs: 1.0),
        ShotSample(elapsedMs: 4000, pressureBar: 8.0, flowGs: 1.01),
        ShotSample(elapsedMs: 7000, pressureBar: 7.5, flowGs: 1.0),
      ]);

      expect(
        hints.where((h) => h.kind == CurveAnomalyKind.flatFlow),
        hasLength(1),
      );
    });

    test('detects early high flow', () {
      final hints = detectCurveAnomalies(const [
        ShotSample(elapsedMs: 0, pressureBar: 3.0, flowGs: 3.0),
        ShotSample(elapsedMs: 5000, pressureBar: 9.0, flowGs: 1.2),
        ShotSample(elapsedMs: 20000, pressureBar: 8.0, flowGs: 1.0),
      ]);

      expect(
        hints.where((h) => h.kind == CurveAnomalyKind.earlyHighFlow),
        hasLength(1),
      );
    });

    test('returns no anomalies for a normal ramp', () {
      final hints = detectCurveAnomalies(const [
        ShotSample(elapsedMs: 0, pressureBar: 0.0, flowGs: 0.0),
        ShotSample(elapsedMs: 5000, pressureBar: 3.0, flowGs: 0.8),
        ShotSample(elapsedMs: 10000, pressureBar: 9.0, flowGs: 1.2),
        ShotSample(elapsedMs: 25000, pressureBar: 8.0, flowGs: 1.4),
      ]);

      expect(hints, isEmpty);
    });
  });

  group('AiInsightsScreen', () {
    late FlowlogDatabase db;
    late ShotRepository shotRepository;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      shotRepository = ShotRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders taste notes and empty anomaly state without shots', (tester) async {
      await _pumpAiInsightsScreen(tester, shotRepository: shotRepository);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_insights_list')), findsOneWidget);
      expect(find.byKey(const Key('ai_insights_taste_notes')), findsOneWidget);
      expect(find.byKey(const Key('ai_insights_tweaks')), findsOneWidget);
      expect(find.byKey(const Key('ai_insights_anomalies')), findsOneWidget);
      expect(find.text('Taste notes'), findsOneWidget);
      expect(find.text('Tweak suggestions'), findsOneWidget);
      expect(find.text('Curve anomalies'), findsOneWidget);
      expect(
        find.text('Save a shot with samples to analyze the curve'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows tweak suggestions when taste notes are entered', (tester) async {
      await _pumpAiInsightsScreen(tester, shotRepository: shotRepository);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('ai_insights_taste_notes_field')),
        'sour and channeling',
      );
      await tester.pump();

      expect(find.byKey(const Key('ai_insights_tweak_sour')), findsOneWidget);
      expect(find.byKey(const Key('ai_insights_tweak_channeling')), findsOneWidget);
      expect(find.text('Sour / under-extracted'), findsOneWidget);
      expect(find.text('Channeling'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows anomaly hints from latest saved shot', (tester) async {
      await shotRepository.insertShot(
        Shot(
          id: 'shot-pressure-drop',
          startedAt: DateTime.utc(2026, 6, 29, 10),
          samples: const [
            ShotSample(elapsedMs: 0, pressureBar: 9.0, flowGs: 1.0),
            ShotSample(elapsedMs: 1000, pressureBar: 6.0, flowGs: 1.1),
          ],
        ),
      );

      await _pumpAiInsightsScreen(tester, shotRepository: shotRepository);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ai_insights_anomaly_suddenPressureDrop')),
        findsOneWidget,
      );
      expect(find.text('Sudden pressure drop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('prefills taste notes from latest shot', (tester) async {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      await shotRepository.insertShot(shot);

      await _pumpAiInsightsScreen(tester, shotRepository: shotRepository);
      await tester.pumpAndSettle();

      expect(
        find.text('Minimal fixture shot for tests and mock replay.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('LibraryScreen', () {
    testWidgets('exposes AI Coach tab in library', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LibraryScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('library_tab_ai_coach')), findsOneWidget);

      await tester.tap(find.byKey(const Key('library_tab_ai_coach')));
      await tester.pumpAndSettle();

      expect(find.byType(AiInsightsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpAiInsightsScreen(
  WidgetTester tester, {
  required ShotRepository shotRepository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AiInsightsScreen(shotRepository: shotRepository),
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