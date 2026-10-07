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
  cancelled,
}

/// Extra time to collect additional matches after the first device is seen.
@visibleForTesting
const Duration kBleScanExtraMatchWindow = Duration(milliseconds: 400);

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

  factory BleScanAssignResult.cancelled() {
    return const BleScanAssignResult._(outcome: BleScanAssignOutcome.cancelled);
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
    Future<void>? abort,
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
    Future<void>? abort,
  }) async {
    return const [];
  }

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    throw UnsupportedError((await ensureReady()) ?? 'Bluetooth unavailable');
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

    var state = await FlutterBluePlus.adapterState
        .where((value) => value != BluetoothAdapterState.unknown)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            return BluetoothAdapterState.unknown;
          },
        );

    if (state == BluetoothAdapterState.turningOn) {
      state = await FlutterBluePlus.adapterState
          .where((value) => value == BluetoothAdapterState.on)
          .first
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              return BluetoothAdapterState.turningOn;
            },
          );
    }

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
      BluetoothAdapterState.unknown => 'Bluetooth state is unknown. Try again.',
    };
  }

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
  }) async {
    final readyError = await ensureReady();
    if (readyError != null) {
      return const [];
    }

    var aborted = false;
    final found = <String, BleDiscoveredDevice>{};
    final finished = Completer<void>();
    Timer? extraWindowTimer;
    Timer? safetyTimer;
    StreamSubscription<bool>? scanningSub;

    void complete() {
      if (!finished.isCompleted) {
        finished.complete();
      }
    }

    if (abort != null) {
      unawaited(
        abort.whenComplete(() {
          aborted = true;
          extraWindowTimer?.cancel();
          unawaited(() async {
            try {
              await FlutterBluePlus.stopScan();
            } catch (_) {}
            complete();
          }());
        }),
      );
      await Future<void>.delayed(Duration.zero);
      if (aborted) {
        return const [];
      }
    }

    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final name = _bleScanResultName(result);
        if (!matchesSensorKind(name, kind)) {
          continue;
        }
        final id = result.device.remoteId.str;
        final isNew = !found.containsKey(id);
        found[id] = BleDiscoveredDevice(
          remoteId: id,
          name: name,
          kind: kind,
          rssi: result.rssi,
        );
        // First match: keep a short window for additional devices, then stop.
        if (isNew && found.length == 1) {
          extraWindowTimer ??= Timer(kBleScanExtraMatchWindow, complete);
        }
      }
    }, onError: (_) {});

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

      if (aborted) {
        return const [];
      }

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withNames: kind == SensorKind.scale
            ? [DecentScaleConstants.deviceName]
            : const [],
      );

      if (aborted) {
        return const [];
      }

      // Stop on first-match extra window, user cancel, or the timeout-driven
      // scan end. Guard with a safety timer so we never hang forever.
      if (FlutterBluePlus.isScanningNow) {
        scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
          if (!scanning) {
            complete();
          }
        });
      } else {
        complete();
      }
      safetyTimer = Timer(timeout + const Duration(seconds: 3), complete);
      await finished.future;
    } catch (_) {
      // Any timeout or platform hiccup during wait: stop and return whatever we collected.
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    } finally {
      extraWindowTimer?.cancel();
      safetyTimer?.cancel();
      await scanningSub?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await subscription.cancel();
    }

    if (aborted) {
      return const [];
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
      SensorKind.scale => () {
        final transport = FlutterBlueDecentScaleTransport(
          remoteId: bleRemoteId,
        );
        final adapter = DecentScaleBleAdapter(transport: transport);
        transport.onLinkLost = adapter.notifyLinkLost;
        return adapter;
      }(),
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
    final devices = await backend.scan(SensorKind.pressensor, timeout: timeout);
    return devices.map((device) => device.remoteId).toList(growable: false);
  }

  @override
  Future<void> connect({String? deviceId}) async {
    final targetId = deviceId ?? this.deviceId;
    if (targetId == null || targetId.isEmpty) {
      throw StateError('Pressensor device id is required to connect.');
    }

    await _pressureSubscription?.cancel();
    _pressureSubscription = null;

    final device = BluetoothDevice.fromId(targetId);
    _device = device;

    // Drop any half-open OS link before connecting. Without this, in-session
    // reconnect often fails while a cold app start (clean BLE stack) works.
    await _forceClearLink(device);

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt > 0) {
          await _forceClearLink(device);
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        await device.connect(
          license: License.nonprofit,
          autoConnect: false,
          timeout: const Duration(seconds: 20),
        );
        await _discoverCharacteristics();
        // Arm CCCD before the adapter reports connected so the first
        // pressure packets are not lost after in-session reconnect.
        await _enablePressureNotify();
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Pressensor connect failed.');
  }

  /// Best-effort disconnect so the next [BluetoothDevice.connect] is clean.
  static Future<void> _forceClearLink(BluetoothDevice device) async {
    try {
      await device.disconnect(timeout: 5);
    } on Object {
      // Already disconnected or platform race — safe to ignore.
    }
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

  Future<void> _enablePressureNotify() async {
    final characteristic = _pressureCharacteristic;
    if (characteristic == null) {
      return;
    }
    try {
      await characteristic.setNotifyValue(true);
    } on Object {
      // Retry once — Android sometimes drops the first setNotifyValue after a
      // fresh reconnect.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await characteristic.setNotifyValue(true);
    }
  }

  @override
  Stream<List<int>> subscribePressure() {
    final characteristic = _pressureCharacteristic;
    final device = _device;
    if (characteristic == null || device == null) {
      throw StateError('Pressensor is not connected.');
    }

    if (_pressureController.isClosed) {
      throw StateError('Pressensor transport was disconnected.');
    }

    unawaited(_pressureSubscription?.cancel());
    _pressureSubscription = characteristic.onValueReceived.listen(
      (value) {
        if (!_pressureController.isClosed) {
          _pressureController.add(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_pressureController.isClosed) {
          _pressureController.addError(error, stackTrace);
        }
      },
    );
    device.cancelWhenDisconnected(_pressureSubscription!);
    // Notify should already be armed in connect(); re-assert best-effort.
    unawaited(_enablePressureNotify());
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
    if (!_pressureController.isClosed) {
      await _pressureController.close();
    }
    final device = _device;
    _device = null;
    _pressureCharacteristic = null;
    _zeroCharacteristic = null;
    _batteryCharacteristic = null;
    if (device != null) {
      try {
        await device.disconnect(timeout: 5);
      } on Object {
        // Ignore disconnect races during force-reconnect.
      }
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
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamController<List<int>> _notifications =
      StreamController<List<int>>.broadcast();
  void Function()? _onLinkLost;

  @override
  Stream<List<int>> get notifications {
    if (_notifications.isClosed) {
      _notifications = StreamController<List<int>>.broadcast();
    }
    return _notifications.stream;
  }

  /// Called when the OS reports the GATT link dropped.
  set onLinkLost(void Function()? callback) => _onLinkLost = callback;

  @override
  Future<void> connect() async {
    final device = BluetoothDevice.fromId(remoteId);
    _device = device;

    // Only force-clear when the stack thinks we are still linked — always
    // disconnecting made cold reconnect flaky and mid-session re-pair noisy.
    if (device.isConnected) {
      try {
        await device.disconnect(timeout: 5);
      } on Object {
        // ignore
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } else {
      try {
        await device.disconnect(timeout: 2);
      } on Object {
        // ignore
      }
    }

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt > 0) {
          try {
            await device.disconnect(timeout: 5);
          } on Object {
            // ignore
          }
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        await device.connect(
          license: License.nonprofit,
          autoConnect: false,
          timeout: const Duration(seconds: 20),
        );
        await _discoverCharacteristics();
        await _watchConnectionState(device);
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Decent Scale connect failed.');
  }

  Future<void> _watchConnectionState(BluetoothDevice device) async {
    await _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _onLinkLost?.call();
      }
    });
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
        } else if (characteristic.uuid ==
            Guid(DecentScaleConstants.writeUuid)) {
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

    if (_notifications.isClosed) {
      _notifications = StreamController<List<int>>.broadcast();
    }

    await _notifySubscription?.cancel();
    _notifySubscription = characteristic.onValueReceived.listen(
      (value) {
        if (!_notifications.isClosed) {
          _notifications.add(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_notifications.isClosed) {
          _notifications.addError(error, stackTrace);
        }
      },
    );
    device.cancelWhenDisconnected(_notifySubscription!);
    try {
      await characteristic.setNotifyValue(true);
    } on Object {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await characteristic.setNotifyValue(true);
    }
  }

  /// Re-enables CCCD notify without a full reconnect (recover silent stream).
  @override
  Future<void> rearmNotifications() async {
    final characteristic = _notifyCharacteristic;
    if (characteristic == null) {
      throw StateError('Decent Scale is not connected.');
    }
    try {
      await characteristic.setNotifyValue(false);
    } on Object {
      // ignore
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await subscribeNotifications();
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
    await characteristic.write(command, withoutResponse: withoutResponse);
  }

  @override
  Future<void> disconnect() async {
    await _connectionSub?.cancel();
    _connectionSub = null;
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    final device = _device;
    _device = null;
    _notifyCharacteristic = null;
    _writeCharacteristic = null;
    // Keep the stream open for a future connect on a new adapter instance;
    // only close if already closed to avoid double-close errors.
    if (!_notifications.isClosed) {
      // Do not close — adapters may still hold the stream briefly. Recreate
      // on next subscribe. Closing permanently broke re-pair mid-session.
    }
    if (device != null) {
      try {
        await device.disconnect(timeout: 5);
      } on Object {
        // ignore
      }
    }
  }
}
