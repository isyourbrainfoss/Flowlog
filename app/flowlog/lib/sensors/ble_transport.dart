import 'dart:async';
import 'dart:io';

import 'package:flowlog/sensors/sensor_kind.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
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

/// Returns true when [name] matches a Flowlog-supported sensor of [kind].
@visibleForTesting
bool matchesSensorKind(String name, SensorKind kind) {
  return switch (kind) {
    SensorKind.pressensor => isPressensorDeviceName(name),
    SensorKind.scale => name == DecentScaleConstants.deviceName,
  };
}

/// Resolves the best available BLE device name for sensor matching.
///
/// Linux reports names via [platformName] only; [advName] is empty there
/// (flutter_blue_plus limitation).
@visibleForTesting
String resolveBleDeviceName({
  required String advName,
  required String platformName,
}) {
  if (advName.isNotEmpty) {
    return advName;
  }
  return platformName;
}

String _bleScanResultName(ScanResult result) {
  return resolveBleDeviceName(
    advName: result.advertisementData.advName,
    platformName: result.device.platformName,
  );
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
          final name = _bleScanResultName(result);
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
      // Use synchronous current value to avoid hanging on .first when state is already reached
      // (newStreamWithInitialValue + .where chains can be racy without it).
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        await FlutterBluePlus.adapterState
            .where((state) => state == BluetoothAdapterState.on)
            .first
            .timeout(const Duration(seconds: 5));
      }

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withNames: kind == SensorKind.scale
            ? [DecentScaleConstants.deviceName]
            : const [],
      );

      // After startScan returns, scanning should be true; wait for the timeout-driven stop.
      // Guard with isScanningNow and a safety timeout so we never hang forever.
      final scanStopTimeout = timeout + const Duration(seconds: 3);
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.isScanning
            .where((scanning) => scanning == false)
            .first
            .timeout(scanStopTimeout);
      }
    } catch (_) {
      // Any timeout or platform hiccup during wait: stop and return whatever we collected.
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    } finally {
      await subscription.cancel();
    }

    if (Platform.isLinux) {
      try {
        await _mergeLinuxCachedDevices(kind: kind, found: found);
      } catch (_) {}
    }

    final devices = found.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
    return devices;
  }

  Future<void> _mergeLinuxCachedDevices({
    required SensorKind kind,
    required Map<String, BleDiscoveredDevice> found,
  }) async {
    try {
      final systemDevices = await FlutterBluePlus.systemDevices(const []);
      for (final device in systemDevices) {
        final name = device.platformName;
        if (!matchesSensorKind(name, kind)) {
          continue;
        }
        found.putIfAbsent(
          device.remoteId.str,
          () => BleDiscoveredDevice(
            remoteId: device.remoteId.str,
            name: name,
            kind: kind,
            rssi: -128,
          ),
        );
      }
    } on Object {
      // Discovery results are still usable when the system device list fails.
    }
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
  BluetoothCharacteristic? _batteryCharacteristic;
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

    BluetoothCharacteristic? battery;

    for (final service in services) {
      if (service.uuid == Guid(pressensorBatteryServiceUuid)) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid ==
              Guid(pressensorBatteryLevelCharacteristicUuid)) {
            battery = characteristic;
          }
        }
        continue;
      }
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
    _batteryCharacteristic = battery;
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
  Future<int?> readBatteryPercent() async {
    final characteristic = _batteryCharacteristic;
    if (characteristic == null) {
      return null;
    }
    final value = await characteristic.read();
    return parsePressensorBatteryLevel(value);
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
    _batteryCharacteristic = null;
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
    // Prefer write-without-response (36F5 is WRITE_NR on DIY firmware); fall
    // back to write-with-response if the characteristic only supports that.
    final withoutResponse = characteristic.properties.writeWithoutResponse;
    await characteristic.write(
      command,
      withoutResponse: withoutResponse,
    );
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