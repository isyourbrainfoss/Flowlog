import 'dart:convert';
import 'dart:io';

import 'package:flowlog/screens/more/export.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildBatchExport', () {
    test('combines multiple shots into one CSV document', () {
      final shots = [
        _fixtureShot(id: 'shot-a'),
        _fixtureShot(id: 'shot-b'),
      ];

      final payload = buildBatchExport(
        shots,
        format: BatchExportFormat.combinedCsv,
      );

      expect(payload.format, BatchExportFormat.combinedCsv);
      expect(payload.files, isEmpty);
      expect(payload.combinedCsv, isNotNull);

      expect(
        payload.combinedCsv,
        '${exportShotToCsv(shots.first)}\n\n${exportShotToCsv(shots.last)}',
      );
    });

    test('zip format returns one file entry per shot', () {
      final shots = [
        _fixtureShot(id: 'shot-a'),
        _fixtureShot(id: 'shot-b'),
      ];

      final payload = buildBatchExport(
        shots,
        format: BatchExportFormat.zip,
      );

      expect(payload.format, BatchExportFormat.zip);
      expect(payload.combinedCsv, isNull);
      expect(payload.files.length, 2);
      expect(payload.files.first.filename, 'shot-a.csv');
      expect(payload.files.first.content, exportShotToCsv(shots.first));
      expect(payload.files.last.filename, 'shot-b.csv');
    });

    test('rejects empty shot list', () {
      expect(
        () => buildBatchExport(const []),
        throwsArgumentError,
      );
    });
  });

  group('deliverBatchExport', () {
    test('writes combined CSV through stub save actions', () async {
      final actions = StubExportActions(
        saveDirectory: Directory.systemTemp.createTempSync('flowlog-export-test').path,
      );
      final shot = _fixtureShot();
      final payload = buildBatchExport([shot]);

      final outcome = await deliverBatchExport(payload, actions: actions);

      expect(outcome.success, isTrue);
      expect(outcome.savedPath, isNotNull);
      expect(actions.lastSavedContent, payload.combinedCsv);
      expect(File(outcome.savedPath!).readAsStringSync(), payload.combinedCsv);
    });

    test('shares zip entries through stub share actions', () async {
      final actions = StubExportActions();
      final shots = [
        _fixtureShot(id: 'shot-a'),
        _fixtureShot(id: 'shot-b'),
      ];
      final payload = buildBatchExport(
        shots,
        format: BatchExportFormat.zip,
      );

      final outcome = await deliverBatchExport(payload, actions: actions);

      expect(outcome.success, isTrue);
      expect(outcome.sharedFilenames, ['shot-a.csv', 'shot-b.csv']);
      expect(actions.lastSharedFiles.length, 2);
    });
  });

  group('ExportScreen', () {
    late FlowlogDatabase db;
    late ShotRepository repository;
    late StubExportActions actions;
    late Directory saveDirectory;

    setUp(() {
      db = FlowlogDatabase.inMemory();
      repository = ShotRepository(db);
      saveDirectory = Directory.systemTemp.createTempSync('flowlog-export-ui');
      actions = StubExportActions(saveDirectory: saveDirectory.path);
    });

    tearDown(() async {
      await db.close();
      if (saveDirectory.existsSync()) {
        saveDirectory.deleteSync(recursive: true);
      }
    });

    testWidgets('shows empty state when no shots exist', (tester) async {
      await _pumpExportScreen(
        tester,
        repository: repository,
        actions: actions,
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved shots to export yet'), findsOneWidget);
    });

    testWidgets('exports selected shots as combined CSV', (tester) async {
      final shots = [
        _fixtureShot(id: 'shot-a'),
        _fixtureShot(id: 'shot-b'),
      ];
      for (final shot in shots) {
        await repository.insertShot(shot);
      }

      await _pumpExportScreen(
        tester,
        repository: repository,
        actions: actions,
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear all'), findsOneWidget);

      final exportButton = find.byKey(const Key('export_submit_button'));
      expect(tester.widget<FilledButton>(exportButton).onPressed, isNotNull);

      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      final expectedCsv = buildBatchExport(shots).combinedCsv;
      expect(actions.saveCalls, 1);
      expect(actions.lastSavedContent, expectedCsv);
      expect(actions.lastSavedPath, isNotNull);
    });

    testWidgets('zip format shares one file per selected shot', (tester) async {
      final shots = [
        _fixtureShot(id: 'shot-a'),
        _fixtureShot(id: 'shot-b'),
      ];
      for (final shot in shots) {
        await repository.insertShot(shot);
      }

      await _pumpExportScreen(
        tester,
        repository: repository,
        actions: actions,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ZIP (stub)'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Shared export'), findsOneWidget);
      expect(actions.lastSharedFiles.length, 2);
      expect(
        actions.lastSharedFiles.map((file) => file.filename).toList(),
        ['shot-a.csv', 'shot-b.csv'],
      );
    });
  });
}

Future<void> _pumpExportScreen(
  WidgetTester tester, {
  required ShotRepository repository,
  required StubExportActions actions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ExportScreen(
          shotRepository: repository,
          exportActions: actions,
        ),
      ),
    ),
  );
}

Shot _fixtureShot({String id = 'shot-minimal-001'}) {
  final file = File(_fixturePath('shots/minimal_shot.json'));
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Shot.fromJson(json).copyWith(id: id);
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
    '../../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}