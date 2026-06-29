import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('exportShotToCsv', () {
    test('matches golden fixture byte-for-byte', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');
      final csv = exportShotToCsv(shot);
      final golden = File(_fixturePath('shots/minimal_shot.csv')).readAsStringSync();

      expect(csv, golden);
    });

    test('is deterministic for the same shot', () {
      final shot = _loadFixtureShot('shots/minimal_shot.json');

      expect(exportShotToCsv(shot), exportShotToCsv(shot));
    });

    test('sorts samples by elapsed_ms', () {
      final shot = Shot(
        id: 'shot-order',
        startedAt: DateTime.utc(2026, 6, 29, 10, 0),
        samples: const [
          ShotSample(elapsedMs: 2000, pressureBar: 2.0),
          ShotSample(elapsedMs: 0, pressureBar: 0.0),
          ShotSample(elapsedMs: 1000, pressureBar: 1.0),
        ],
      );

      final csv = exportShotToCsv(shot);
      final sampleSection = csv
          .split('\n\n')
          .last
          .split('\n')
          .skip(1)
          .where((line) => line.isNotEmpty);

      expect(
        sampleSection.map((line) => int.parse(line.split(',').first)).toList(),
        [0, 1000, 2000],
      );
    });

    test('escapes metadata values that need CSV quoting', () {
      final shot = Shot(
        id: 'shot-escape',
        startedAt: DateTime.utc(2026, 6, 29, 10, 0),
        notes: 'Bright, fruity "morning" shot',
        flavourTags: const ['citrus', 'floral'],
        samples: const [ShotSample(elapsedMs: 0)],
      );

      final csv = exportShotToCsv(shot);

      expect(csv, contains('notes,"Bright, fruity ""morning"" shot"'));
      expect(csv, contains('flavour_tags,citrus;floral'));
    });
  });
}

Shot _loadFixtureShot(String relativePath) {
  final json = jsonDecode(File(_fixturePath(relativePath)).readAsStringSync())
      as Map<String, dynamic>;
  return Shot.fromJson(json);
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