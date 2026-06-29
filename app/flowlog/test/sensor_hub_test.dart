import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, SensorAdapter;
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
}