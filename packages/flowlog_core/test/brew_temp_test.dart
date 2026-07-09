import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('brewTempRangeFromSamples', () {
    test('returns first and last in-shot temperatures', () {
      final range = brewTempRangeFromSamples(const [
        ShotSample(elapsedMs: 0, pressureBar: 0, tempC: 91.5),
        ShotSample(elapsedMs: 1000, pressureBar: 3, tempC: 92.0),
        ShotSample(elapsedMs: 2000, pressureBar: 9, tempC: 93.4),
        ShotSample(elapsedMs: 3000, pressureBar: 0.5, tempC: 70.0),
        ShotSample(elapsedMs: 4000, pressureBar: 0, tempC: 45.0),
      ]);

      expect(range.startTempC, 91.5);
      expect(range.endTempC, 93.4);
      expect(range.format(), '91.5 °C → 93.4 °C');
    });

    test('omits end temp when no in-shot reading exists', () {
      final range = brewTempRangeFromSamples(const [
        ShotSample(elapsedMs: 0, pressureBar: 0, tempC: 92.0),
        ShotSample(elapsedMs: 1000, pressureBar: 0.2, tempC: 40.0),
      ]);

      expect(range.startTempC, 92.0);
      expect(range.endTempC, isNull);
      expect(range.format(), '92.0 °C');
    });

    test('returns empty range without temperature readings', () {
      final range = brewTempRangeFromSamples(const [
        ShotSample(elapsedMs: 0, pressureBar: 9),
        ShotSample(elapsedMs: 1000, pressureBar: 6),
      ]);

      expect(range.hasAny, isFalse);
      expect(range.format(), '—');
    });

    test('uses custom pressure cutoff', () {
      final range = brewTempRangeFromSamples(
        const [
          ShotSample(elapsedMs: 0, pressureBar: 2, tempC: 90.0),
          ShotSample(elapsedMs: 1000, pressureBar: 1.5, tempC: 91.0),
          ShotSample(elapsedMs: 2000, pressureBar: 0.8, tempC: 50.0),
        ],
        endTempMinPressureBar: 1.5,
      );

      expect(range.endTempC, 91.0);
    });
  });
}