import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:test/test.dart';

void main() {
  group('SensorSample', () {
    test('exposes elapsed time as Duration t', () {
      const sample = SensorSample(elapsedMs: 1500);
      expect(sample.t, const Duration(milliseconds: 1500));
    });

    test('supports optional channel fields', () {
      const sample = SensorSample(
        elapsedMs: 100,
        pressureBar: 9.2,
        weightG: 18.5,
        tempC: 93.1,
        flowGs: 2.4,
      );

      expect(sample.pressureBar, 9.2);
      expect(sample.weightG, 18.5);
      expect(sample.tempC, 93.1);
      expect(sample.flowGs, 2.4);
    });

    test('maps to ShotSample', () {
      const sample = SensorSample(
        elapsedMs: 250,
        pressureBar: 8.0,
        weightG: 12.3,
      );

      final shotSample = sample.toShotSample();
      expect(shotSample.elapsedMs, 250);
      expect(shotSample.pressureBar, 8.0);
      expect(shotSample.weightG, 12.3);
      expect(shotSample.tempC, isNull);
      expect(shotSample.flowGs, isNull);
    });

    test('copyWith overrides provided fields', () {
      const original = SensorSample(elapsedMs: 0, pressureBar: 1.0);
      final updated = original.copyWith(weightG: 5.0, elapsedMs: 50);

      expect(updated.elapsedMs, 50);
      expect(updated.pressureBar, 1.0);
      expect(updated.weightG, 5.0);
    });

    test('equality uses value semantics', () {
      const a = SensorSample(elapsedMs: 10, pressureBar: 6.0);
      const b = SensorSample(elapsedMs: 10, pressureBar: 6.0);
      const c = SensorSample(elapsedMs: 11, pressureBar: 6.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}