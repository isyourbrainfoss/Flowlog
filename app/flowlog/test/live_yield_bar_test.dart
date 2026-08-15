import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldFireYieldWarn', () {
    test('fires once when weight crosses warn level', () {
      expect(
        shouldFireYieldWarn(
          weightG: 31.9,
          warnAtG: 32,
          targetYieldG: 36,
          alreadyFired: false,
        ),
        isFalse,
      );
      expect(
        shouldFireYieldWarn(
          weightG: 32.0,
          warnAtG: 32,
          targetYieldG: 36,
          alreadyFired: false,
        ),
        isTrue,
      );
      expect(
        shouldFireYieldWarn(
          weightG: 34.0,
          warnAtG: 32,
          targetYieldG: 36,
          alreadyFired: true,
        ),
        isFalse,
      );
    });

    test('ignores null weight', () {
      expect(
        shouldFireYieldWarn(
          weightG: null,
          warnAtG: 32,
          targetYieldG: 36,
          alreadyFired: false,
        ),
        isFalse,
      );
    });
  });

  group('LiveYieldProgress', () {
    testWidgets('does not show no-weight banner when a reading is on screen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveYieldProgress(
              weightG: 18.4,
              targetYieldG: 36,
              warnAtG: 32,
              weightHealth: WeightStreamHealth.linkedNoWeight,
            ),
          ),
        ),
      );

      expect(find.text('18.4 g'), findsOneWidget);
      expect(find.byKey(const Key('live_yield_no_weight_banner')), findsNothing);
      expect(find.text('No weight'), findsNothing);
    });

    testWidgets('shows no-weight banner only when there is no reading',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveYieldProgress(
              weightG: null,
              targetYieldG: 36,
              warnAtG: 32,
              weightHealth: WeightStreamHealth.linkedNoWeight,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('live_yield_no_weight_banner')), findsOneWidget);
      expect(find.text('No weight'), findsOneWidget);
    });
  });

  group('resolveWeightStreamHealth', () {
    test('treats a recent packet as live during brew', () {
      expect(
        resolveWeightStreamHealth(
          scalePaired: true,
          scaleLinked: true,
          isBrewing: true,
          shotHasWeight: true,
          lastWeightReceiveMs: 10_000,
          nowMs: 12_000,
        ),
        WeightStreamHealth.live,
      );
    });

    test('does not alarm in the first seconds before any packet', () {
      expect(
        resolveWeightStreamHealth(
          scalePaired: true,
          scaleLinked: true,
          isBrewing: true,
          shotHasWeight: false,
          lastWeightReceiveMs: null,
          nowMs: 2_000,
          brewElapsed: const Duration(seconds: 2),
        ),
        WeightStreamHealth.live,
      );
    });

    test('flags a long silent gap mid-brew', () {
      expect(
        resolveWeightStreamHealth(
          scalePaired: true,
          scaleLinked: true,
          isBrewing: true,
          shotHasWeight: true,
          lastWeightReceiveMs: 1_000,
          nowMs: 10_000,
        ),
        WeightStreamHealth.linkedNoWeight,
      );
    });

    test('does not flag missing stream after the shot already has weight', () {
      expect(
        resolveWeightStreamHealth(
          scalePaired: true,
          scaleLinked: true,
          isBrewing: false,
          shotHasWeight: true,
          lastWeightReceiveMs: null,
          nowMs: 30_000,
        ),
        WeightStreamHealth.live,
      );
    });
  });

  group('LiveYieldProgress display', () {
    testWidgets('shows large weight digit and warn banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LiveYieldProgress(
              weightG: 32.5,
              targetYieldG: 36,
              warnAtG: 32,
              showWarnBanner: true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('live_yield_progress')), findsOneWidget);
      expect(find.byKey(const Key('live_yield_weight_digit')), findsOneWidget);
      expect(find.text('32.5 g'), findsOneWidget);
      expect(find.byKey(const Key('live_yield_warn_banner')), findsOneWidget);
      expect(find.textContaining('wind back'), findsOneWidget);
    });
  });
}
