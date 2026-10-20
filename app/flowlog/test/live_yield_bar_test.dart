import 'package:flowlog/screens/live/live_pressure_bar.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
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
    testWidgets('shows stale-stream banner even when last grams are on screen',
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
      expect(find.byKey(const Key('live_yield_no_weight_banner')), findsOneWidget);
      expect(find.textContaining('not updating'), findsOneWidget);
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

  group('LivePressureDeviationBar', () {
    testWidgets('does not treat 9 bar as a target when none is set',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivePressureDeviationBar(
              currentPressure: 6.0,
              targetPressure: null,
            ),
          ),
        ),
      );

      expect(find.textContaining('6.0 bar'), findsOneWidget);
      expect(find.textContaining('/ 9'), findsNothing);
      expect(find.byKey(const Key('live_pressure_no_target')), findsOneWidget);
      expect(find.byKey(const Key('live_pressure_deviation_bar')), findsNothing);
    });

    testWidgets('shows deviation bar when a target is set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LivePressureDeviationBar(
              currentPressure: 8.5,
              targetPressure: 9.0,
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('live_pressure_deviation_bar')), findsOneWidget);
      expect(find.byKey(const Key('live_pressure_no_target')), findsNothing);
      expect(find.textContaining('/ 9.0'), findsOneWidget);
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

  group('LiveYieldProgress contrast', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final entry in {
      'light': FlowlogTheme.cafeLight,
      'dark': FlowlogTheme.coffeeDark,
    }.entries) {
      testWidgets('warn-state weight digit is readable (${entry.key})', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: const Scaffold(
              body: LiveYieldProgress(
                weightG: 33,
                targetYieldG: 36,
                warnAtG: 32,
              ),
            ),
          ),
        );
        final digit = tester.widget<Text>(
          find.byKey(const Key('live_yield_weight_digit')),
        );
        final color = digit.style!.color!;
        final surface = entry.value.colorScheme.surface;
        // WCAG AA for large text is 3:1; aim for normal-text 4.5:1.
        expect(contrast(color, surface), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
