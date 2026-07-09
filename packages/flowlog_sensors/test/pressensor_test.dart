import 'dart:async';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:test/test.dart';

class _MockPressensorBleTransport implements PressensorBleTransport {
  _MockPressensorBleTransport({
    this.discoveredDeviceIds = const ['prs-1'],
  });

  final List<String> discoveredDeviceIds;
  final writtenZeroCommands = <List<int>>[];
  final _pressureController = StreamController<List<int>>.broadcast();

  bool connected = false;
  String? connectedDeviceId;

  void emitPressure(List<int> data) {
    _pressureController.add(data);
  }

  @override
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return discoveredDeviceIds;
  }

  @override
  Future<void> connect({String? deviceId}) async {
    connected = true;
    connectedDeviceId = deviceId;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    connectedDeviceId = null;
  }

  @override
  Stream<List<int>> subscribePressure() => _pressureController.stream;

  @override
  Future<void> writeZeroPressure([
    List<int> payload = pressensorZeroPressureCommand,
  ]) async {
    writtenZeroCommands.add(List<int>.from(payload));
  }

  int? batteryPercent = 85;

  @override
  Future<int?> readBatteryPercent() async => batteryPercent;

  Future<void> close() => _pressureController.close();
}

void main() {
  group('pressensor protocol', () {
    test('PRS name prefix filter matches Pressensor devices', () {
      expect(isPressensorDeviceName('PRS-CJ2'), isTrue);
      expect(isPressensorDeviceName('PRS123'), isTrue);
      expect(isPressensorDeviceName('Decent Scale'), isFalse);
      expect(isPressensorDeviceName('prs-lowercase'), isFalse);
    });

    test('zero pressure command is documented single-byte payload', () {
      expect(pressensorZeroPressureCommand, [0x00]);
    });

    test('exposes pressure service and characteristic UUIDs', () {
      expect(
        pressensorPressureCharacteristicUuid,
        '873ae82b-4c5a-4342-b539-9d900bf7ebd0',
      );
      expect(
        pressensorZeroPressureCharacteristicUuid,
        '873ae82c-4c5a-4342-b539-9d900bf7ebd0',
      );
    });
  });

  group('parsePressureNotify', () {
    test('parses 2-byte pressure notify from mbar to bar', () {
      // 9000 mbar = 9.0 bar
      final reading = parsePressureNotify([0x23, 0x28]);

      expect(reading.pressureBar, closeTo(9.0, 1e-9));
      expect(reading.tempC, isNull);
    });

    test('parses signed negative pressure', () {
      // -100 mbar = -0.1 bar
      final reading = parsePressureNotify([0xFF, 0x9C]);

      expect(reading.pressureBar, closeTo(-0.1, 1e-9));
      expect(reading.tempC, isNull);
    });

    test('parses temperature on every 16th notification (4-byte payload)', () {
      // 8500 mbar + 93.1 °C (931 tenths)
      final reading = parsePressureNotify([0x21, 0x34, 0x03, 0xA3]);

      expect(reading.pressureBar, closeTo(8.5, 1e-9));
      expect(reading.tempC, closeTo(93.1, 1e-9));
    });

    test('parses signed negative temperature', () {
      // 0 mbar + -5.0 °C (-50 tenths)
      final reading = parsePressureNotify([0x00, 0x00, 0xFF, 0xCE]);

      expect(reading.pressureBar, 0.0);
      expect(reading.tempC, closeTo(-5.0, 1e-9));
    });

    test('rejects payloads shorter than 2 bytes', () {
      expect(
        () => parsePressureNotify([0x01]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parsePressensorBatteryLevel', () {
    test('parses single-byte BLE battery characteristic', () {
      expect(parsePressensorBatteryLevel([72]), 72);
      expect(parsePressensorBatteryLevel([150]), 100);
      expect(parsePressensorBatteryLevel(const []), isNull);
    });

    test('low-battery helpers use configured threshold', () {
      expect(isPressensorLowBattery(20), isTrue);
      expect(isPressensorLowBattery(21), isFalse);
      expect(
        pressensorLowBatteryWarning(15),
        'Pressensor battery low (15%). Charge before your next session.',
      );
      expect(pressensorLowBatteryWarning(80), isNull);
    });
  });

  group('PressensorBleAdapter', () {
    late _MockPressensorBleTransport transport;
    late PressensorBleAdapter adapter;

    setUp(() {
      transport = _MockPressensorBleTransport();
      adapter = PressensorBleAdapter(transport: transport, deviceId: 'prs-1');
    });

    tearDown(() async {
      await adapter.disconnect();
      await transport.close();
    });

    test('scanForDevices delegates to transport', () async {
      final devices = await adapter.scanForDevices();
      expect(devices, ['prs-1']);
    });

    test('zeroPressure writes zero command via transport', () async {
      await adapter.zeroPressure();

      expect(transport.writtenZeroCommands, [
        pressensorZeroPressureCommand,
      ]);
    });

    test('connect reads battery percent from transport', () async {
      transport.batteryPercent = 18;

      await adapter.connect();

      expect(adapter.batteryPercent, 18);
    });

    test('connect emits lifecycle states and parsed samples', () async {
      final states = <ConnectionState>[];
      final samples = <SensorSample>[];

      final stateSub = adapter.state.listen(states.add);
      final sampleSub = adapter.samples.listen(samples.add);

      await adapter.connect();
      transport.emitPressure([0x23, 0x28]);
      transport.emitPressure([0x21, 0x34, 0x03, 0xA3]);
      await Future<void>.delayed(Duration.zero);

      expect(
        states,
        [
          ConnectionState.connecting,
          ConnectionState.connected,
        ],
      );
      expect(samples, hasLength(2));
      expect(samples.first.pressureBar, closeTo(9.0, 1e-9));
      expect(samples.first.tempC, isNull);
      expect(samples.last.pressureBar, closeTo(8.5, 1e-9));
      expect(samples.last.tempC, closeTo(93.1, 1e-9));
      expect(samples.first.elapsedMs, greaterThanOrEqualTo(0));

      await stateSub.cancel();
      await sampleSub.cancel();
    });

    test('disconnect ends in disconnected state', () async {
      final states = <ConnectionState>[];
      final sub = adapter.state.listen(states.add);

      await adapter.connect();
      await adapter.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states.last, ConnectionState.disconnected);
      expect(transport.connected, isFalse);

      await sub.cancel();
    });
  });
}