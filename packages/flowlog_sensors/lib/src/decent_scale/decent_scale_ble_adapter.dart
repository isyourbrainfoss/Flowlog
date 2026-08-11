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
  Timer? _weightWatchdog;
  int? _streamStartMs;
  int _lastCommandSentMs = 0;
  /// Host receive time of the last parsed weight packet (ms since epoch).
  int? _lastWeightReceiveMs;
  int _silentRearmAttempts = 0;
  /// Serializes outbound writes so heartbeat + pressure forward cannot race.
  Future<void> _writeQueue = Future<void>.value();
  bool _writeInFlight = false;

  /// Monotonic host ms of the last weight sample, if any this session.
  int? get lastWeightReceiveMs => _lastWeightReceiveMs;

  /// True when connected but no weight packet for [silentFor].
  bool isWeightStreamSilent({
    Duration silentFor = const Duration(seconds: 4),
  }) {
    final last = _lastWeightReceiveMs;
    if (last == null) {
      return true;
    }
    return _monotonicClock() - last >= silentFor.inMilliseconds;
  }

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
      await _notificationSub?.cancel();
      await _transport.connect();
      await _transport.subscribeNotifications();
      _notificationSub = _transport.notifications.listen(
        _onNotification,
        onError: _onError,
      );
      await _writeCommand(DecentScaleCommands.ledOnGrams());
      _streamStartMs = _monotonicClock();
      _lastWeightReceiveMs = null;
      _silentRearmAttempts = 0;
      _startHeartbeatTimer();
      _startWeightWatchdog();
      _stateController.add(ConnectionState.connected);
    } on Object catch (error, stackTrace) {
      _stateController.add(ConnectionState.error);
      Zone.current.handleUncaughtError(error, stackTrace);
      rethrow;
    }
  }

  /// Re-enables weight notifications and LED-on without a full disconnect.
  Future<void> rearmStream() async {
    try {
      await _transport.rearmNotifications();
      await _notificationSub?.cancel();
      _notificationSub = _transport.notifications.listen(
        _onNotification,
        onError: _onError,
      );
      await _writeCommand(DecentScaleCommands.ledOnGrams());
    } on Object {
      // Caller may escalate to full reconnect.
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

  /// Mirrors live pressensor pressure onto the Flowlog DIY scale OLED.
  ///
  /// Use while the phone owns the PRS BLE link so the scale can still show bar.
  /// Drops the write if another command is already in flight so weight notify
  /// traffic is not starved by a pressure-forward backlog.
  Future<void> sendPhonePressure(double pressureBar) async {
    await _writeCommand(
      DecentScaleCommands.phonePressure(pressureBar),
      dropIfBusy: true,
    );
  }

  /// Notifies the scale that an app-driven brew started.
  Future<void> sendPhoneBrewStart() async {
    await _writeCommand(DecentScaleCommands.phoneBrewStart());
  }

  /// Notifies the scale that an app-driven brew ended.
  Future<void> sendPhoneBrewEnd() async {
    await _writeCommand(DecentScaleCommands.phoneBrewEnd());
  }

  /// Pushes OLED target/warn grams and pressure-bar window to the DIY scale.
  Future<void> sendScaleDisplayConfig({
    required int targetYieldG,
    required int warnAtG,
    required int pressureMinBar,
    required int pressureMaxBar,
  }) async {
    await _writeCommand(
      DecentScaleCommands.scaleDisplayConfig(
        targetYieldG: targetYieldG,
        warnAtG: warnAtG,
        pressureMinBar: pressureMinBar,
        pressureMaxBar: pressureMaxBar,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _weightWatchdog?.cancel();
    _weightWatchdog = null;
    await _notificationSub?.cancel();
    _notificationSub = null;
    _streamStartMs = null;
    _lastWeightReceiveMs = null;
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

  void _startWeightWatchdog() {
    _weightWatchdog?.cancel();
    // Soft recover silent FFF4 streams (common after phone sleep / brew end).
    _weightWatchdog = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_stateController.isClosed) {
        return;
      }
      if (!isWeightStreamSilent(silentFor: const Duration(seconds: 5))) {
        _silentRearmAttempts = 0;
        return;
      }
      if (_silentRearmAttempts >= 2) {
        // Escalate: mark error so SensorHub can reconnect the scale.
        if (!_stateController.isClosed) {
          _stateController.add(ConnectionState.error);
        }
        return;
      }
      _silentRearmAttempts += 1;
      unawaited(() async {
        try {
          await rearmStream();
        } on Object {
          // Next watchdog tick may escalate to error/reconnect.
        }
      }());
    });
  }

  Future<void> _writeCommand(
    List<int> command, {
    bool dropIfBusy = false,
  }) {
    if (dropIfBusy && _writeInFlight) {
      return Future<void>.value();
    }

    final done = Completer<void>();
    _writeQueue = _writeQueue.then((_) async {
      if (dropIfBusy && _writeInFlight) {
        if (!done.isCompleted) {
          done.complete();
        }
        return;
      }
      _writeInFlight = true;
      try {
        final now = _monotonicClock();
        final elapsed = now - _lastCommandSentMs;
        if (_lastCommandSentMs != 0 &&
            elapsed < _minCommandSpacing.inMilliseconds) {
          await Future<void>.delayed(
            Duration(
              milliseconds: _minCommandSpacing.inMilliseconds - elapsed,
            ),
          );
        }
        await _transport.writeCommand(command);
        _lastCommandSentMs = _monotonicClock();
        if (!done.isCompleted) {
          done.complete();
        }
      } on Object catch (error, stackTrace) {
        if (!done.isCompleted) {
          done.completeError(error, stackTrace);
        }
      } finally {
        _writeInFlight = false;
      }
    }).catchError((Object error, StackTrace stackTrace) {
      if (!done.isCompleted) {
        done.completeError(error, stackTrace);
      }
    });
    return done.future;
  }

  void _onNotification(List<int> data) {
    final reading = DecentScaleParser.parseWeight(data);
    if (reading == null) return;

    final receiveMs = _monotonicClock();
    _lastWeightReceiveMs = receiveMs;
    _silentRearmAttempts = 0;
    final startMs = _streamStartMs ?? receiveMs;
    final elapsedMs = receiveMs - startMs;

    _samplesController.add(
      SensorSample(
        elapsedMs: elapsedMs,
        weightG: reading.grams,
      ),
    );
  }

  /// Called by the transport when the OS drops the GATT link.
  void notifyLinkLost() {
    _weightWatchdog?.cancel();
    _weightWatchdog = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (!_stateController.isClosed) {
      _stateController.add(ConnectionState.disconnected);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!_stateController.isClosed) {
      _stateController.add(ConnectionState.error);
    }
    Zone.current.handleUncaughtError(error, stackTrace);
  }
}