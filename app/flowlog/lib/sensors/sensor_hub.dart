import 'dart:async';

import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_kind.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState, SensorAdapter;
import 'package:flutter/material.dart' hide ConnectionState;

export 'package:flowlog/sensors/sensor_kind.dart';

/// Outcome of a recorded reconnect attempt.
enum ReconnectOutcome {
  attempted,
  connected,
  failed,
}

/// A reconnect attempt recorded for sensor diagnostics.
class SensorReconnectEvent {
  SensorReconnectEvent({
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    required this.outcome,
    this.message,
  });

  final String deviceId;
  final String deviceName;
  final DateTime timestamp;
  final ReconnectOutcome outcome;
  final String? message;
}

/// A user-paired sensor entry (persisted in memory for this session).
class PairedSensorEntry {
  PairedSensorEntry({
    required this.id,
    required this.name,
    required this.kind,
    this.bleRemoteId,
    this.state = ConnectionState.disconnected,
  });

  final String id;
  final String name;
  final SensorKind kind;

  /// BLE remote id from [BleDiscoveredDevice.remoteId], assigned after scan.
  final String? bleRemoteId;
  ConnectionState state;

  PairedSensorEntry copyWith({
    ConnectionState? state,
    String? bleRemoteId,
    String? name,
  }) {
    return PairedSensorEntry(
      id: id,
      name: name ?? this.name,
      kind: kind,
      bleRemoteId: bleRemoteId ?? this.bleRemoteId,
      state: state ?? this.state,
    );
  }
}

/// In-app registry for paired sensors and their connection state.
class SensorHub extends ChangeNotifier {
  SensorHub({
    List<PairedSensorEntry>? initialDevices,
    BleConnectionBackend? bleBackend,
  })  : _devices = List.of(initialDevices ?? []),
        _bleBackend = bleBackend ?? const UnsupportedBleConnectionBackend();

  final List<PairedSensorEntry> _devices;
  final List<SensorReconnectEvent> _reconnectLog = [];
  final Map<String, int?> _rssiByDevice = {};
  final Map<String, SensorAdapter> _activeAdapters = {};
  final Map<String, StreamSubscription<ConnectionState>> _adapterStateSubs = {};
  final BleConnectionBackend _bleBackend;
  int _idCounter = 0;
  String? _lastError;

  List<PairedSensorEntry> get devices => List.unmodifiable(_devices);

  /// Chronological reconnect attempts (newest last).
  List<SensorReconnectEvent> get reconnectLog => List.unmodifiable(_reconnectLog);

  /// Most recent connection error across all sensors.
  String? get lastError => _lastError;

  /// RSSI in dBm from the most recent scan, when available.
  int? rssiFor(String deviceId) => _rssiByDevice[deviceId];

  bool hasKind(SensorKind kind) =>
      _devices.any((device) => device.kind == kind);

  ConnectionState stateFor(SensorKind kind) {
    final match = _devices.where((device) => device.kind == kind);
    if (match.isEmpty) {
      return ConnectionState.disconnected;
    }
    return match.first.state;
  }

  ConnectionState get pressensorState => stateFor(SensorKind.pressensor);

  ConnectionState get scaleState => stateFor(SensorKind.scale);

  /// Active adapter for a connected device of [kind], when [connect] succeeded.
  SensorAdapter? activeAdapterFor(SensorKind kind) {
    for (final device in _devices) {
      if (device.kind == kind && device.state == ConnectionState.connected) {
        return _activeAdapters[device.id];
      }
    }
    return null;
  }

  /// Adds a paired device of [kind] if none exists yet.
  bool addDevice(SensorKind kind, {String? name}) {
    if (hasKind(kind)) {
      return false;
    }
    _idCounter += 1;
    _devices.add(
      PairedSensorEntry(
        id: 'sensor-$_idCounter',
        name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : kind.defaultName,
        kind: kind,
      ),
    );
    notifyListeners();
    return true;
  }

  /// Assigns a scanned BLE remote id to the paired entry of [kind].
  bool assignBleRemoteId(
    SensorKind kind, {
    required String bleRemoteId,
    String? name,
    int? rssi,
  }) {
    final index = _devices.indexWhere((device) => device.kind == kind);
    if (index < 0) {
      return false;
    }

    final device = _devices[index];
    _devices[index] = device.copyWith(
      bleRemoteId: bleRemoteId,
      name: name?.trim().isNotEmpty ?? false ? name!.trim() : device.name,
    );
    if (rssi != null) {
      _rssiByDevice[device.id] = rssi;
    }
    notifyListeners();
    return true;
  }

  /// Scans for a sensor of [kind] and auto-assigns when exactly one is found.
  Future<BleScanAssignResult> scanAndAssign(SensorKind kind) async {
    final readyError = await _bleBackend.ensureReady();
    if (readyError != null) {
      setLastError(readyError);
      return BleScanAssignResult.unavailable(readyError);
    }

    final discovered = await _bleBackend.scan(kind);
    if (discovered.isEmpty) {
      const message = 'No nearby sensor found. Make sure it is powered on.';
      setLastError(message);
      return BleScanAssignResult.notFound();
    }

    if (discovered.length > 1) {
      return BleScanAssignResult.multiple(discovered);
    }

    final match = discovered.first;
    assignBleRemoteId(
      kind,
      bleRemoteId: match.remoteId,
      name: match.name,
      rssi: match.rssi,
    );
    setLastError(null);
    return BleScanAssignResult.assigned(match);
  }

  void removeDevice(String id) {
    final before = _devices.length;
    unawaited(disconnect(id));
    _devices.removeWhere((device) => device.id == id);
    if (_devices.length != before) {
      _rssiByDevice.remove(id);
      notifyListeners();
    }
  }

  /// Records a reconnect attempt for the diagnostics screen.
  void recordReconnect({
    required String deviceId,
    required String deviceName,
    required ReconnectOutcome outcome,
    String? message,
    DateTime? timestamp,
  }) {
    _reconnectLog.add(
      SensorReconnectEvent(
        deviceId: deviceId,
        deviceName: deviceName,
        outcome: outcome,
        message: message,
        timestamp: timestamp ?? DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void clearReconnectLog() {
    if (_reconnectLog.isEmpty) {
      return;
    }
    _reconnectLog.clear();
    notifyListeners();
  }

  void setLastError(String? message) {
    if (_lastError == message) {
      return;
    }
    _lastError = message;
    notifyListeners();
  }

  /// Updates RSSI for [deviceId] from scan results.
  void updateRssi(String deviceId, int? rssi) {
    _rssiByDevice[deviceId] = rssi;
    notifyListeners();
  }

  /// Attempt BLE connect using flutter_blue_plus when the platform supports it.
  Future<void> connect(String id) async {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) {
      return;
    }

    final device = _devices[index];
    _devices[index] = device.copyWith(state: ConnectionState.connecting);
    _rssiByDevice[id] = null;
    recordReconnect(
      deviceId: id,
      deviceName: device.name,
      outcome: ReconnectOutcome.attempted,
    );
    notifyListeners();

    final readyError = await _bleBackend.ensureReady();
    if (readyError != null) {
      await _failConnect(index, device, readyError);
      return;
    }

    final bleRemoteId = device.bleRemoteId;
    if (bleRemoteId == null || bleRemoteId.isEmpty) {
      await _failConnect(
        index,
        device,
        'Scan for this sensor first to assign its BLE device id.',
      );
      return;
    }

    try {
      await _adapterStateSubs.remove(id)?.cancel();
      await _activeAdapters.remove(id)?.disconnect();

      final adapter = await _bleBackend.createAdapter(
        kind: device.kind,
        bleRemoteId: bleRemoteId,
      );
      _activeAdapters[id] = adapter;
      _adapterStateSubs[id] = adapter.state.listen((state) {
        _onAdapterStateChanged(id, state);
      });

      await adapter.connect();

      final currentIndex = _devices.indexWhere((entry) => entry.id == id);
      if (currentIndex < 0) {
        return;
      }

      _devices[currentIndex] =
          _devices[currentIndex].copyWith(state: ConnectionState.connected);
      setLastError(null);
      recordReconnect(
        deviceId: id,
        deviceName: device.name,
        outcome: ReconnectOutcome.connected,
      );
      notifyListeners();
    } on Object catch (error) {
      final message = 'BLE connect failed: $error';
      await _failConnect(index, device, message);
      await _adapterStateSubs.remove(id)?.cancel();
      await _activeAdapters.remove(id)?.disconnect();
    }
  }

  Future<void> _failConnect(
    int index,
    PairedSensorEntry device,
    String message,
  ) async {
    _devices[index] = device.copyWith(state: ConnectionState.disconnected);
    setLastError(message);
    recordReconnect(
      deviceId: device.id,
      deviceName: device.name,
      outcome: ReconnectOutcome.failed,
      message: message,
    );
    notifyListeners();
  }

  void _onAdapterStateChanged(String id, ConnectionState state) {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) {
      return;
    }

    _devices[index] = _devices[index].copyWith(state: state);
    if (state == ConnectionState.error) {
      setLastError('Sensor link error ($id).');
    }
    notifyListeners();
  }

  Future<void> disconnect(String id) async {
    await _adapterStateSubs.remove(id)?.cancel();
    final adapter = _activeAdapters.remove(id);
    if (adapter != null) {
      await adapter.disconnect();
    }

    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) {
      return;
    }
    _devices[index] =
        _devices[index].copyWith(state: ConnectionState.disconnected);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _adapterStateSubs.values) {
      unawaited(subscription.cancel());
    }
    _adapterStateSubs.clear();
    for (final adapter in _activeAdapters.values) {
      unawaited(adapter.disconnect());
    }
    _activeAdapters.clear();
    super.dispose();
  }
}

/// Provides [SensorHub] to the widget tree.
class SensorHubScope extends InheritedNotifier<SensorHub> {
  const SensorHubScope({
    required SensorHub hub,
    required super.child,
    super.key,
  }) : super(notifier: hub);

  static SensorHub of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SensorHubScope>();
    assert(scope != null, 'SensorHubScope not found in context');
    return scope!.notifier!;
  }

  static SensorHub? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SensorHubScope>()
        ?.notifier;
  }
}