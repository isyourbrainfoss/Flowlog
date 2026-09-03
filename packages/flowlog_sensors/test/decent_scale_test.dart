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
      // 9.0 bar = 9000 mbar = 0x2328
      expect(
        DecentScaleCommands.phonePressure(9.0),
        [0x03, 0xF0, 0x23, 0x28, 0x00, 0x00, 0xF8],
      );
      expect(
        DecentScaleCommands.phoneBrewStart(),
        [0x03, 0xF1, 0x00, 0x00, 0x00, 0x00, 0xF2],
      );
      expect(
        DecentScaleCommands.phoneBrewEnd(),
        [0x03, 0xF2, 0x00, 0x00, 0x00, 0x00, 0xF1],
      );
      // 36, 34, 5, 10 → XOR of 03 F3 24 22 05 0A
      expect(
        DecentScaleCommands.scaleDisplayConfig(
          targetYieldG: 36,
          warnAtG: 34,
          pressureMinBar: 5,
          pressureMaxBar: 10,
        ),
        [0x03, 0xF3, 0x24, 0x22, 0x05, 0x0A, 0xF9],
      );
      expect(
        DecentScaleCommands.shotExportList(),
        [0x03, 0xF4, 0x00, 0x00, 0x00, 0x00, 0xF7],
      );
      expect(
        DecentScaleCommands.shotExportGet(age: 1),
        [0x03, 0xF4, 0x01, 0x01, 0x00, 0x00, 0xF7],
      );
      expect(
        DecentScaleCommands.shotExportStatus(),
        [0x03, 0xF4, 0x02, 0x00, 0x00, 0x00, 0xF5],
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

    test('isWeightStreamSilent waits for grace after connect', () async {
      await adapter.connect();

      clockMs = 1_000 + 1_500;
      expect(
        adapter.isWeightStreamSilent(silentFor: const Duration(seconds: 4)),
        isFalse,
      );

      clockMs = 1_000 + 5_000;
      expect(
        adapter.isWeightStreamSilent(silentFor: const Duration(seconds: 4)),
        isTrue,
      );

      clockMs = 8_000;
      transport.emitNotification([0x03, 0xCE, 0x00, 0x65, 0x00, 0x00, 0xA8]);
      await Future<void>.delayed(Duration.zero);
      expect(
        adapter.isWeightStreamSilent(silentFor: const Duration(seconds: 4)),
        isFalse,
      );

      clockMs = 13_000;
      expect(
        adapter.isWeightStreamSilent(silentFor: const Duration(seconds: 4)),
        isTrue,
      );
    });

    test('sendPhonePressure and heartbeat do not throw', () async {
      await adapter.connect();
      await adapter.sendPhonePressure(9.0);
      clockMs += 120;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(adapter.writtenCommands, isNotEmpty);
    });

    test('heartbeat drops while another write is in flight', () async {
      clockMs = 1_000;
      final blocking = _BlockingDecentScaleTransport();
      final busyAdapter = DecentScaleBleAdapter(
        transport: blocking,
        heartbeatInterval: const Duration(milliseconds: 40),
        minCommandSpacing: Duration.zero,
        monotonicClock: () => clockMs,
      );
      addTearDown(busyAdapter.disconnect);

      await busyAdapter.connect();
      blocking.blockWrites = Completer<void>();
      final tare = busyAdapter.tare();
      await Future<void>.delayed(Duration.zero);

      await busyAdapter.sendPhonePressure(9.0);
      clockMs += 200;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(
        busyAdapter.writtenCommands,
        [DecentScaleCommands.ledOnGrams()],
      );

      blocking.blockWrites!.complete();
      blocking.blockWrites = null;
      await tare;
      expect(busyAdapter.writtenCommands.last, DecentScaleCommands.tare());
    });

    test('rearmStream skips CCCD toggle when hard recovery is disabled', () async {
      final counting = _CountingRearmTransport();
      final recoveryAdapter = DecentScaleBleAdapter(
        transport: counting,
        heartbeatInterval: const Duration(days: 1),
        minCommandSpacing: Duration.zero,
        monotonicClock: () => clockMs,
      );
      addTearDown(recoveryAdapter.disconnect);

      await recoveryAdapter.connect();
      expect(counting.rearmCalls, 0);

      recoveryAdapter.allowHardRecovery = false;
      await recoveryAdapter.rearmStream();
      expect(counting.rearmCalls, 0);
      expect(
        recoveryAdapter.writtenCommands.last,
        DecentScaleCommands.ledOnGrams(),
      );

      recoveryAdapter.allowHardRecovery = true;
      await recoveryAdapter.rearmStream();
      expect(counting.rearmCalls, 1);
      expect(
        recoveryAdapter.writtenCommands.last,
        DecentScaleCommands.ledOnGrams(),
      );
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

class _BlockingDecentScaleTransport extends MockDecentScaleTransport {
  Completer<void>? blockWrites;

  @override
  Future<void> writeCommand(List<int> command) async {
    final block = blockWrites;
    if (block != null) {
      await block.future;
    }
    await super.writeCommand(command);
  }
}

class _CountingRearmTransport extends MockDecentScaleTransport {
  int rearmCalls = 0;

  @override
  Future<void> rearmNotifications() {
    rearmCalls += 1;
    return super.rearmNotifications();
  }
}