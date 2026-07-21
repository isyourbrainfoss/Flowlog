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
