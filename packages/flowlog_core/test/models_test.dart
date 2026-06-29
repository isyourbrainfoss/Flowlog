import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('ShotSample', () {
    test('toJson/fromJson round-trip', () {
      const original = ShotSample(
        elapsedMs: 1250,
        pressureBar: 9.2,
        weightG: 18.4,
        flowGs: 1.8,
        tempC: 93.5,
      );

      final restored = ShotSample.fromJson(original.toJson());
      expect(restored, original);
    });

    test('fromJson accepts integer numeric fields', () {
      final sample = ShotSample.fromJson({
        'elapsedMs': 500,
        'pressureBar': 9,
        'weightG': 10,
      });

      expect(sample.pressureBar, 9.0);
      expect(sample.weightG, 10.0);
    });

    test('copyWith updates selected fields', () {
      const original = ShotSample(elapsedMs: 100, pressureBar: 8.0);
      final updated = original.copyWith(weightG: 12.5);

      expect(updated.elapsedMs, 100);
      expect(updated.pressureBar, 8.0);
      expect(updated.weightG, 12.5);
    });
  });

  group('Bean', () {
    test('toJson/fromJson round-trip', () {
      const original = Bean(
        id: 'bean-1',
        name: 'Ethiopia Yirgacheffe',
        origin: 'Ethiopia',
        roastLevel: 'light',
        stockG: 250.0,
        notes: 'Fruity',
      );

      final restored = Bean.fromJson(original.toJson());
      expect(restored, original);
    });

    test('minimal bean round-trip', () {
      const original = Bean(id: 'bean-min', name: 'House Blend');
      expect(Bean.fromJson(original.toJson()), original);
    });
  });

  group('Device', () {
    test('toJson/fromJson round-trip', () {
      final original = Device(
        id: 'dev-pressensor',
        name: 'CJ2 Pressensor',
        type: DeviceType.pressensor,
        lastConnectedAt: DateTime.utc(2026, 6, 29, 8, 30),
      );

      final restored = Device.fromJson(original.toJson());
      expect(restored, original);
    });

    test('scale device type serializes as scale', () {
      const device = Device(
        id: 'dev-scale',
        name: 'Decent Half',
        type: DeviceType.scale,
      );

      expect(device.toJson()['type'], 'scale');
      expect(
        Device.fromJson(device.toJson()).type,
        DeviceType.scale,
      );
    });
  });

  group('Shot', () {
    test('toJson/fromJson round-trip with samples and tags', () {
      final original = Shot(
        id: 'shot-42',
        startedAt: DateTime.utc(2026, 6, 29, 10, 0),
        endedAt: DateTime.utc(2026, 6, 29, 10, 0, 32),
        doseG: 18.0,
        yieldG: 36.5,
        grindSetting: 14.5,
        beanId: 'bean-1',
        waterTempC: 93.0,
        notes: 'Clean extraction',
        tasteScore: 8,
        flavourTags: const ['chocolate', 'caramel'],
        samples: const [
          ShotSample(elapsedMs: 0, pressureBar: 0.0, weightG: 0.0),
          ShotSample(elapsedMs: 15000, pressureBar: 9.0, weightG: 18.2),
        ],
      );

      final restored = Shot.fromJson(original.toJson());
      expect(restored, original);
    });

    test('minimal shot round-trip', () {
      final original = Shot(
        id: 'shot-min',
        startedAt: DateTime.utc(2026, 6, 29, 12, 0),
      );

      expect(Shot.fromJson(original.toJson()), original);
    });

    test('rejects tasteScore outside 0-10', () {
      expect(
        () => Shot(
          id: 'bad',
          startedAt: DateTime.utc(2026, 1, 1),
          tasteScore: 11,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith updates metadata', () {
      final original = Shot(
        id: 'shot-1',
        startedAt: DateTime.utc(2026, 6, 29, 9, 0),
        doseG: 18.0,
      );

      final updated = original.copyWith(yieldG: 40.0, tasteScore: 9);
      expect(updated.doseG, 18.0);
      expect(updated.yieldG, 40.0);
      expect(updated.tasteScore, 9);
    });
  });

  group('fixtures', () {
    test('minimal_shot.json round-trips', () {
      final fixturePath = _fixturePath('shots/minimal_shot.json');
      final json = jsonDecode(File(fixturePath).readAsStringSync())
          as Map<String, dynamic>;

      final shot = Shot.fromJson(json);
      expect(shot.id, 'shot-minimal-001');
      expect(shot.samples, hasLength(2));
      expect(Shot.fromJson(shot.toJson()), shot);
    });
  });
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) return file.path;
  }

  throw StateError('Fixture not found: $relativePath');
}