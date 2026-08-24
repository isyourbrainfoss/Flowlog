import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show
        ConnectionState,
        DecentScaleBleAdapter,
        MockDecentScaleTransport,
        PressensorBleAdapter,
        PressensorBleTransport,
        SensorAdapter,
        SensorSample,
        pressensorZeroPressureCommand;
import 'package:flutter_test/flutter_test.dart';

class _ReadyBleBackend extends BleConnectionBackend {
  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
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
    test('force-reconnects a silent pressensor even when hub still reports connected',
        () async {
      final backend = _PressensorConnectBackend();
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

      final adapter = hub.activeAdapterFor(SensorKind.pressensor);
      expect(adapter, isA<PressensorBleAdapter>());
      expect(
        (adapter as PressensorBleAdapter).isPressureStreamSilent(
          silentFor: const Duration(seconds: 3),
        ),
        isTrue,
      );

      await hub.reconnectPairedDevices();

      expect(backend.connectCalls, 2);
      expect(hub.devices.first.state, ConnectionState.connected);
      expect(
        hub.reconnectLog.where((e) => e.outcome == ReconnectOutcome.connected),
        hasLength(2),
      );
    });

    test('skips reconnect for a pressensor that is emitting samples', () async {
      final backend = _PressensorConnectBackend();
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor);
      hub.assignBleRemoteId(
        SensorKind.pressensor,
        bleRemoteId: 'AA:BB:CC:DD:EE:FF',
        name: 'PRS-live',
      );

      await hub.connect(hub.devices.first.id);
      expect(backend.connectCalls, 1);

      backend.transport!.emitPressure([0x23, 0x28]);
      await Future<void>.delayed(Duration.zero);

      final adapter = hub.activeAdapterFor(SensorKind.pressensor);
      expect(adapter, isA<PressensorBleAdapter>());
      expect(
        (adapter as PressensorBleAdapter).isPressureStreamSilent(
          silentFor: const Duration(seconds: 3),
        ),
        isFalse,
      );

      await hub.reconnectPairedDevices();
      expect(backend.connectCalls, 1);
      expect(hub.devices.first.state, ConnectionState.connected);
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

    test('setScaleRecoveryEnabled(false) skips hard reconnect after silent wait', () {
      fakeAsync((async) {
        final backend = _ScaleConnectBackend();
        final hub = SensorHub(bleBackend: backend);
        hub.addDevice(SensorKind.scale);
        hub.assignBleRemoteId(
          SensorKind.scale,
          bleRemoteId: 'scale-1',
          name: 'Decent Scale',
        );

        unawaited(hub.connect(hub.devices.first.id));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();
        expect(hub.devices.first.state, ConnectionState.connected);
        expect(backend.connectCalls, 1);

        // Silent for the 6s recovery threshold, then start recover + 2s wait.
        async.elapse(const Duration(seconds: 6));
        unawaited(hub.recoverSilentScalesForTest());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();

        hub.setScaleRecoveryEnabled(false);
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(
          backend.connectCalls,
          1,
          reason: 'hard reconnect must not run after recovery is disabled mid-wait',
        );

        hub.dispose();
        async.flushMicrotasks();
      });
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
    Future<void>? abort,
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

class _PressensorConnectBackend implements BleConnectionBackend {
  int connectCalls = 0;
  _HubPressensorTransport? transport;

  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
  }) async =>
      const [];

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    connectCalls += 1;
    transport = _HubPressensorTransport();
    return PressensorBleAdapter(
      transport: transport!,
      deviceId: bleRemoteId,
    );
  }
}

class _HubPressensorTransport implements PressensorBleTransport {
  final _pressure = StreamController<List<int>>.broadcast();

  void emitPressure(List<int> data) => _pressure.add(data);

  @override
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async =>
      const [];

  @override
  Future<void> connect({String? deviceId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<List<int>> subscribePressure() => _pressure.stream;

  @override
  Future<void> writeZeroPressure([
    List<int> payload = pressensorZeroPressureCommand,
  ]) async {}

  @override
  Future<int?> readBatteryPercent() async => 85;
}

class _ScaleConnectBackend implements BleConnectionBackend {
  int connectCalls = 0;

  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
  }) async =>
      const [];

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    connectCalls += 1;
    return DecentScaleBleAdapter(transport: MockDecentScaleTransport());
  }
}