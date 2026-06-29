import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('importShotFromCsv', () {
    test('round-trips with exportShotToCsv using minimal_shot fixture', () {
      final golden =
          File(_fixturePath('shots/minimal_shot.csv')).readAsStringSync();
      final shot = importShotFromCsv(golden);

      expect(exportShotToCsv(shot), golden);
    });

    test('round-trips through DB insert and read', () async {
      final csv =
          File(_fixturePath('shots/minimal_shot.csv')).readAsStringSync();
      final shot = importShotFromCsv(csv);

      final db = FlowlogDatabase.inMemory();
      addTearDown(db.close);

      final repository = ShotRepository(db);
      await repository.insertShot(shot);

      final loaded = await repository.getShotWithSamples(shot.id);
      expect(loaded, shot);
    });

    test('parses quoted metadata values', () {
      final exported = exportShotToCsv(
        Shot(
          id: 'shot-escape',
          startedAt: DateTime.utc(2026, 6, 29, 10, 0),
          notes: 'Bright, fruity "morning" shot',
          flavourTags: const ['citrus', 'floral'],
          samples: const [ShotSample(elapsedMs: 0)],
        ),
      );

      final shot = importShotFromCsv(exported);

      expect(shot.notes, 'Bright, fruity "morning" shot');
      expect(shot.flavourTags, ['citrus', 'floral']);
      expect(exportShotToCsv(shot), exported);
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