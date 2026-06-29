import 'dart:async';

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart';

/// Coordinates [ShotSession] lifecycle with a replay adapter and scale tare.
class LiveShotController extends ChangeNotifier {
  LiveShotController({
    required SensorAdapter sampleAdapter,
    required Future<void> Function() onTare,
    ShotSession? session,
  })  : _sampleAdapter = sampleAdapter,
        _onTare = onTare,
        _session = session ?? ShotSession() {
    _stateSub = _session.stateChanges.listen((_) => _notify());
    _sampleBatchSub = _session.sampleBatches.listen((_) => _notify());
  }

  final SensorAdapter _sampleAdapter;
  final Future<void> Function() _onTare;
  ShotSession _session;
  StreamSubscription<ShotSessionState>? _stateSub;
  StreamSubscription<List<ShotSample>>? _sampleBatchSub;
  DateTime? _sessionStartedAt;
  DateTime? _sessionEndedAt;
  bool _disposed = false;

  ShotSession get session => _session;

  ShotSessionState get sessionState => _session.state;

  int get sampleCount => _session.samples.length;

  List<ShotSample> get samples => _session.samples;

  DateTime? get sessionStartedAt => _sessionStartedAt;

  DateTime? get sessionEndedAt => _sessionEndedAt;

  bool get canSaveShot =>
      sessionState == ShotSessionState.stopped && samples.isNotEmpty;

  bool get canStart =>
      sessionState == ShotSessionState.idle ||
      sessionState == ShotSessionState.stopped;

  bool get canPause => sessionState == ShotSessionState.recording;

  bool get canResume => sessionState == ShotSessionState.paused;

  bool get canStop =>
      sessionState == ShotSessionState.recording ||
      sessionState == ShotSessionState.paused;

  /// Tares the scale, connects [sampleAdapter], and begins [ShotSession].
  Future<void> start() async {
    if (!canStart) {
      return;
    }

    if (sessionState == ShotSessionState.stopped) {
      await _replaceSession();
    }

    await _onTare();
    _sessionStartedAt = DateTime.now().toUtc();
    _sessionEndedAt = null;
    // Subscribe before connect so instant replay samples are not missed.
    _session.start(
      _sampleAdapter.samples.map((sample) => sample.toShotSample()),
    );
    await _sampleAdapter.connect();
    _notify();
  }

  void pause() {
    if (!canPause) {
      return;
    }
    _session.pause();
    _notify();
  }

  void resume() {
    if (!canResume) {
      return;
    }
    _session.resume();
    _notify();
  }

  /// Ends recording and disconnects the sample adapter.
  Future<void> stop() async {
    if (!canStop) {
      return;
    }

    _session.stop();
    _sessionEndedAt = DateTime.now().toUtc();
    await _sampleAdapter.disconnect();
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _sampleBatchSub?.cancel();
    unawaited(_session.dispose());
    unawaited(_sampleAdapter.disconnect());
    super.dispose();
  }

  Future<void> _replaceSession() async {
    _stateSub?.cancel();
    _sampleBatchSub?.cancel();
    await _session.dispose();
    _session = ShotSession();
    _sessionStartedAt = null;
    _sessionEndedAt = null;
    _stateSub = _session.stateChanges.listen((_) => _notify());
    _sampleBatchSub = _session.sampleBatches.listen((_) => _notify());
  }
}

/// Start / pause / resume / stop controls for a live shot recording.
class LiveControls extends StatelessWidget {
  const LiveControls({
    required this.controller,
    super.key,
  });

  final LiveShotController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            FilledButton(
              key: const Key('live_start'),
              onPressed: controller.canStart ? () => controller.start() : null,
              child: const Text('Start'),
            ),
            FilledButton.tonal(
              key: const Key('live_pause'),
              onPressed: controller.canPause ? controller.pause : null,
              child: const Text('Pause'),
            ),
            FilledButton.tonal(
              key: const Key('live_resume'),
              onPressed: controller.canResume ? controller.resume : null,
              child: const Text('Resume'),
            ),
            FilledButton(
              key: const Key('live_stop'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: controller.canStop ? () => controller.stop() : null,
              child: const Text('Stop'),
            ),
          ],
        );
      },
    );
  }
}