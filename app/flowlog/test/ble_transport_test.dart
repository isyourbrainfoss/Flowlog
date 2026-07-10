import 'dart:async';

import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingBleBackend implements BleConnectionBackend {
  // ignore: unused_element_parameter
  _RecordingBleBackend({
    this.readyMessage, // ignore: unused_element_parameter
    this.discovered = const [],
    this.connectError, // ignore: unused_element_parameter
  });

  String? readyMessage;
  List<BleDiscoveredDevice> discovered;
  Object? connectError;
  int scanCalls = 0;
  int connectCalls = 0;

  @override
  Future<String?> ensureReady() async => readyMessage;

  @override
  Future<List<BleDiscoveredDevice>> scan(SensorKind kind, {Duration timeout = const Duration(seconds: 10)}) async {
    scanCalls += 1;
    return discovered;
  }

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    connectCalls += 1;
    if (connectError != null) {
      throw connectError!;
    }
    return _FakeSensorAdapter();
  }
}

class _FakeSensorAdapter implements SensorAdapter {
  final _state = StreamController<ConnectionState>.broadcast();
  final _samples = StreamController<SensorSample>.broadcast();

  @override
  Stream<ConnectionState> get state => _state.stream;

  @override
  Stream<SensorSample> get samples => _samples.stream;

  @override
  Future<void> connect() async {
    _state.add(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _state.add(ConnectionState.disconnected);
    await _state.close();
    await _samples.close();
  }
}

void main() {
  group('matchesSensorKind', () {
    test('detects Pressensor PRS advertisements', () {
      expect(matchesSensorKind('PRS-CJ2', SensorKind.pressensor), isTrue);
      expect(matchesSensorKind('PRS39739', SensorKind.pressensor), isTrue);
      expect(matchesSensorKind('Decent Scale', SensorKind.pressensor), isFalse);
    });

    test('detects Decent Scale advertisements', () {
      expect(matchesSensorKind('Decent Scale', SensorKind.scale), isTrue);
      expect(matchesSensorKind('PRS-1', SensorKind.scale), isFalse);
    });
  });

  group('resolveBleDeviceName', () {
    test('prefers advertisement name when present', () {
      expect(
        resolveBleDeviceName(advName: 'PRS-CJ2', platformName: ''),
        'PRS-CJ2',
      );
    });

    test('falls back to platform name for Linux-style scan results', () {
      expect(
        resolveBleDeviceName(advName: '', platformName: 'PRS39739'),
        'PRS39739',
      );
    });
  });

  group('UnsupportedBleConnectionBackend', () {
    test('reports unavailable on ensureReady', () async {
      const backend = UnsupportedBleConnectionBackend();
      final message = await backend.ensureReady();
      expect(message, contains('Bluetooth is not available'));
    });
  });

  group('SensorHub BLE wiring', () {
    test('connect fails gracefully without BLE remote id', () async {
      final backend = _RecordingBleBackend();
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor);
      final deviceId = hub.devices.first.id;

      await hub.connect(deviceId);

      expect(backend.connectCalls, 0);
      expect(hub.lastError, contains('Scan for this sensor first'));
      expect(hub.devices.first.state, ConnectionState.disconnected);
    });

    test('scanAndAssign auto-assigns a single discovered device', () async {
      final backend = _RecordingBleBackend(
        discovered: const [
          BleDiscoveredDevice(
            remoteId: 'AA:BB:CC:DD:EE:FF',
            name: 'PRS-CJ2',
            kind: SensorKind.pressensor,
            rssi: -55,
          ),
        ],
      );
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);
      hub.addDevice(SensorKind.pressensor);

      final result = await hub.scanAndAssign(SensorKind.pressensor);

      expect(result.outcome, BleScanAssignOutcome.assigned);
      expect(hub.devices.first.bleRemoteId, 'AA:BB:CC:DD:EE:FF');
      expect(hub.rssiFor(hub.devices.first.id), -55);
    });

    test('connect uses backend adapter when BLE id is assigned', () async {
      final backend = _RecordingBleBackend();
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);
      hub.addDevice(SensorKind.scale);
      hub.assignBleRemoteId(
        SensorKind.scale,
        bleRemoteId: 'scale-remote-id',
        name: 'Decent Scale',
      );

      await hub.connect(hub.devices.first.id);

      expect(backend.connectCalls, 1);
      expect(hub.devices.first.state, ConnectionState.connected);
      expect(hub.reconnectLog.last.outcome, ReconnectOutcome.connected);
    });
  });
}

