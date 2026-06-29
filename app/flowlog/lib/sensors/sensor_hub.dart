import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;

/// Known sensor types Flowlog supports pairing with.
enum SensorKind {
  pressensor,
  scale,
}

extension SensorKindLabels on SensorKind {
  String get defaultName => switch (this) {
        SensorKind.pressensor => 'Pressensor PRS',
        SensorKind.scale => 'Decent Scale',
      };

  String get subtitle => switch (this) {
        SensorKind.pressensor => 'Pressure sensor (BLE)',
        SensorKind.scale => 'BLE scale',
      };

  IconData get icon => switch (this) {
        SensorKind.pressensor => Icons.speed,
        SensorKind.scale => Icons.scale,
      };
}

/// A user-paired sensor entry (persisted in memory for this session).
class PairedSensorEntry {
  PairedSensorEntry({
    required this.id,
    required this.name,
    required this.kind,
    this.state = ConnectionState.disconnected,
  });

  final String id;
  final String name;
  final SensorKind kind;
  ConnectionState state;

  PairedSensorEntry copyWith({ConnectionState? state}) {
    return PairedSensorEntry(
      id: id,
      name: name,
      kind: kind,
      state: state ?? this.state,
    );
  }
}

/// In-app registry for paired sensors and their connection state.
///
/// BLE transport wiring (flutter_blue_plus) is not hooked up yet — [connect]
/// simulates an attempt and leaves the device disconnected with feedback.
class SensorHub extends ChangeNotifier {
  SensorHub({List<PairedSensorEntry>? initialDevices})
      : _devices = List.of(initialDevices ?? []);

  final List<PairedSensorEntry> _devices;
  int _idCounter = 0;

  List<PairedSensorEntry> get devices => List.unmodifiable(_devices);

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

  void removeDevice(String id) {
    final removed = _devices.length;
    _devices.removeWhere((device) => device.id == id);
    if (_devices.length != removed) {
      notifyListeners();
    }
  }

  /// Attempt BLE connect — stub until flutter_blue_plus UI lands.
  Future<void> connect(String id) async {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) {
      return;
    }

    _devices[index] = _devices[index].copyWith(state: ConnectionState.connecting);
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 400));

    // Honest default: parsers exist but live BLE UI is not wired yet.
    _devices[index] = _devices[index].copyWith(state: ConnectionState.disconnected);
    notifyListeners();
  }

  void disconnect(String id) {
    final index = _devices.indexWhere((device) => device.id == id);
    if (index < 0) {
      return;
    }
    _devices[index] =
        _devices[index].copyWith(state: ConnectionState.disconnected);
    notifyListeners();
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
}