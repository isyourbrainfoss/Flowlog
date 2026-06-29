import 'dart:async';
import 'dart:io';

import 'package:flowlog/sensors/sensor_kind.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
// Decent scale BLE types live in a sub-library to keep flowlog_sensors pure Dart.
// ignore: implementation_imports
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// A BLE device discovered during a sensor scan.
class BleDiscoveredDevice {
  const BleDiscoveredDevice({
    required this.remoteId,
    required this.name,
    required this.kind,
    required this.rssi,
  });

  final String remoteId;
  final String name;
  final SensorKind kind;
  final int rssi;
}

/// Outcome of assigning a BLE remote id to a paired sensor entry.
enum BleScanAssignOutcome {
  assigned,
  notFound,
  multiple,
  unavailable,
}

/// Result of [BleConnectionBackend.scanAndAssign].
class BleScanAssignResult {
  const BleScanAssignResult._({
    required this.outcome,
    this.device,
    this.devices = const [],
    this.message,
  });

  final BleScanAssignOutcome outcome;
  final BleDiscoveredDevice? device;
  final List<BleDiscoveredDevice> devices;
  final String? message;

  factory BleScanAssignResult.assigned(BleDiscoveredDevice device) {
    return BleScanAssignResult._(
      outcome: BleScanAssignOutcome.assigned,
      device: device,
    );
  }

  factory BleScanAssignResult.notFound() {
    return const BleScanAssignResult._(outcome: BleScanAssignOutcome.notFound);
  }

  factory BleScanAssignResult.multiple(List<BleDiscoveredDevice> devices) {
    return BleScanAssignResult._(
      outcome: BleScanAssignOutcome.multiple,
      devices: devices,
    );
  }

  factory BleScanAssignResult.unavailable(String message) {
    return BleScanAssignResult._(
      outcome: BleScanAssignOutcome.unavailable,
      message: message,
    );
  }
}

/// Returns true when [advName] matches a Flowlog-supported sensor of [kind].
@visibleForTesting
bool matchesSensorKind(String advName, SensorKind kind) {
  return switch (kind) {
    SensorKind.pressensor => isPressensorDeviceName(advName),
    SensorKind.scale => advName == DecentScaleConstants.deviceName,
  };
}

/// High-level BLE operations used by [SensorHub].
abstract class BleConnectionBackend {
  Future<String?> ensureReady();

  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
  });

  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  });
}

/// BLE backend for platforms without Bluetooth support (desktop CI, tests).
class UnsupportedBleConnectionBackend implements BleConnectionBackend {
  const UnsupportedBleConnectionBackend({this.message});

  final String? message;

  @override
  Future<String?> ensureReady() async {
    return message ??
        'Bluetooth is not available on this device. '
            'Pair sensors on Android or Linux with Bluetooth enabled.';
  }

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return const [];
  }

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    throw UnsupportedError(
      (await ensureReady()) ?? 'Bluetooth unavailable',
    );
  }
}

/// flutter_blue_plus wiring for Android and Linux.
class FlutterBlueBleConnectionBackend implements BleConnectionBackend {
  @override
  Future<String?> ensureReady() async {
    if (!Platform.isAndroid && !Platform.isLinux) {
      return 'Bluetooth connect is only enabled on Android and Linux.';
    }

    if (await FlutterBluePlus.isSupported == false) {
      return 'Bluetooth is not supported on this device.';
    }

    if (Platform.isAndroid) {
      try {
        await FlutterBluePlus.turnOn();
      } on Object {
        // User may decline; adapter state check below surfaces a clear message.
      }
    }

    final state = await FlutterBluePlus.adapterState
        .where((value) => value != BluetoothAdapterState.unknown)
        .first
        .timeout(const Duration(seconds: 5), onTimeout: () {
      return BluetoothAdapterState.unknown;
    });

    return switch (state) {
      BluetoothAdapterState.on => null,
      BluetoothAdapterState.off =>
        'Turn on Bluetooth to scan and connect sensors.',
      BluetoothAdapterState.unauthorized =>
        'Bluetooth permission is required to connect sensors.',
      BluetoothAdapterState.unavailable =>
        'Bluetooth is unavailable on this device.',
      BluetoothAdapterState.turningOn || BluetoothAdapterState.turningOff =>
        'Bluetooth is still starting. Try again in a moment.',
      BluetoothAdapterState.unknown =>
        'Bluetooth state is unknown. Try again.',
    };
  }

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final readyError = await ensureReady();
    if (readyError != null) {
      return const [];
    }

    final found = <String, BleDiscoveredDevice>{};

    final subscription = FlutterBluePlus.onScanResults.listen(
      (results) {
        for (final result in results) {
          final name = result.advertisementData.advName;
          if (!matchesSensorKind(name, kind)) {
            continue;
          }
          found[result.device.remoteId.str] = BleDiscoveredDevice(
            remoteId: result.device.remoteId.str,
            name: name,
            kind: kind,
            rssi: result.rssi,
          );
        }
      },
      onError: (_) {},
    );

    FlutterBluePlus.cancelWhenScanComplete(subscription);

    try {
      await FlutterBluePlus.adapterState
          .where((state) => state == BluetoothAdapterState.on)
          .first;
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withNames: kind == SensorKind.scale
            ? [DecentScaleConstants.deviceName]
            : const [],
      );
      await FlutterBluePlus.isScanning
          .where((scanning) => scanning == false)
          .first;
    } finally {
      await subscription.cancel();
    }

    final devices = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return devices;
  }

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    return switch (kind) {
      SensorKind.pressensor => PressensorBleAdapter(
          transport: FlutterBluePressensorTransport(deviceId: bleRemoteId),
          deviceId: bleRemoteId,
        ),
      SensorKind.scale => DecentScaleBleAdapter(
          transport: FlutterBlueDecentScaleTransport(remoteId: bleRemoteId),
        ),
    };
  }
}

/// Creates the production BLE backend on supported platforms.
BleConnectionBackend createBleConnectionBackend() {
  if (Platform.isAndroid || Platform.isLinux) {
    return FlutterBlueBleConnectionBackend();
  }
  return const UnsupportedBleConnectionBackend();
}

/// Pressensor transport backed by flutter_blue_plus.
class FlutterBluePressensorTransport implements PressensorBleTransport {
  FlutterBluePressensorTransport({this.deviceId});

  final String? deviceId;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _pressureCharacteristic;
  BluetoothCharacteristic? _zeroCharacteristic;
  StreamSubscription<List<int>>? _pressureSubscription;
  final _pressureController = StreamController<List<int>>.broadcast();

  @override
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final backend = FlutterBlueBleConnectionBackend();
    final devices = await backend.scan(
      SensorKind.pressensor,
      timeout: timeout,
    );
    return devices.map((device) => device.remoteId).toList(growable: false);
  }

  @override
  Future<void> connect({String? deviceId}) async {
    final targetId = deviceId ?? this.deviceId;
    if (targetId == null || targetId.isEmpty) {
      throw StateError('Pressensor device id is required to connect.');
    }

    _device = BluetoothDevice.fromId(targetId);
    await _device!.connect(license: License.nonprofit);
    await _discoverCharacteristics();
  }

  Future<void> _discoverCharacteristics() async {
    final device = _device;
    if (device == null) {
      throw StateError('Pressensor device is not connected.');
    }

    final services = await device.discoverServices();
    BluetoothCharacteristic? pressure;
    BluetoothCharacteristic? zero;

    for (final service in services) {
      if (service.uuid != Guid(pressensorPressureServiceUuid)) {
        continue;
      }
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == Guid(pressensorPressureCharacteristicUuid)) {
          pressure = characteristic;
        } else if (characteristic.uuid ==
            Guid(pressensorZeroPressureCharacteristicUuid)) {
          zero = characteristic;
        }
      }
    }

    if (pressure == null || zero == null) {
      throw StateError('Pressensor pressure characteristics not found.');
    }

    _pressureCharacteristic = pressure;
    _zeroCharacteristic = zero;
  }

  @override
  Stream<List<int>> subscribePressure() {
    final characteristic = _pressureCharacteristic;
    final device = _device;
    if (characteristic == null || device == null) {
      throw StateError('Pressensor is not connected.');
    }

    unawaited(_pressureSubscription?.cancel());
    _pressureSubscription = characteristic.onValueReceived.listen(
      _pressureController.add,
      onError: _pressureController.addError,
    );
    device.cancelWhenDisconnected(_pressureSubscription!);
    unawaited(characteristic.setNotifyValue(true));
    return _pressureController.stream;
  }

  @override
  Future<void> writeZeroPressure([
    List<int> payload = pressensorZeroPressureCommand,
  ]) async {
    final characteristic = _zeroCharacteristic;
    if (characteristic == null) {
      throw StateError('Pressensor zero characteristic is unavailable.');
    }
    await characteristic.write(payload);
  }

  @override
  Future<void> disconnect() async {
    await _pressureSubscription?.cancel();
    _pressureSubscription = null;
    await _pressureController.close();
    final device = _device;
    _device = null;
    _pressureCharacteristic = null;
    _zeroCharacteristic = null;
    if (device != null) {
      await device.disconnect();
    }
  }
}

/// Decent Scale transport backed by flutter_blue_plus.
class FlutterBlueDecentScaleTransport implements DecentScaleTransport {
  FlutterBlueDecentScaleTransport({required this.remoteId});

  final String remoteId;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _notifyCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  final _notifications = StreamController<List<int>>.broadcast();

  @override
  Stream<List<int>> get notifications => _notifications.stream;

  @override
  Future<void> connect() async {
    _device = BluetoothDevice.fromId(remoteId);
    await _device!.connect(license: License.nonprofit);
    await _discoverCharacteristics();
  }

  Future<void> _discoverCharacteristics() async {
    final device = _device;
    if (device == null) {
      throw StateError('Decent Scale device is not connected.');
    }

    final services = await device.discoverServices();
    BluetoothCharacteristic? notify;
    BluetoothCharacteristic? write;

    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == Guid(DecentScaleConstants.notifyUuid)) {
          notify = characteristic;
        } else if (characteristic.uuid == Guid(DecentScaleConstants.writeUuid)) {
          write = characteristic;
        }
      }
    }

    if (notify == null || write == null) {
      throw StateError('Decent Scale characteristics not found.');
    }

    _notifyCharacteristic = notify;
    _writeCharacteristic = write;
  }

  @override
  Future<void> subscribeNotifications() async {
    final characteristic = _notifyCharacteristic;
    final device = _device;
    if (characteristic == null || device == null) {
      throw StateError('Decent Scale is not connected.');
    }

    final subscription = characteristic.onValueReceived.listen(
      _notifications.add,
      onError: _notifications.addError,
    );
    device.cancelWhenDisconnected(subscription);
    await characteristic.setNotifyValue(true);
  }

  @override
  Future<void> writeCommand(List<int> command) async {
    final characteristic = _writeCharacteristic;
    if (characteristic == null) {
      throw StateError('Decent Scale write characteristic is unavailable.');
    }
    await characteristic.write(command);
  }

  @override
  Future<void> disconnect() async {
    final device = _device;
    _device = null;
    _notifyCharacteristic = null;
    _writeCharacteristic = null;
    if (!_notifications.isClosed) {
      await _notifications.close();
    }
    if (device != null) {
      await device.disconnect();
    }
  }
}