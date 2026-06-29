import 'dart:async';

import 'package:meta/meta.dart';

import '../adapter.dart' show ConnectionState, SensorAdapter;
import '../sample.dart';
import 'commands.dart';
import 'constants.dart';
import 'parser.dart';
import 'transport.dart';

/// Monotonic clock used to stamp samples on host receive time.
@visibleForTesting
typedef MonotonicClock = int Function();

/// WiFi [SensorAdapter] for openscale 3.x Half Decent Scale.
///
/// Connects to `ws://{host}/snapshot`, negotiates the default stream rate, and
/// emits weight samples stamped on **host receive time** (not device `ms`).
class WifiScaleAdapter implements SensorAdapter {
  WifiScaleAdapter({
    required WifiScaleTransport transport,
    this.host = WifiScaleConstants.defaultHost,
    this.rateCommand = WifiScaleConstants.defaultRateCommand,
    MonotonicClock? monotonicClock,
  })  : _transport = transport,
        _monotonicClock = monotonicClock ?? _defaultMonotonicClock;

  static int _defaultMonotonicClock() => DateTime.now().millisecondsSinceEpoch;

  final WifiScaleTransport _transport;
  final MonotonicClock _monotonicClock;

  /// LAN hostname or IP for the scale (default `hds.local`).
  final String host;

  /// Rate negotiation command sent after connect.
  final String rateCommand;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();

  StreamSubscription<String>? _messageSub;
  int? _streamStartMs;

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  /// Commands written during the current session (visible in tests).
  @visibleForTesting
  List<String> get sentCommands {
    if (_transport is MockWifiScaleTransport) {
      return (_transport as MockWifiScaleTransport).sentCommands;
    }
    return const [];
  }

  @override
  Future<void> connect() async {
    if (_stateController.isClosed) {
      return;
    }

    _stateController.add(ConnectionState.connecting);
    try {
      await _transport.connect(host: host);
      _messageSub = _transport.messages.listen(
        _onMessage,
        onError: _onError,
      );
      await _transport.sendCommand(rateCommand);
      _streamStartMs = _monotonicClock();
      _stateController.add(ConnectionState.connected);
    } on Object catch (error, stackTrace) {
      _stateController.add(ConnectionState.error);
      Zone.current.handleUncaughtError(error, stackTrace);
      rethrow;
    }
  }

  /// Sends the legacy `tare` text command.
  Future<void> tare() async {
    await _transport.sendCommand(WifiScaleCommands.tareText);
  }

  @override
  Future<void> disconnect() async {
    await _messageSub?.cancel();
    _messageSub = null;
    _streamStartMs = null;
    await _transport.disconnect();
    if (!_stateController.isClosed) {
      _stateController.add(ConnectionState.disconnected);
    }
  }

  void _onMessage(String message) {
    final frame = parseWifiScaleWeightFrame(message);
    if (frame == null) {
      return;
    }

    final receiveMs = _monotonicClock();
    final startMs = _streamStartMs ?? receiveMs;
    final elapsedMs = receiveMs - startMs;

    _samplesController.add(
      SensorSample(
        elapsedMs: elapsedMs,
        weightG: frame.grams,
      ),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!_stateController.isClosed) {
      _stateController.add(ConnectionState.error);
    }
    Zone.current.handleUncaughtError(error, stackTrace);
  }
}