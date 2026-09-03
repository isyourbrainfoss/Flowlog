import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoryShotCard', () {
    testWidgets('shows bean label and grind with existing metrics', (
      tester,
    ) async {
      final shot = _cardShot(grindSetting: 3.2);
      await _pumpCard(
        tester,
        HistoryShotCard(shot: shot, beanLabel: 'Ethiopia'),
      );

      expect(find.byKey(Key('history_shot_meta_${shot.id}')), findsOneWidget);
      expect(find.byKey(Key('history_shot_bean_${shot.id}')), findsOneWidget);
      expect(find.byKey(Key('history_shot_grind_${shot.id}')), findsOneWidget);
      expect(find.text('Ethiopia'), findsOneWidget);
      expect(find.text('Grind 3.2'), findsOneWidget);
      expect(find.text('Peak P'), findsOneWidget);
      expect(find.text('Yield'), findsOneWidget);
      expect(find.text('Taste'), findsOneWidget);
      expect(find.text('9.0 bar'), findsOneWidget);
      expect(find.text('36.0 g'), findsOneWidget);
      expect(find.text('7/10'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(Key('history_shot_meta_${shot.id}'))).label,
        'Bean Ethiopia. Grind 3.2',
      );
    });

    testWidgets('hides meta row when bean and grind are missing', (
      tester,
    ) async {
      final shot = _cardShot(grindSetting: null);
      await _pumpCard(tester, HistoryShotCard(shot: shot));

      expect(find.byKey(Key('history_shot_meta_${shot.id}')), findsNothing);
      expect(find.byKey(Key('history_shot_bean_${shot.id}')), findsNothing);
      expect(find.byKey(Key('history_shot_grind_${shot.id}')), findsNothing);
      expect(find.text('Peak P'), findsOneWidget);
      expect(find.text('Yield'), findsOneWidget);
      expect(find.text('Taste'), findsOneWidget);
    });

    testWidgets('hides meta row when beanLabel is empty and grind is missing', (
      tester,
    ) async {
      final shot = _cardShot(grindSetting: null);
      await _pumpCard(
        tester,
        HistoryShotCard(shot: shot, beanLabel: '  '),
      );

      expect(find.byKey(Key('history_shot_meta_${shot.id}')), findsNothing);
    });

    testWidgets('shows grind only with empty leading space', (tester) async {
      final shot = _cardShot(grindSetting: 3.2);
      await _pumpCard(tester, HistoryShotCard(shot: shot));

      expect(find.byKey(Key('history_shot_meta_${shot.id}')), findsOneWidget);
      expect(find.byKey(Key('history_shot_bean_${shot.id}')), findsNothing);
      expect(find.byKey(Key('history_shot_grind_${shot.id}')), findsOneWidget);
      expect(find.text('Grind 3.2'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(Key('history_shot_meta_${shot.id}'))).label,
        'Grind 3.2',
      );
    });

    testWidgets('shows bean only at full width without grind', (tester) async {
      final shot = _cardShot(grindSetting: null);
      await _pumpCard(
        tester,
        HistoryShotCard(shot: shot, beanLabel: 'Ethiopia'),
      );

      expect(find.byKey(Key('history_shot_meta_${shot.id}')), findsOneWidget);
      expect(find.byKey(Key('history_shot_bean_${shot.id}')), findsOneWidget);
      expect(find.byKey(Key('history_shot_grind_${shot.id}')), findsNothing);
      expect(find.text('Ethiopia'), findsOneWidget);
      expect(find.textContaining('Grind'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(Key('history_shot_meta_${shot.id}'))).label,
        'Bean Ethiopia',
      );
    });

    testWidgets('compact 400x800 still shows bean grind and metrics', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shot = _cardShot(grindSetting: 3.2);
      await _pumpCard(
        tester,
        HistoryShotCard(shot: shot, beanLabel: 'Ethiopia'),
      );

      expect(find.text('Ethiopia'), findsOneWidget);
      expect(find.text('Grind 3.2'), findsOneWidget);
      expect(find.text('Peak P'), findsOneWidget);
      expect(find.text('Yield'), findsOneWidget);
      expect(find.text('Taste'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Shot _cardShot({double? grindSetting}) {
  return Shot(
    id: 'shot-card',
    startedAt: DateTime.utc(2026, 6, 29, 10),
    yieldG: 36,
    grindSetting: grindSetting,
    tasteScore: 7,
    samples: const [
      ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0),
      ShotSample(elapsedMs: 15000, pressureBar: 9.0, weightG: 36),
    ],
  );
}

Future<void> _pumpCard(WidgetTester tester, HistoryShotCard card) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: card),
    ),
  );
}
