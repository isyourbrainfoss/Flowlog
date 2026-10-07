import 'dart:async';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog_core/flowlog_core.dart';

/// Stops a forgotten brew once pressure has dropped off after a real pull.
///
/// Looks at the last ~8 samples (~800 ms). If pressure has been near zero
/// after meaningful pressure was seen, [onAutoStop] fires after a 1.5 s grace
/// so forgotten brews don't save huge zero tails. Never fires during initial
/// low-pressure pre-infusion, before the pump has built pressure, or while
/// the BLE stream is frozen (leftover ticks are not "pump off").
class LiveAutoStopGuard {
  LiveAutoStopGuard({required this.onAutoStop});

  /// Invoked when the grace timer elapses; the caller re-checks the session.
  final void Function() onAutoStop;

  /// Samples needed before the guard engages (~0.8 s at 100 ms).
  static const int minSamples = 8;

  /// Delay between "pressure dropped" and [onAutoStop].
  static const Duration grace = Duration(milliseconds: 1500);

  Timer? _timer;

  /// True while the auto-stop grace timer is pending.
  bool get isArmed => _timer != null;

  /// Re-evaluates [controller] after a sample update.
  void check(LiveShotController controller) {
    if (controller.sessionState != ShotSessionState.recording) {
      cancel();
      return;
    }

    final samples = controller.samples;
    if (samples.length < minSamples) return;

    // A frozen BLE stream (scale watchdog / radio stall) stops new samples.
    // Do not treat leftover ticks as "pump off" and kill the brew.
    final started = controller.sessionStartedAt;
    if (started != null) {
      final lastAge = DateTime.now().difference(
        started.add(Duration(milliseconds: samples.last.elapsedMs)),
      );
      if (lastAge > const Duration(milliseconds: 800)) {
        cancel();
        return;
      }
    }

    final recent = samples.sublist(samples.length - minSamples);
    final allLow = recent.every((s) => (s.pressureBar ?? 100) < 0.4);

    if (allLow) {
      final hasSeenPressure = samples.any((s) => (s.pressureBar ?? 0) >= 0.8);
      if (hasSeenPressure) {
        _timer ??= Timer(grace, () {
          onAutoStop();
          _timer = null;
        });
      } else {
        cancel();
      }
    } else {
      cancel();
    }
  }

  /// Cancels a pending auto-stop.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
