import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../adapter.dart';
import '../sample.dart';

/// Replays a JSONL sensor stream fixture at a configurable speed.
///
/// Each line in [fixturePath] must be a JSON object with at least
/// `elapsedMs` and optional `pressureBar`, `weightG`, `tempC`, `flowGs`.
///
/// [speed] controls replay timing: `1.0` is real-time (deltas between
/// consecutive `elapsedMs` values), `2.0` is twice as fast, and `0` emits
/// all samples instantly.
class MockReplayAdapter implements SensorAdapter {
  MockReplayAdapter({
    this.fixturePath,
    this.fixtureLoader,
    this.speed = 1.0,
  }) : assert(
          fixturePath != null || fixtureLoader != null,
          'Provide fixturePath or fixtureLoader',
        );

  /// Path to a JSONL fixture file (dev/tests on a filesystem).
  final String? fixturePath;

  /// Optional async loader for bundled fixtures (e.g. Flutter assets).
  final Future<List<SensorSample>> Function()? fixtureLoader;

  /// Replay speed multiplier (`1.0` = real-time, `0` = instant).
  final double speed;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();

  Timer? _replayTimer;
  bool _connected = false;
  List<SensorSample>? _cachedSamples;

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }

    _stateController.add(ConnectionState.connecting);

    try {
      final samples = await _loadSamples();
      _connected = true;
      _stateController.add(ConnectionState.connected);
      _startReplay(samples);
    } catch (_) {
      _stateController.add(ConnectionState.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _replayTimer?.cancel();
    _replayTimer = null;
    _connected = false;
    _stateController.add(ConnectionState.disconnected);
  }

  Future<List<SensorSample>> _loadSamples() async {
    if (_cachedSamples != null) {
      return _cachedSamples!;
    }

    if (fixtureLoader != null) {
      _cachedSamples = await fixtureLoader!();
      return _cachedSamples!;
    }

    _cachedSamples = await parseFixtureFile(File(fixturePath!));
    return _cachedSamples!;
  }

  /// Parses a JSONL fixture from disk.
  static Future<List<SensorSample>> parseFixtureFile(File file) async {
    return parseLines(await file.readAsLines(), source: file.path);
  }

  /// Parses JSONL fixture lines into samples.
  static List<SensorSample> parseLines(
    Iterable<String> lines, {
    String source = 'fixture',
  }) {
    final samples = <SensorSample>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      samples.add(_sampleFromJson(json));
    }

    if (samples.isEmpty) {
      throw StateError('Fixture contains no samples: $source');
    }

    return samples;
  }

  static SensorSample _sampleFromJson(Map<String, dynamic> json) {
    return SensorSample(
      elapsedMs: (json['elapsedMs'] as num).toInt(),
      pressureBar: (json['pressureBar'] as num?)?.toDouble(),
      weightG: (json['weightG'] as num?)?.toDouble(),
      tempC: (json['tempC'] as num?)?.toDouble(),
      flowGs: (json['flowGs'] as num?)?.toDouble(),
    );
  }

  void _startReplay(List<SensorSample> samples) {
    if (speed <= 0) {
      for (final sample in samples) {
        if (!_connected) {
          return;
        }
        _samplesController.add(sample);
      }
      return;
    }

    _emitSample(samples, 0);
  }

  void _emitSample(List<SensorSample> samples, int index) {
    if (!_connected || index >= samples.length) {
      return;
    }

    _samplesController.add(samples[index]);

    final nextIndex = index + 1;
    if (nextIndex >= samples.length) {
      return;
    }

    final deltaMs = samples[nextIndex].elapsedMs - samples[index].elapsedMs;
    final delayMs = (deltaMs / speed).round();

    _replayTimer?.cancel();
    if (delayMs <= 0) {
      _emitSample(samples, nextIndex);
      return;
    }

    _replayTimer = Timer(Duration(milliseconds: delayMs), () {
      _emitSample(samples, nextIndex);
    });
  }
}