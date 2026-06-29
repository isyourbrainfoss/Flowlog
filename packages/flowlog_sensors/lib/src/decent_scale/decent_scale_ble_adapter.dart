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

/// BLE adapter for the Decent Scale weight stream.
///
/// Connect flow: subscribe FFF4 → send [DecentScaleCommands.ledOnGrams] →
/// start the Half Decent Scale heartbeat timer.
///
/// **Heartbeat timer:** while connected, [DecentScaleCommands.heartbeat] is
/// sent every [heartbeatInterval] (default 5 s). The timer is created after a
/// successful connect and cancelled on disconnect. Set byte 5 of tare/LED-on
/// commands to `0x01` so the scale enforces heartbeat on Half Decent Scale.
class DecentScaleBleAdapter implements SensorAdapter {
  DecentScaleBleAdapter({
    required DecentScaleTransport transport,
    Duration heartbeatInterval = DecentScaleConstants.heartbeatInterval,
    Duration minCommandSpacing = DecentScaleConstants.minCommandSpacing,
    MonotonicClock? monotonicClock,
  })  : _transport = transport,
        heartbeatInterval = heartbeatInterval,
        _minCommandSpacing = minCommandSpacing,
        _monotonicClock = monotonicClock ?? _defaultMonotonicClock;

  static int _defaultMonotonicClock() => DateTime.now().millisecondsSinceEpoch;

  final DecentScaleTransport _transport;
  final Duration _minCommandSpacing;
  final MonotonicClock _monotonicClock;

  /// Interval between Half Decent Scale heartbeat commands while connected.
  final Duration heartbeatInterval;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();

  StreamSubscription<List<int>>? _notificationSub;
  Timer? _heartbeatTimer;
  int? _streamStartMs;
  int _lastCommandSentMs = 0;

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  /// Commands written during the current session (visible in tests).
  @visibleForTesting
  List<List<int>> get writtenCommands {
    if (_transport is MockDecentScaleTransport) {
      return (_transport as MockDecentScaleTransport).writtenCommands;
    }
    return const [];
  }

  @override
  Future<void> connect() async {
    if (_stateController.isClosed) return;

    _stateController.add(ConnectionState.connecting);
    try {
      await _transport.connect();
      await _transport.subscribeNotifications();
      _notificationSub = _transport.notifications.listen(
        _onNotification,
        onError: _onError,
      );
      await _writeCommand(DecentScaleCommands.ledOnGrams());
      _streamStartMs = _monotonicClock();
      _startHeartbeatTimer();
      _stateController.add(ConnectionState.connected);
    } on Object catch (error, stackTrace) {
      _stateController.add(ConnectionState.error);
      Zone.current.handleUncaughtError(error, stackTrace);
      rethrow;
    }
  }

  /// Sends a tare command (`030F000000010D`).
  Future<void> tare() async {
    await _writeCommand(DecentScaleCommands.tare());
  }

  /// Sends LED on (`030A0101000108`).
  Future<void> ledOn() async {
    await _writeCommand(DecentScaleCommands.ledOnGrams());
  }

  /// Sends LED off (`030A0000000009`).
  Future<void> ledOff() async {
    await _writeCommand(DecentScaleCommands.ledOff());
  }

  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _notificationSub?.cancel();
    _notificationSub = null;
    _streamStartMs = null;
    await _transport.disconnect();
    if (!_stateController.isClosed) {
      _stateController.add(ConnectionState.disconnected);
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      unawaited(_writeCommand(DecentScaleCommands.heartbeat()));
    });
  }

  Future<void> _writeCommand(List<int> command) async {
    final now = _monotonicClock();
    final elapsed = now - _lastCommandSentMs;
    if (_lastCommandSentMs != 0 && elapsed < _minCommandSpacing.inMilliseconds) {
      await Future<void>.delayed(
        Duration(milliseconds: _minCommandSpacing.inMilliseconds - elapsed),
      );
    }
    await _transport.writeCommand(command);
    _lastCommandSentMs = _monotonicClock();
  }

  void _onNotification(List<int> data) {
    final reading = DecentScaleParser.parseWeight(data);
    if (reading == null) return;

    final receiveMs = _monotonicClock();
    final startMs = _streamStartMs ?? receiveMs;
    final elapsedMs = receiveMs - startMs;

    _samplesController.add(
      SensorSample(
        elapsedMs: elapsedMs,
        weightG: reading.grams,
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