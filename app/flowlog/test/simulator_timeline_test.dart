import 'dart:io';

import 'package:flowlog/screens/library/simulator.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show MockReplayAdapter;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timeline hold', () {
    const keyframes = [
      PressureKeyframe(elapsedMs: 0, pressureBar: 0),
      PressureKeyframe(elapsedMs: 15000, pressureBar: 9),
    ];

    test('expandKeyframesToProfile holds the last pressure to the end', () {
      final profile = expandKeyframesToProfile(keyframes, holdUntilMs: 30000);
      expect(profile.last.elapsedMs, 30000);
      expect(profile.last.pressureBar, 9);
      expect(pressureAtElapsedMs(22000, profile), 9);
    });

    test('without holdUntilMs the profile ends at the last keyframe', () {
      expect(expandKeyframesToProfile(keyframes).last.elapsedMs, 15000);
      expect(
        expandKeyframesToProfile(keyframes, holdUntilMs: 5000).last.elapsedMs,
        15000,
      );
    });

    test('profileFromKeyframes covers the whole timeline', () {
      final profile = profileFromKeyframes(keyframes, holdUntilMs: 30000);
      expect(profile.pressureSamples.last.elapsedMs, 30000);
    });
  });

  test(
    'keyframes from a real shot keep the pre-infusion knee and the hold',
    () {
      final file = ['../../fixtures', '../../../fixtures']
          .map((d) => File('$d/sensor_streams/demo_shot.jsonl'))
          .firstWhere((f) => f.existsSync());
      final samples = [
        for (final s in MockReplayAdapter.parseLines(file.readAsLinesSync()))
          ShotSample(elapsedMs: s.elapsedMs, pressureBar: s.pressureBar),
      ];

      final kfs = extractPressureKeyframesFromSamples(
        samples,
        durationMs: 30000,
      );

      expect(kfs.first.elapsedMs, 0);
      expect(kfs.length, lessThanOrEqualTo(12));
      // Pre-infusion knee (~4 s, ~2.5 bar) before the ramp.
      expect(
        kfs.any(
          (k) =>
              k.elapsedMs > 1000 &&
              k.elapsedMs < 6000 &&
              k.pressureBar > 1 &&
              k.pressureBar < 4,
        ),
        isTrue,
        reason: '$kfs',
      );
      // The ~9 bar hold must still be there late in the shot, not a slope.
      expect(
        kfs.any((k) => k.elapsedMs > 20000 && k.pressureBar > 8),
        isTrue,
        reason: '$kfs',
      );
      // Every point stays within ~0.6 bar of the real curve.
      final profile = expandKeyframesToProfile(kfs, stepMs: 100);
      for (final s in samples) {
        final p = pressureAtElapsedMs(s.elapsedMs, profile)!;
        expect(
          (p - s.pressureBar!).abs(),
          lessThan(1.2),
          reason: 't=${s.elapsedMs}',
        );
      }
      // Keyframes respect the editor's minimum spacing.
      for (var i = 1; i < kfs.length; i++) {
        expect(
          kfs[i].elapsedMs - kfs[i - 1].elapsedMs,
          greaterThanOrEqualTo(kSimulatorMinKeyframeSpacingMs),
          reason: '$kfs',
        );
      }
    },
  );
}
