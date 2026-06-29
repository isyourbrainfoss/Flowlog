import 'dart:async';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:test/test.dart';

class _MockPressensorBleTransport implements PressensorBleTransport {
  _MockPressensorBleTransport();

  final _pressureController = StreamController<List<int>>.broadcast();

  bool connected = false;

  void emitPressure(List<int> data) {
    _pressureController.add(data);
  }

  @override
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return const ['prs-1'];
  }

  @override
  Future<void> connect({String? deviceId}) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Stream<List<int>> subscribePressure() => _pressureController.stream;

  @override
  Future<void> writeZeroPressure([
    List<int> payload = pressensorZeroPressureCommand,
  ]) async {}

  Future<void> close() => _pressureController.close();
}

void main() {
  group('MergedSampleStream', () {
    late _MockPressensorBleTransport pressureTransport;
    late MockDecentScaleTransport weightTransport;
    late PressensorBleAdapter pressureAdapter;
    late DecentScaleBleAdapter weightAdapter;
    late int clockMs;

    setUp(() {
      clockMs = 10_000;
      pressureTransport = _MockPressensorBleTransport();
      weightTransport = MockDecentScaleTransport();
      pressureAdapter = PressensorBleAdapter(
        transport: pressureTransport,
        deviceId: 'prs-1',
      );
      weightAdapter = DecentScaleBleAdapter(
        transport: weightTransport,
        heartbeatInterval: const Duration(days: 1),
        minCommandSpacing: Duration.zero,
        monotonicClock: () => clockMs,
      );
    });

    tearDown(() async {
      await pressureTransport.close();
    });

    test('requires at least one adapter', () async {
      final merged = MergedSampleStream();

      expect(
        () => merged.start(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('at least one sensor adapter'),
          ),
        ),
      );
    });

    test('merges pressure and weight on host monotonic clock', () async {
      final merged = MergedSampleStream(
        pressureAdapter: pressureAdapter,
        weightAdapter: weightAdapter,
        monotonicClock: () => clockMs,
      );

      final received = <SensorSample>[];
      final sub = merged.samples.listen(received.add);

      clockMs = 10_000;
      await merged.start();

      clockMs = 10_050;
      pressureTransport.emitPressure([0x23, 0x28]);
      await Future<void>.delayed(Duration.zero);

      clockMs = 10_200;
      weightTransport.emitNotification(
        [0x03, 0xCE, 0x00, 0x65, 0x00, 0x00, 0xA8],
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received[0].elapsedMs, 50);
      expect(received[0].pressureBar, closeTo(9.0, 1e-9));
      expect(received[0].weightG, isNull);
      expect(received[0].tempC, isNull);

      expect(received[1].elapsedMs, 200);
      expect(received[1].pressureBar, closeTo(9.0, 1e-9));
      expect(received[1].weightG, 10.1);
      expect(received[1].tempC, isNull);

      await merged.stop();
      await sub.cancel();
    });

    test('carries temperature forward from pressure notifications', () async {
      final merged = MergedSampleStream(
        pressureAdapter: pressureAdapter,
        weightAdapter: weightAdapter,
        monotonicClock: () => clockMs,
      );

      final received = <SensorSample>[];
      final sub = merged.samples.listen(received.add);

      await merged.start();

      clockMs = 10_100;
      pressureTransport.emitPressure([0x21, 0x34, 0x03, 0xA3]);
      await Future<void>.delayed(Duration.zero);

      clockMs = 10_250;
      weightTransport.emitNotification(
        [0x03, 0xCE, 0x00, 0x65, 0x00, 0x00, 0xA8],
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      expect(received.last.tempC, closeTo(93.1, 1e-9));
      expect(received.last.pressureBar, closeTo(8.5, 1e-9));
      expect(received.last.weightG, 10.1);

      await merged.stop();
      await sub.cancel();
    });

    test('works with only pressure adapter connected', () async {
      final merged = MergedSampleStream(
        pressureAdapter: pressureAdapter,
        monotonicClock: () => clockMs,
      );

      final received = <SensorSample>[];
      final sub = merged.samples.listen(received.add);

      await merged.start();

      clockMs = 10_075;
      pressureTransport.emitPressure([0x23, 0x28]);
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.pressureBar, closeTo(9.0, 1e-9));
      expect(received.single.weightG, isNull);
      expect(received.single.elapsedMs, 75);

      await merged.stop();
      await sub.cancel();
    });

    test('works with only weight adapter connected', () async {
      final merged = MergedSampleStream(
        weightAdapter: weightAdapter,
        monotonicClock: () => clockMs,
      );

      final received = <SensorSample>[];
      final sub = merged.samples.listen(received.add);

      await merged.start();

      clockMs = 10_125;
      weightTransport.emitNotification(
        [0x03, 0xCE, 0x00, 0x65, 0x00, 0x00, 0xA8],
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.weightG, 10.1);
      expect(received.single.pressureBar, isNull);
      expect(received.single.tempC, isNull);
      expect(received.single.elapsedMs, 125);

      await merged.stop();
      await sub.cancel();
    });
  });
}