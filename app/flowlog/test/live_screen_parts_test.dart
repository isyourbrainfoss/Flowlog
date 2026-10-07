import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/live_auto_stop.dart';
import 'package:flowlog/screens/live/live_brew_complete_overlay.dart';
import 'package:flowlog/screens/live/live_brew_hud.dart';
import 'package:flowlog/screens/live/live_target_gamification.dart';
import 'package:flowlog/screens/live/live_yield_warn.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal controller stand-in for the extracted Live helpers.
class _FakeLiveController extends Fake implements LiveShotController {
  _FakeLiveController({
    this.sessionState = ShotSessionState.recording,
    List<ShotSample>? samples,
    this.sessionStartedAt,
  }) : samples = samples ?? [];

  @override
  ShotSessionState sessionState;

  @override
  List<ShotSample> samples;

  @override
  DateTime? sessionStartedAt;

  @override
  bool get isBrewing =>
      sessionState == ShotSessionState.recording ||
      sessionState == ShotSessionState.paused;
}

List<ShotSample> _pressureRun(List<double?> bars, {int stepMs = 100}) => [
  for (var i = 0; i < bars.length; i++)
    ShotSample(elapsedMs: i * stepMs, pressureBar: bars[i]),
];

void main() {
  group('brew HUD formatters', () {
    test('formatBrewElapsed renders m:ss', () {
      expect(formatBrewElapsed(null), '0:00');
      expect(formatBrewElapsed(9_999), '0:09');
      expect(formatBrewElapsed(75_400), '1:15');
    });

    test('formatBrewFlow renders one decimal or a dash', () {
      expect(formatBrewFlow(null), '— g/s');
      expect(formatBrewFlow(2.04), '2.0 g/s');
    });
  });

  group('LiveAutoStopGuard', () {
    test('arms after pressure drops off and fires once', () async {
      var stops = 0;
      final guard = LiveAutoStopGuard(onAutoStop: () => stops += 1);
      addTearDown(guard.dispose);

      final samples = _pressureRun([
        9, 9, 9, 9, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, //
      ]);
      final controller = _FakeLiveController(
        samples: samples,
        // Last sample is "now" so the stream is not considered frozen.
        sessionStartedAt: DateTime.now().subtract(
          Duration(milliseconds: samples.last.elapsedMs),
        ),
      );

      guard.check(controller);
      expect(guard.isArmed, isTrue);
      await Future<void>.delayed(
        LiveAutoStopGuard.grace + const Duration(milliseconds: 50),
      );
      expect(stops, 1);
      expect(guard.isArmed, isFalse);
    });

    test('ignores pre-infusion that never built pressure', () {
      final guard = LiveAutoStopGuard(onAutoStop: () {});
      addTearDown(guard.dispose);
      final samples = _pressureRun(List<double?>.filled(10, 0.2));
      guard.check(
        _FakeLiveController(
          samples: samples,
          sessionStartedAt: DateTime.now().subtract(
            Duration(milliseconds: samples.last.elapsedMs),
          ),
        ),
      );
      expect(guard.isArmed, isFalse);
    });

    test('does not treat a frozen stream as pump off', () {
      final guard = LiveAutoStopGuard(onAutoStop: () {});
      addTearDown(guard.dispose);
      guard.check(
        _FakeLiveController(
          samples: _pressureRun([9, 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
          // Last sample is ~5 s old.
          sessionStartedAt: DateTime.now().subtract(
            const Duration(seconds: 6),
          ),
        ),
      );
      expect(guard.isArmed, isFalse);
    });

    test('cancels when the session leaves recording', () {
      final guard = LiveAutoStopGuard(onAutoStop: () {});
      addTearDown(guard.dispose);
      final samples = _pressureRun([9, 9, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      final controller = _FakeLiveController(
        samples: samples,
        sessionStartedAt: DateTime.now().subtract(
          Duration(milliseconds: samples.last.elapsedMs),
        ),
      );
      guard.check(controller);
      expect(guard.isArmed, isTrue);
      controller.sessionState = ShotSessionState.stopped;
      guard.check(controller);
      expect(guard.isArmed, isFalse);
    });
  });

  group('LiveYieldWarnTracker', () {
    const defaults = BrewDefaultsSettings(
      targetYieldG: 36,
      yieldWarnAtG: 32,
    );

    test('fires once per brew at the warn level', () {
      final tracker = LiveYieldWarnTracker();
      final controller = _FakeLiveController(
        samples: [const ShotSample(elapsedMs: 0, weightG: 20)],
      );
      expect(
        tracker.check(controller, defaults: defaults, fallbackWeightG: null),
        isFalse,
      );

      controller.samples = [const ShotSample(elapsedMs: 100, weightG: 33)];
      expect(
        tracker.check(controller, defaults: defaults, fallbackWeightG: null),
        isTrue,
      );
      expect(tracker.fired, isTrue);
      expect(
        tracker.check(controller, defaults: defaults, fallbackWeightG: null),
        isFalse,
      );

      tracker.reset();
      expect(tracker.fired, isFalse);
    });

    test('uses fallback weight when the newest sample has none', () {
      final tracker = LiveYieldWarnTracker();
      final controller = _FakeLiveController(
        samples: [const ShotSample(elapsedMs: 0, pressureBar: 9)],
      );
      expect(
        tracker.check(controller, defaults: defaults, fallbackWeightG: 34),
        isTrue,
      );
    });

    test('respects disabled alerts and idle sessions', () {
      final tracker = LiveYieldWarnTracker();
      final brewing = _FakeLiveController(
        samples: [const ShotSample(elapsedMs: 0, weightG: 35)],
      );
      expect(
        tracker.check(
          brewing,
          defaults: defaults.copyWith(yieldAlertEnabled: false),
          fallbackWeightG: null,
        ),
        isFalse,
      );
      final idle = _FakeLiveController(
        sessionState: ShotSessionState.stopped,
        samples: [const ShotSample(elapsedMs: 0, weightG: 35)],
      );
      expect(
        tracker.check(idle, defaults: defaults, fallbackWeightG: null),
        isFalse,
      );
    });
  });

  group('BrewCompleteBannerController', () {
    const summary = BrewSummary(
      durationMs: 28_000,
    );

    test('show/dismiss notify and auto-dismiss clears the summary', () async {
      final banner = BrewCompleteBannerController(
        autoDismiss: const Duration(milliseconds: 30),
      );
      addTearDown(banner.dispose);
      var notifications = 0;
      banner.addListener(() => notifications += 1);

      banner.show(summary);
      expect(banner.isVisible, isTrue);
      expect(notifications, 1);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(banner.summary, isNull);
      expect(notifications, 2);

      banner.dismiss();
      expect(notifications, 2, reason: 'already hidden');
    });

    test('dismiss after dispose is a safe no-op', () {
      final banner = BrewCompleteBannerController()..show(summary);
      banner.dispose();
      expect(banner.dismiss, returnsNormally);
    });
  });

  group('LiveTargetGamification', () {
    test('stats are empty unless stopped with a target curve', () {
      final samples = _pressureRun([9, 9, 9]);
      expect(
        identical(
          LiveTargetGamificationStats.forSession(
            state: ShotSessionState.recording,
            samples: samples,
            targets: samples,
          ),
          LiveTargetGamificationStats.empty,
        ),
        isTrue,
      );
      expect(
        identical(
          LiveTargetGamificationStats.forSession(
            state: ShotSessionState.stopped,
            samples: samples,
            targets: const [],
          ),
          LiveTargetGamificationStats.empty,
        ),
        isTrue,
      );
      final stats = LiveTargetGamificationStats.forSession(
        state: ShotSessionState.stopped,
        samples: samples,
        targets: samples,
      );
      expect(stats.closeness, isNotNull);
    });

    testWidgets('renders pills, hides when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowlogTheme.coffeeDark,
          home: const Scaffold(
            body: Column(
              children: [
                LiveTargetGamification(
                  stats: LiveTargetGamificationStats(
                    closeness: 87,
                    maxStreakSec: 9,
                    currentStreakSec: 4,
                    penaltyCount: 2,
                    score: 91,
                  ),
                ),
                LiveTargetGamification(
                  stats: LiveTargetGamificationStats.empty,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('87%'), findsOneWidget);
      expect(find.text('4s / 9s'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('91'), findsOneWidget);
      expect(find.byIcon(Icons.track_changes), findsOneWidget);
    });
  });
}
