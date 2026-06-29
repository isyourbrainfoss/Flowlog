import 'dart:io';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:test/test.dart';

void main() {
  group('MockReplayAdapter', () {
    late String fixturePath;
    late int expectedSampleCount;

    setUp(() {
      fixturePath = _fixturePath('sensor_streams/demo_shot.jsonl');
      expectedSampleCount = File(fixturePath)
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .length;
    });

    test('instant replay emits every fixture sample', () async {
      final adapter = MockReplayAdapter(
        fixturePath: fixturePath,
        speed: 0,
      );

      final states = <ConnectionState>[];
      final received = <SensorSample>[];

      final stateSub = adapter.state.listen(states.add);
      final sampleSub = adapter.samples.listen(received.add);

      await adapter.connect();
      await Future<void>.delayed(Duration.zero);

      expect(
        states,
        [
          ConnectionState.connecting,
          ConnectionState.connected,
        ],
      );
      expect(received, hasLength(expectedSampleCount));
      expect(received.first.elapsedMs, 0);
      expect(received.first.pressureBar, 0.0);
      expect(received.last.elapsedMs, 28000);
      expect(received.last.weightG, closeTo(36.32, 0.01));

      await adapter.disconnect();
      expect(states.last, ConnectionState.disconnected);

      await stateSub.cancel();
      await sampleSub.cancel();
    });

    test('realtime replay schedules samples by elapsedMs deltas', () async {
      final tempDir = Directory.systemTemp.createTempSync('mock_replay_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final timingFixture = File('${tempDir.path}/timing.jsonl')
        ..writeAsStringSync('''
{"elapsedMs":0,"pressureBar":0}
{"elapsedMs":100,"pressureBar":1}
{"elapsedMs":300,"pressureBar":2}
''');

      final adapter = MockReplayAdapter(
        fixturePath: timingFixture.path,
        speed: 1.0,
      );

      final received = <SensorSample>[];
      final sampleSub = adapter.samples.listen(received.add);

      await adapter.connect();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await adapter.disconnect();
      await sampleSub.cancel();

      expect(received, hasLength(1));
      expect(received.single.elapsedMs, 0);
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
    if (file.existsSync()) {
      return file.path;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}