import 'dart:async';

import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:test/test.dart';

/// Minimal in-memory adapter for exercising the [SensorAdapter] contract.
class _FakeSensorAdapter implements SensorAdapter {
  _FakeSensorAdapter({required this.samplesToEmit});

  final List<SensorSample> samplesToEmit;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _samplesController = StreamController<SensorSample>.broadcast();

  @override
  Stream<ConnectionState> get state => _stateController.stream;

  @override
  Stream<SensorSample> get samples => _samplesController.stream;

  @override
  Future<void> connect() async {
    _stateController.add(ConnectionState.connecting);
    _stateController.add(ConnectionState.connected);
    for (final sample in samplesToEmit) {
      _samplesController.add(sample);
    }
  }

  @override
  Future<void> disconnect() async {
    _stateController.add(ConnectionState.disconnected);
    await _samplesController.close();
    await _stateController.close();
  }
}

void main() {
  group('ConnectionState', () {
    test('includes lifecycle values', () {
      expect(
        ConnectionState.values,
        containsAll([
          ConnectionState.disconnected,
          ConnectionState.connecting,
          ConnectionState.connected,
          ConnectionState.error,
        ]),
      );
    });
  });

  group('SensorAdapter', () {
    test('connect emits state transitions and samples', () async {
      final adapter = _FakeSensorAdapter(
        samplesToEmit: const [
          SensorSample(elapsedMs: 0, pressureBar: 0.0),
          SensorSample(elapsedMs: 100, pressureBar: 6.5),
        ],
      );

      final states = <ConnectionState>[];
      final received = <SensorSample>[];

      final stateSub = adapter.state.listen(states.add);
      final sampleSub = adapter.samples.listen(received.add);

      await adapter.connect();
      await Future<void>.delayed(Duration.zero);

      expect(
        states,
        [
          ConnectionState.connecting,
          ConnectionState.connected,
        ],
      );
      expect(received, hasLength(2));
      expect(received.first.elapsedMs, 0);
      expect(received.last.pressureBar, 6.5);

      await adapter.disconnect();
      await stateSub.cancel();
      await sampleSub.cancel();
    });

    test('disconnect ends in disconnected state', () async {
      final adapter = _FakeSensorAdapter(samplesToEmit: const []);

      final states = <ConnectionState>[];
      final sub = adapter.state.listen(states.add);

      await adapter.connect();
      await adapter.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(states.last, ConnectionState.disconnected);

      await sub.cancel();
    });
  });
}