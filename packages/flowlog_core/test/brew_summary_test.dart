import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('BrewSummary', () {
    test('formats duration and peak pressure from shot', () {
      final shot = Shot(
        id: 'shot-summary',
        startedAt: DateTime.utc(2026, 7, 5, 10),
        endedAt: DateTime.utc(2026, 7, 5, 10, 0, 28, 500),
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0),
          ShotSample(elapsedMs: 12000, pressureBar: 6),
          ShotSample(elapsedMs: 28500, pressureBar: 9.2),
        ],
      );

      final summary = BrewSummary.fromShot(shot);

      expect(summary.durationMs, 28500);
      expect(summary.peakPressureBar, 9.2);
      expect(summary.formatDuration(), '28.5 s');
      expect(summary.formatPeakPressure(), '9.2 bar');
      expect(
        summary.savedMessage(),
        'Shot saved · 28.5 s · 9.2 bar peak',
      );
    });

    test('plateau average ignores depressurization tail', () {
      const samples = [
        ShotSample(elapsedMs: 0, pressureBar: 0.5),
        ShotSample(elapsedMs: 5000, pressureBar: 8.8),
        ShotSample(elapsedMs: 10000, pressureBar: 9.0),
        ShotSample(elapsedMs: 15000, pressureBar: 9.1),
        ShotSample(elapsedMs: 20000, pressureBar: 8.9),
        ShotSample(elapsedMs: 25000, pressureBar: 0.2),
        ShotSample(elapsedMs: 28000, pressureBar: 0.0),
      ];
      final hold = plateauAveragePressureBar(samples);
      expect(hold, isNotNull);
      expect(hold!, greaterThan(8.5));
      expect(hold, lessThan(9.5));
      expect(samples.last.pressureBar, 0.0);
    });
  });
}