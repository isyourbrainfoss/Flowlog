import 'dart:async';

import '../adapter.dart';
import '../sample.dart';
import 'pressensor_ble_transport.dart';
import 'pressensor_parser.dart';

/// [SensorAdapter] for Pressensor PRS pressure gauges over BLE.
class PressensorBleAdapter implements SensorAdapter {
  PressensorBleAdapter({
    required PressensorBleTransport transport,
    this.deviceId,
    int Function()? monotonicClock,
  })  : _transport = transport,
        _monotonicClock = monotonicClock ?? _defaultMonotonicClock;

  static int _defaultMonotonicClock() => DateTime.now().millisecondsSinceEpoch;

  final PressensorBleTransport _transport;
  final int Function() _monotonicClock;

  /// Optional device ID from [PressensorBleTransport.scanForDevices].
  final String? deviceId;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();
  final _stopwatch = Stopwatch();

  StreamSubscription<List<int>>? _pressureSub;
  int? _batteryPercent;
  int? _streamStartMs;
  /// Host receive time of the last parsed pressure packet (ms since epoch).
  int? _lastSampleReceiveMs;

  /// Last battery reading from [readBatteryPercent], if available.
  int? get batteryPercent => _batteryPercent;

  /// Monotonic host ms of the last pressure sample, if any this session.
  int? get lastSampleReceiveMs => _lastSampleReceiveMs;

  /// True when connected but no pressure packet for [silentFor].
  ///
  /// A brand-new link ([lastSampleReceiveMs] null) is not silent until
  /// [silentFor] has elapsed since connect — otherwise reconnect loops
  /// immediately after `connect()` clears the last-receive stamp.
  bool isPressureStreamSilent({
    Duration silentFor = const Duration(seconds: 3),
  }) {
    final now = _monotonicClock();
    final last = _lastSampleReceiveMs;
    if (last != null) {
      return now - last >= silentFor.inMilliseconds;
    }
    final start = _streamStartMs;
    if (start == null) {
      return true;
    }
    return now - start >= silentFor.inMilliseconds;
  }

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  /// Scans for PRS* devices via the transport.
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _transport.scanForDevices(timeout: timeout);
  }

  /// Tares pressure: writes [pressensorZeroPressureCommand] to the device.
  Future<void> zeroPressure() => _transport.writeZeroPressure();

  @override
  Future<void> connect() async {
    _stateController.add(ConnectionState.connecting);
    try {
      await _transport.connect(deviceId: deviceId);
      _stopwatch
        ..reset()
        ..start();
      _streamStartMs = _monotonicClock();
      _lastSampleReceiveMs = null;
      _pressureSub = _transport.subscribePressure().listen(
        _onPressureNotify,
        onError: (Object error, StackTrace _) {
          _stateController.add(ConnectionState.error);
        },
      );
      await refreshBatteryPercent();
      _stateController.add(ConnectionState.connected);
    } catch (_) {
      _stateController.add(ConnectionState.error);
      rethrow;
    }
  }

  /// Re-reads battery level from the device (BLE read, not streamed).
  Future<void> refreshBatteryPercent() async {
    try {
      _batteryPercent = await _transport.readBatteryPercent();
    } on Object {
      _batteryPercent = null;
    }
  }

  void _onPressureNotify(List<int> data) {
    final reading = parsePressureNotify(data);
    _lastSampleReceiveMs = _monotonicClock();
    _samplesController.add(
      SensorSample(
        elapsedMs: _stopwatch.elapsedMilliseconds,
        pressureBar: reading.pressureBar,
        tempC: reading.tempC,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    await _pressureSub?.cancel();
    _pressureSub = null;
    _streamStartMs = null;
    _lastSampleReceiveMs = null;
    await _transport.disconnect();
    _stopwatch.stop();
    _stateController.add(ConnectionState.disconnected);
  }
}