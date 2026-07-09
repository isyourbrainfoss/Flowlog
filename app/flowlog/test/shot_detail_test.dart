import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final beanRepository = BeanRepository(db);
      await beanRepository.upsertBean(
        const Bean(id: 'bean-house-blend', name: 'House Blend'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(
            shot: shot,
            shotRepository: repository,
            beanRepository: beanRepository,
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
      expect(find.text('14.0'), findsOneWidget);
      expect(find.text('93.0 °C'), findsOneWidget);
      expect(find.text('House Blend'), findsOneWidget);
      expect(find.text('bean-house-blend'), findsNothing);
      expect(find.byKey(const Key('flavour_profile_section')), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_taste_value')), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_tags')), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_tag_chocolate')), findsOneWidget);
      expect(find.byKey(const Key('flavour_profile_tag_nutty')), findsOneWidget);
      expect(
        find.text('Minimal fixture shot for tests and mock replay.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('shot_ai_flavor_goal')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows inferred metadata when shot fields are unset', (
      tester,
    ) async {
      final shot = Shot(
        id: 'sparse-shot',
        startedAt: DateTime.utc(2026, 6, 29, 10),
        endedAt: DateTime.utc(2026, 6, 29, 10, 0, 28),
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0, tempC: 92.0),
          ShotSample(elapsedMs: 15000, pressureBar: 9, weightG: 36.2, tempC: 93.5),
        ],
      );
      await repository.insertShot(shot);

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(
            shot: shot,
            shotRepository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('${kDefaultBrewDoseG.toStringAsFixed(1)} g'), findsOneWidget);
      expect(find.text('36.2 g'), findsOneWidget);
      expect(find.text('93.5 °C'), findsOneWidget);
      expect(find.text(formatGrindSetting(kDefaultBrewGrindSetting)), findsOneWidget);
      expect(
        find.text('${kDefaultCoffeejackRewindTurns} turns'),
        findsOneWidget,
      );
      expect(
        find.text('${kDefaultCoffeejackPreinfusionTurns} slow turns'),
        findsOneWidget,
      );
    });

    testWidgets('shows stored coffeejack turns from shot record', (tester) async {
      final shot = Shot(
        id: 'turns-shot',
        startedAt: DateTime.utc(2026, 6, 29, 10),
        endedAt: DateTime.utc(2026, 6, 29, 10, 0, 28),
        doseG: 18,
        yieldG: 36,
        coffeejackRewindTurns: 11,
        coffeejackPreinfusionTurns: 7,
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
          ShotSample(elapsedMs: 15000, pressureBar: 9, weightG: 36),
        ],
      );
      await repository.insertShot(shot);

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(
            shot: shot,
            shotRepository: repository,
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('11 turns'), findsOneWidget);
      expect(find.text('7 slow turns'), findsOneWidget);
    });

    testWidgets('copies shot data for AI feedback', (tester) async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final beanRepository = BeanRepository(db);
      await beanRepository.upsertBean(
        const Bean(
          id: 'bean-house-blend',
          name: 'House Blend',
          origin: 'Brazil',
        ),
      );

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardText =
                (methodCall.arguments as Map<Object?, Object?>)['text']
                    as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ShotDetailScreen(
            shot: shot,
            shotRepository: repository,
            beanRepository: beanRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('shot_ai_flavor_goal')),
        'more sweetness',
      );
      await tester.tap(find.byKey(const Key('shot_copy_ai_feedback_button')));
      await tester.pumpAndSettle();

      expect(clipboardText, isNotNull);
      expect(clipboardText, contains('flowlog-shot-ai-feedback-v1'));
      expect(clipboardText, contains('more sweetness'));
      expect(clipboardText, contains('House Blend'));
      expect(
        find.byKey(const Key('shot_ai_feedback_copied_snackbar')),
        findsOneWidget,
      );
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