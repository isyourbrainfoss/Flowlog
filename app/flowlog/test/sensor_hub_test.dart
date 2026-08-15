import 'dart:async';

import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, SensorAdapter, SensorSample;
import 'package:flutter_test/flutter_test.dart';

class _ReadyBleBackend extends BleConnectionBackend {
  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
  }) async =>
      const [];

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  group('SensorHub diagnostics', () {
    test('connect records reconnect log and last error', () async {
      final hub = SensorHub(bleBackend: _ReadyBleBackend());
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor);
      final deviceId = hub.devices.first.id;

      expect(hub.reconnectLog, isEmpty);
      expect(hub.lastError, isNull);

      final connectFuture = hub.connect(deviceId);
      expect(hub.reconnectLog, hasLength(1));
      expect(hub.reconnectLog.first.outcome, ReconnectOutcome.attempted);
      expect(hub.rssiFor(deviceId), isNull);

      await connectFuture;

      expect(hub.reconnectLog, hasLength(2));
      expect(hub.reconnectLog.last.outcome, ReconnectOutcome.failed);
      expect(hub.lastError, contains('Scan for this sensor first'));
      expect(hub.devices.first.state, ConnectionState.disconnected);
    });

    test('recordReconnect and clearReconnectLog', () {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      hub.recordReconnect(
        deviceId: 'sensor-1',
        deviceName: 'Test sensor',
        outcome: ReconnectOutcome.connected,
      );

      expect(hub.reconnectLog, hasLength(1));
      hub.clearReconnectLog();
      expect(hub.reconnectLog, isEmpty);
    });

    test('setLastError and updateRssi notify listeners', () {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      var notifications = 0;
      hub.addListener(() => notifications += 1);

      hub.setLastError('Link lost');
      hub.setLastError('Link lost');
      hub.updateRssi('sensor-1', -62);
      hub.updateRssi('sensor-1', null);

      expect(hub.lastError, 'Link lost');
      expect(hub.rssiFor('sensor-1'), isNull);
      expect(notifications, 3);
    });

    test('removeDevice clears RSSI entry', () {
      final hub = SensorHub()..addDevice(SensorKind.scale);
      addTearDown(hub.dispose);

      final deviceId = hub.devices.first.id;
      hub.updateRssi(deviceId, -70);

      hub.removeDevice(deviceId);

      expect(hub.rssiFor(deviceId), isNull);
      expect(hub.devices, isEmpty);
    });
  });

  group('SensorHub reconnectPairedDevices', () {
    test('force-reconnects even when hub still reports connected', () async {
      final backend = _CountingConnectBackend();
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor);
      hub.assignBleRemoteId(
        SensorKind.pressensor,
        bleRemoteId: 'AA:BB:CC:DD:EE:FF',
        name: 'PRS-test',
      );
      final deviceId = hub.devices.first.id;

      await hub.connect(deviceId);
      expect(hub.devices.first.state, ConnectionState.connected);
      expect(backend.connectCalls, 1);

      // Simulate a zombie "connected" link: hub still says connected, user
      // taps Reconnect. Old code skipped; new code must tear down + reconnect.
      await hub.reconnectPairedDevices();

      expect(backend.connectCalls, 2);
      expect(hub.devices.first.state, ConnectionState.connected);
      expect(
        hub.reconnectLog.where((e) => e.outcome == ReconnectOutcome.connected),
        hasLength(2),
      );
    });

    test('reconnects when currently disconnected', () async {
      final backend = _CountingConnectBackend();
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor);
      hub.assignBleRemoteId(
        SensorKind.pressensor,
        bleRemoteId: '11:22:33:44:55:66',
        name: 'PRS-idle',
      );

      expect(hub.devices.first.state, ConnectionState.disconnected);
      await hub.reconnectPairedDevices();
      expect(backend.connectCalls, 1);
      expect(hub.devices.first.state, ConnectionState.connected);
    });

    test('setScaleRecoveryEnabled is off during brew policy', () {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      expect(hub.scaleRecoveryEnabled, isTrue);
      hub.setScaleRecoveryEnabled(false);
      expect(hub.scaleRecoveryEnabled, isFalse);
      hub.setScaleRecoveryEnabled(true);
      expect(hub.scaleRecoveryEnabled, isTrue);
    });

    test('skips devices without a BLE remote id', () async {
      final backend = _CountingConnectBackend();
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor);
      await hub.reconnectPairedDevices();
      expect(backend.connectCalls, 0);
    });
  });
}

class _CountingConnectBackend implements BleConnectionBackend {
  int connectCalls = 0;

  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
  }) async =>
      const [];

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    connectCalls += 1;
    return _AlwaysConnectAdapter();
  }
}

class _AlwaysConnectAdapter implements SensorAdapter {
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
    if (!_state.isClosed) {
      _state.add(ConnectionState.disconnected);
    }
  }
}