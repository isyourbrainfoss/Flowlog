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
  }) : _transport = transport;

  final PressensorBleTransport _transport;

  /// Optional device ID from [PressensorBleTransport.scanForDevices].
  final String? deviceId;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();
  final _stopwatch = Stopwatch();

  StreamSubscription<List<int>>? _pressureSub;

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
      _pressureSub = _transport.subscribePressure().listen(
        _onPressureNotify,
        onError: (Object error, StackTrace _) {
          _stateController.add(ConnectionState.error);
        },
      );
      _stateController.add(ConnectionState.connected);
    } catch (_) {
      _stateController.add(ConnectionState.error);
      rethrow;
    }
  }

  void _onPressureNotify(List<int> data) {
    final reading = parsePressureNotify(data);
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
    await _transport.disconnect();
    _stopwatch.stop();
    _stateController.add(ConnectionState.disconnected);
  }
}