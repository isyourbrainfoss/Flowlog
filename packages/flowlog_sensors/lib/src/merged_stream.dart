import 'dart:async';

import 'package:meta/meta.dart';

import 'adapter.dart';
import 'sample.dart';

/// Supplies elapsed milliseconds for merged samples (tests inject a fake clock).
@visibleForTesting
typedef MergeMonotonicClock = int Function();

/// Merges pressure and weight [SensorAdapter] streams onto one host timeline.
///
/// Each emitted [SensorSample] is stamped with elapsed milliseconds from a
/// monotonic clock started when [start] is called. The latest reading from each
/// connected sensor is carried forward so live charts see a unified stream.
///
/// Works when only a pressensor or only a scale is provided.
class MergedSampleStream {
  MergedSampleStream({
    SensorAdapter? pressureAdapter,
    SensorAdapter? weightAdapter,
    MergeMonotonicClock? monotonicClock,
  })  : _pressure = pressureAdapter,
        _weight = weightAdapter,
        _monotonicClock = monotonicClock;

  final SensorAdapter? _pressure;
  final SensorAdapter? _weight;
  final MergeMonotonicClock? _monotonicClock;

  final _samplesController = StreamController<SensorSample>.broadcast();
  final _stopwatch = Stopwatch();

  StreamSubscription<SensorSample>? _pressureSub;
  StreamSubscription<SensorSample>? _weightSub;

  bool _running = false;
  int? _clockStartMs;

  double? _lastPressureBar;
  double? _lastWeightG;
  double? _lastTempC;

  /// Unified sensor readings while [start] has been called and [stop] has not.
  Stream<SensorSample> get samples => _samplesController.stream;

  /// Whether [start] completed and [stop] has not been called.
  bool get isRunning => _running;

  /// Connects available adapters and begins emitting merged samples.
  Future<void> start() async {
    if (_running) {
      return;
    }
    if (_pressure == null && _weight == null) {
      throw StateError(
        'MergedSampleStream requires at least one sensor adapter.',
      );
    }

    _resetCarryForward();
    _startClock();

    final connects = <Future<void>>[];
    if (_pressure != null) {
      connects.add(_pressure!.connect());
    }
    if (_weight != null) {
      connects.add(_weight!.connect());
    }
    await Future.wait(connects);

    _running = true;

    if (_pressure != null) {
      _pressureSub = _pressure!.samples.listen(_onPressureSample);
    }
    if (_weight != null) {
      _weightSub = _weight!.samples.listen(_onWeightSample);
    }
  }

  /// Cancels subscriptions, disconnects adapters, and stops the merge clock.
  Future<void> stop() async {
    if (!_running) {
      return;
    }

    _running = false;

    await _pressureSub?.cancel();
    await _weightSub?.cancel();
    _pressureSub = null;
    _weightSub = null;

    final disconnects = <Future<void>>[];
    if (_pressure != null) {
      disconnects.add(_pressure!.disconnect());
    }
    if (_weight != null) {
      disconnects.add(_weight!.disconnect());
    }
    await Future.wait(disconnects);

    _stopClock();
  }

  /// Stops merging and closes [samples].
  Future<void> dispose() async {
    await stop();
    await _samplesController.close();
  }

  void _onPressureSample(SensorSample sample) {
    _lastPressureBar = sample.pressureBar;
    if (sample.tempC != null) {
      _lastTempC = sample.tempC;
    }
    _emitMerged();
  }

  void _onWeightSample(SensorSample sample) {
    _lastWeightG = sample.weightG;
    _emitMerged();
  }

  void _emitMerged() {
    if (!_running || _samplesController.isClosed) {
      return;
    }

    _samplesController.add(
      SensorSample(
        elapsedMs: _elapsedMs(),
        pressureBar: _lastPressureBar,
        weightG: _lastWeightG,
        tempC: _lastTempC,
      ),
    );
  }

  void _resetCarryForward() {
    _lastPressureBar = null;
    _lastWeightG = null;
    _lastTempC = null;
  }

  void _startClock() {
    if (_monotonicClock != null) {
      _clockStartMs = _monotonicClock!();
      return;
    }

    _stopwatch
      ..reset()
      ..start();
  }

  void _stopClock() {
    _stopwatch.stop();
    _clockStartMs = null;
  }

  int _elapsedMs() {
    if (_monotonicClock != null) {
      return _monotonicClock!() - (_clockStartMs ?? 0);
    }
    return _stopwatch.elapsedMilliseconds;
  }
}