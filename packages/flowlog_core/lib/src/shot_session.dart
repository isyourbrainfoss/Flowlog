import 'dart:async';

import 'models/shot_sample.dart';

/// Lifecycle states for an in-progress espresso shot recording.
enum ShotSessionState {
  idle,
  recording,
  paused,
  stopped,
}

/// Records [ShotSample] points from a live sensor stream or manual ingestion.
///
/// Accepts either a [Stream] of [ShotSample] via [start] or individual samples
/// via [startManual] + [ingestSample]. Does not depend on sensor adapters; the
/// app layer converts device readings to [ShotSample] before feeding this class.
class ShotSession {
  ShotSession();

  final _stateController = StreamController<ShotSessionState>.broadcast(
    sync: true,
  );
  final _batchController = StreamController<List<ShotSample>>.broadcast(
    sync: true,
  );

  StreamSubscription<ShotSample>? _subscription;
  ShotSessionState _state = ShotSessionState.idle;
  final List<ShotSample> _samples = [];

  /// Current lifecycle state.
  ShotSessionState get state => _state;

  /// All samples collected so far in this session (immutable view).
  List<ShotSample> get samples => List.unmodifiable(_samples);

  /// Emits whenever [state] changes.
  Stream<ShotSessionState> get stateChanges => _stateController.stream;

  /// Emits batches of newly collected samples while recording.
  ///
  /// Each event is an incremental batch (not the full session history).
  /// A final batch containing any samples not yet emitted is sent on [stop].
  Stream<List<ShotSample>> get sampleBatches => _batchController.stream;

  /// Begins a new session, subscribing to [sampleStream].
  void start(Stream<ShotSample> sampleStream) {
    _beginSession();
    _subscription = sampleStream.listen(
      _onSample,
      onError: _onStreamError,
    );
  }

  /// Begins a new session without a stream; push samples via [ingestSample].
  void startManual() {
    _beginSession();
  }

  /// Records a single sample when started via [startManual].
  void ingestSample(ShotSample sample) {
    _onSample(sample);
  }

  /// Pauses collection; samples from the stream are ignored until [resume].
  void pause() {
    _requireState(ShotSessionState.recording, 'pause');
    _setState(ShotSessionState.paused);
  }

  /// Resumes collection after [pause].
  void resume() {
    _requireState(ShotSessionState.paused, 'resume');
    _setState(ShotSessionState.recording);
  }

  /// Ends the session, cancels any stream subscription, and emits a final batch.
  void stop() {
    if (_state != ShotSessionState.recording &&
        _state != ShotSessionState.paused) {
      throw StateError('Cannot stop while in $_state');
    }

    _subscription?.cancel();
    _subscription = null;
    _emitPendingBatch();
    _setState(ShotSessionState.stopped);
  }

  /// Releases stream controllers. The session must not be used after [dispose].
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _stateController.close();
    await _batchController.close();
  }

  void _beginSession() {
    _requireState(ShotSessionState.idle, 'start');
    _samples.clear();
    _pendingBatch.clear();
    _setState(ShotSessionState.recording);
  }

  void _onSample(ShotSample sample) {
    if (_state != ShotSessionState.recording) {
      return;
    }

    _samples.add(sample);
    _pendingBatch.add(sample);
    _batchController.add(List<ShotSample>.unmodifiable(_pendingBatch));
    _pendingBatch.clear();
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    _subscription?.cancel();
    _subscription = null;
    _emitPendingBatch();
    _setState(ShotSessionState.stopped);
  }

  final List<ShotSample> _pendingBatch = [];

  void _emitPendingBatch() {
    if (_pendingBatch.isEmpty) {
      return;
    }
    _batchController.add(List<ShotSample>.unmodifiable(_pendingBatch));
    _pendingBatch.clear();
  }

  void _setState(ShotSessionState next) {
    if (_state == next) {
      return;
    }
    _state = next;
    _stateController.add(next);
  }

  void _requireState(ShotSessionState expected, String action) {
    if (_state != expected) {
      throw StateError('Cannot $action while in $_state');
    }
  }
}