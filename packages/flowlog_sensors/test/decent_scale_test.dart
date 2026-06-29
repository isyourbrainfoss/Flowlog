import 'dart:async';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:test/test.dart';

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main() {
  group('DecentScaleCommands', () {
    test('builds documented commands with correct XOR', () {
      expect(DecentScaleCommands.tare(), [0x03, 0x0F, 0x00, 0x00, 0x00, 0x01, 0x0D]);
      expect(
        DecentScaleCommands.ledOnGrams(),
        [0x03, 0x0A, 0x01, 0x01, 0x00, 0x01, 0x08],
      );
      expect(DecentScaleCommands.ledOff(), [0x03, 0x0A, 0x00, 0x00, 0x00, 0x00, 0x09]);
      expect(DecentScaleCommands.timerStart(), [0x03, 0x0B, 0x03, 0x00, 0x00, 0x00, 0x0B]);
      expect(DecentScaleCommands.timerStop(), [0x03, 0x0B, 0x00, 0x00, 0x00, 0x00, 0x08]);
      expect(DecentScaleCommands.timerReset(), [0x03, 0x0B, 0x02, 0x00, 0x00, 0x00, 0x0A]);
      expect(
        DecentScaleCommands.heartbeat(),
        [0x03, 0x0A, 0x03, 0xFF, 0xFF, 0x00, 0x0A],
      );
    });

    test('xorChecksum matches first six bytes', () {
      expect(
        DecentScaleCommands.xorChecksum([0x03, 0xCE, 0x00, 0x65, 0x00, 0x00]),
        0xA8,
      );
    });
  });

  group('DecentScaleParser', () {
    test('parses 7-byte weight examples from protocol doc', () {
      expect(
        DecentScaleParser.parseWeight([0x03, 0xCE, 0x00, 0x00, 0x00, 0x00, 0xCD]),
        const DecentScaleWeightReading(grams: 0.0, isStable: true),
      );
      expect(
        DecentScaleParser.parseWeight([0x03, 0xCE, 0x00, 0x65, 0x00, 0x00, 0xA8]),
        const DecentScaleWeightReading(grams: 10.1, isStable: true),
      );
      expect(
        DecentScaleParser.parseWeight([0x03, 0xCE, 0x07, 0x94, 0x00, 0x00, 0x5E]),
        const DecentScaleWeightReading(grams: 194.0, isStable: true),
      );
      expect(
        DecentScaleParser.parseWeight([0x03, 0xCE, 0x1B, 0x93, 0x00, 0x00, 0x5E]),
        const DecentScaleWeightReading(grams: 705.9, isStable: true),
      );
    });

    test('parses 10-byte weight examples with timer fields', () {
      expect(
        DecentScaleParser.parseWeight(
          [0x03, 0xCE, 0x00, 0x00, 0x01, 0x02, 0x03, 0x00, 0x00, 0xCD],
        ),
        const DecentScaleWeightReading(
          grams: 0.0,
          isStable: true,
          timer: DecentScaleTimer(minutes: 1, seconds: 2, deciseconds: 3),
        ),
      );
      expect(
        DecentScaleParser.parseWeight(
          [0x03, 0xCE, 0x00, 0x65, 0x01, 0x02, 0x04, 0x00, 0x00, 0xA8],
        ),
        const DecentScaleWeightReading(
          grams: 10.1,
          isStable: true,
          timer: DecentScaleTimer(minutes: 1, seconds: 2, deciseconds: 4),
        ),
      );
    });

    test('marks changing weight packets as unstable', () {
      expect(
        DecentScaleParser.parseWeight([0x03, 0xCA, 0x00, 0x65, 0x00, 0x00, 0xAC]),
        const DecentScaleWeightReading(grams: 10.1, isStable: false),
      );
    });

    test('returns null for invalid packets', () {
      expect(DecentScaleParser.parseWeight([0x03, 0xAA, 0x01, 0x01, 0x00, 0x00, 0xA9]), isNull);
      expect(DecentScaleParser.parseWeight([0x03, 0xCE, 0x00, 0x00, 0x00, 0x00]), isNull);
      expect(DecentScaleParser.parseWeight([0x03, 0xCE, 0x00, 0x00, 0x00]), isNull);
    });
  });

  group('DecentScaleBleAdapter', () {
    late MockDecentScaleTransport transport;
    late DecentScaleBleAdapter adapter;
    late int clockMs;

    setUp(() {
      clockMs = 1_000;
      transport = MockDecentScaleTransport();
      adapter = DecentScaleBleAdapter(
        transport: transport,
        heartbeatInterval: const Duration(milliseconds: 50),
        minCommandSpacing: Duration.zero,
        monotonicClock: () => clockMs,
      );
    });

    tearDown(() async {
      await adapter.disconnect();
    });

    test('connect subscribes, sends LED on, and reaches connected state', () async {
      final states = <ConnectionState>[];
      final sub = adapter.state.listen(states.add);

      await adapter.connect();
      await Future<void>.delayed(Duration.zero);

      expect(transport.connected, isTrue);
      expect(transport.subscribed, isTrue);
      expect(
        adapter.writtenCommands.first,
        DecentScaleCommands.ledOnGrams(),
      );
      expect(states, [ConnectionState.connecting, ConnectionState.connected]);

      await sub.cancel();
    });

    test('tare writes heartbeat-aware command', () async {
      await adapter.connect();
      await adapter.tare();

      expect(adapter.writtenCommands.last, DecentScaleCommands.tare());
    });

    test('emits weight samples stamped with host receive time', () async {
      final samples = <SensorSample>[];
      final sub = adapter.samples.listen(samples.add);

      await adapter.connect();
      clockMs = 1_150;
      transport.emitNotification([0x03, 0xCE, 0x00, 0x65, 0x00, 0x00, 0xA8]);
      await Future<void>.delayed(Duration.zero);

      expect(samples, hasLength(1));
      expect(samples.single.weightG, 10.1);
      expect(samples.single.elapsedMs, 150);

      await sub.cancel();
    });

    test('sends heartbeat command periodically while connected', () async {
      await adapter.connect();
      await Future<void>.delayed(Duration.zero);

      clockMs += 120;
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final heartbeats = adapter.writtenCommands
          .where((cmd) => _bytesEqual(cmd, DecentScaleCommands.heartbeat()))
          .length;
      expect(heartbeats, greaterThanOrEqualTo(2));
    });

    test('disconnect stops heartbeat and emits disconnected', () async {
      final states = <ConnectionState>[];
      final sub = adapter.state.listen(states.add);

      await adapter.connect();
      await adapter.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states.last, ConnectionState.disconnected);
      expect(transport.connected, isFalse);

      clockMs += 200;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final commandCountAfterDisconnect = adapter.writtenCommands.length;

      clockMs += 200;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(adapter.writtenCommands.length, commandCountAfterDisconnect);

      await sub.cancel();
    });
  });
}