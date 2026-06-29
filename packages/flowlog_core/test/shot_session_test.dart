import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:test/test.dart';

void main() {
  group('ShotSession', () {
    late ShotSession session;

    setUp(() {
      session = ShotSession();
    });

    tearDown(() async {
      await session.dispose();
    });

    test('starts in idle with no samples', () {
      expect(session.state, ShotSessionState.idle);
      expect(session.samples, isEmpty);
    });

    test('start transitions idle to recording and collects stream samples', () async {
      final streamController = StreamController<ShotSample>();
      final states = <ShotSessionState>[];
      final batches = <List<ShotSample>>[];

      session.stateChanges.listen(states.add);
      session.sampleBatches.listen(batches.add);

      session.start(streamController.stream);

      expect(session.state, ShotSessionState.recording);
      expect(states, [ShotSessionState.recording]);

      streamController
        ..add(const ShotSample(elapsedMs: 0, pressureBar: 0.0, weightG: 0.0))
        ..add(const ShotSample(elapsedMs: 100, pressureBar: 1.0, weightG: 0.5));

      await pumpEventQueue();

      expect(session.samples, hasLength(2));
      expect(batches, hasLength(2));
      expect(batches[0], [session.samples[0]]);
      expect(batches[1], [session.samples[1]]);

      await streamController.close();
    });

    test('start rejects non-idle state', () {
      session.startManual();

      expect(
        () => session.start(Stream<ShotSample>.empty()),
        throwsA(isA<StateError>()),
      );
    });

    test('pause and resume gate sample collection', () async {
      final streamController = StreamController<ShotSample>();
      final states = <ShotSessionState>[];

      session.stateChanges.listen(states.add);
      session.start(streamController.stream);

      streamController.add(
        const ShotSample(elapsedMs: 0, pressureBar: 0.0, weightG: 0.0),
      );
      await pumpEventQueue();

      session.pause();
      streamController.add(
        const ShotSample(elapsedMs: 100, pressureBar: 1.0, weightG: 0.5),
      );
      await pumpEventQueue();

      expect(session.state, ShotSessionState.paused);
      expect(session.samples, hasLength(1));
      expect(states, [
        ShotSessionState.recording,
        ShotSessionState.paused,
      ]);

      session.resume();
      streamController.add(
        const ShotSample(elapsedMs: 200, pressureBar: 2.0, weightG: 1.0),
      );
      await pumpEventQueue();

      expect(session.state, ShotSessionState.recording);
      expect(session.samples, hasLength(2));
      expect(states, [
        ShotSessionState.recording,
        ShotSessionState.paused,
        ShotSessionState.recording,
      ]);

      await streamController.close();
    });

    test('pause and resume reject invalid states', () {
      expect(() => session.pause(), throwsA(isA<StateError>()));
      expect(() => session.resume(), throwsA(isA<StateError>()));

      session.startManual();
      expect(() => session.resume(), throwsA(isA<StateError>()));
    });

    test('stop from recording finalizes session and cancels subscription', () async {
      final streamController = StreamController<ShotSample>();
      final states = <ShotSessionState>[];
      final batches = <List<ShotSample>>[];

      session.stateChanges.listen(states.add);
      session.sampleBatches.listen(batches.add);
      session.start(streamController.stream);

      streamController
        ..add(const ShotSample(elapsedMs: 0, pressureBar: 0.0))
        ..add(const ShotSample(elapsedMs: 100, pressureBar: 1.0));
      await pumpEventQueue();

      session.stop();

      expect(session.state, ShotSessionState.stopped);
      expect(session.samples, hasLength(2));
      expect(states.last, ShotSessionState.stopped);

      streamController.add(
        const ShotSample(elapsedMs: 200, pressureBar: 2.0),
      );
      await pumpEventQueue();
      expect(session.samples, hasLength(2));

      await streamController.close();
    });

    test('stop from paused preserves collected samples', () async {
      final streamController = StreamController<ShotSample>();

      session.start(streamController.stream);
      streamController.add(
        const ShotSample(elapsedMs: 0, weightG: 0.0),
      );
      await pumpEventQueue();

      session.pause();
      session.stop();

      expect(session.state, ShotSessionState.stopped);
      expect(session.samples, hasLength(1));

      await streamController.close();
    });

    test('stop rejects idle', () {
      expect(() => session.stop(), throwsA(isA<StateError>()));
    });

    test('manual ingestion collects samples without a stream', () async {
      final batches = <List<ShotSample>>[];
      session.sampleBatches.listen(batches.add);

      session.startManual();
      session.ingestSample(
        const ShotSample(elapsedMs: 0, pressureBar: 0.0, weightG: 0.0),
      );
      session.ingestSample(
        const ShotSample(elapsedMs: 50, pressureBar: 0.5, weightG: 0.2),
      );
      await pumpEventQueue();

      expect(session.samples, hasLength(2));
      expect(batches, hasLength(2));
    });

    test('replays demo_shot fixture samples through stream mode', () async {
      final samples = await _loadDemoShotSamples();
      final streamController = StreamController<ShotSample>();

      session.start(streamController.stream);
      for (final sample in samples) {
        streamController.add(sample);
      }
      await pumpEventQueue();

      session.stop();

      expect(session.samples, samples);
      expect(session.state, ShotSessionState.stopped);

      await streamController.close();
    });
  });
}

Future<List<ShotSample>> _loadDemoShotSamples() async {
  final fixturePath = _fixturePath('sensor_streams/demo_shot.jsonl');
  final lines = await File(fixturePath).readAsLines();
  final samples = <ShotSample>[];

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final json = jsonDecode(trimmed) as Map<String, dynamic>;
    samples.add(
      ShotSample(
        elapsedMs: (json['elapsedMs'] as num).toInt(),
        pressureBar: (json['pressureBar'] as num?)?.toDouble(),
        weightG: (json['weightG'] as num?)?.toDouble(),
        tempC: (json['tempC'] as num?)?.toDouble(),
        flowGs: (json['flowGs'] as num?)?.toDouble(),
      ),
    );
  }

  return samples;
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