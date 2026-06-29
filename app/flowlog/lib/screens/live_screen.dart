import 'dart:async';
import 'dart:io';

import 'package:flowlog/screens/live/annotations.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart';

/// Live shot tab: recording controls, live chart, metrics, and god-shot save.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    this.controller,
    this.shotRepository,
    this.profileRepository,
    this.repeatShotController,
    this.onShotSaved,
    this.shotEndFeedback = const ShotEndFeedback(),
    this.shotIdGenerator = generateShotId,
  });

  /// Optional override for tests or dependency injection.
  final LiveShotController? controller;

  /// Optional repository override; defaults to a temp-file database.
  final ShotRepository? shotRepository;

  /// Optional profile repository override; defaults to shared temp database.
  final ProfileRepository? profileRepository;

  /// Optional repeat-shot controller override for tests.
  final RepeatShotController? repeatShotController;

  /// Called after a shot is persisted (useful in tests).
  final void Function(Shot shot)? onShotSaved;

  /// Shot-end haptic/sound hook (injectable in tests).
  final ShotEndFeedback shotEndFeedback;

  /// Generates ids for newly saved shots.
  final ShotIdGenerator shotIdGenerator;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final LiveShotController _controller;
  late final bool _ownsController;
  late final ValueNotifier<List<ShotSample>> _samplesNotifier;
  late final ShotAnnotationController _annotationController;
  late final ValueNotifier<List<ShotAnnotation>> _annotationsNotifier;
  MockReplayAdapter? _replayAdapter;
  DecentScaleBleAdapter? _scaleAdapter;
  ShotRepository? _shotRepository;
  ProfileRepository? _profileRepository;
  FlowlogDatabase? _database;
  bool _ownsRepository = false;
  bool _savingShot = false;
  ShotSessionState _lastSessionState = ShotSessionState.idle;
  FlowlogShortcutRegistry? _shortcutRegistry;
  RepeatShotController? _repeatShotController;
  final ConfettiController _confettiController = ConfettiController();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final scaleTransport = MockDecentScaleTransport();
      _scaleAdapter = DecentScaleBleAdapter(transport: scaleTransport);
      _replayAdapter = MockReplayAdapter(
        fixturePath: _defaultFixturePath(),
        speed: 0,
      );
      _controller = LiveShotController(
        sampleAdapter: _replayAdapter!,
        onTare: () => _scaleAdapter!.tare(),
      );
      _ownsController = true;
    }

    _samplesNotifier = ValueNotifier<List<ShotSample>>(
      List<ShotSample>.from(_controller.samples),
    );
    _annotationController = ShotAnnotationController();
    _annotationsNotifier = ValueNotifier<List<ShotAnnotation>>(
      List<ShotAnnotation>.from(_annotationController.annotations),
    );
    _controller.addListener(_syncSamples);
    _annotationController.addListener(_syncAnnotations);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FlowlogShortcutsScope.maybeOf(context);
    if (scope != null) {
      _shortcutRegistry = scope.registry;
      _shortcutRegistry!.setToggleLiveShot(_onToggleShotShortcut);
    }
    _repeatShotController =
        widget.repeatShotController ?? RepeatShotScope.maybeOf(context);
  }

  @override
  void dispose() {
    _shortcutRegistry?.setToggleLiveShot(null);
    _confettiController.dispose();
    _controller.removeListener(_syncSamples);
    _annotationController.removeListener(_syncAnnotations);
    _annotationController.dispose();
    _annotationsNotifier.dispose();
    _samplesNotifier.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsRepository) {
      unawaited(_database?.close());
    }
    super.dispose();
  }

  void _syncSamples() {
    final state = _controller.sessionState;
    if (state == ShotSessionState.recording &&
        _lastSessionState != ShotSessionState.recording) {
      _annotationController.clear();
    }
    _lastSessionState = state;
    _samplesNotifier.value = List<ShotSample>.from(_controller.samples);
  }

  void _syncAnnotations() {
    _annotationsNotifier.value =
        List<ShotAnnotation>.from(_annotationController.annotations);
  }

  int? _currentElapsedMs() {
    final samples = _controller.samples;
    if (samples.isEmpty) {
      return null;
    }
    return samples.last.elapsedMs;
  }

  void _onMarkChannel() {
    final elapsedMs = _currentElapsedMs();
    if (elapsedMs == null) {
      return;
    }
    _annotationController.markChannel(elapsedMs: elapsedMs);
  }

  Future<void> _onAnnotateAtElapsedMs(int elapsedMs) async {
    if (_controller.sessionState == ShotSessionState.idle) {
      return;
    }

    await promptShotNoteAnnotation(
      context: context,
      controller: _annotationController,
      elapsedMs: elapsedMs,
    );
  }

  Future<void> _onToggleShotShortcut() async {
    if (_controller.canStart) {
      await _controller.start();
    } else if (_controller.canStop) {
      await _controller.stop();
    }
  }

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _ownsRepository = true;
    return _database!;
  }

  Future<ShotRepository> _ensureShotRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    final database = await _ensureDatabase();
    _shotRepository = ShotRepository(database);
    return _shotRepository!;
  }

  Future<ProfileRepository> _ensureProfileRepository() async {
    if (widget.profileRepository != null) {
      return widget.profileRepository!;
    }
    if (_profileRepository != null) {
      return _profileRepository!;
    }

    final database = await _ensureDatabase();
    _profileRepository = ProfileRepository(database);
    return _profileRepository!;
  }

  Future<void> _onStarShotPressed() async {
    if (!_controller.canSaveShot || _savingShot) {
      return;
    }

    final startedAt = _controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    setState(() => _savingShot = true);
    try {
      final repository = await _ensureShotRepository();
      if (!mounted) {
        return;
      }

      final shot = await runStarShotSaveFlow(
        context: context,
        repository: repository,
        samples: _controller.samples,
        startedAt: startedAt,
        endedAt: _controller.sessionEndedAt,
        initialMetadata: _repeatShotController?.prefill?.metadata,
        annotations: _annotationController.annotations,
        idGenerator: widget.shotIdGenerator,
        onSaved: widget.onShotSaved,
      );

      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: shot,
        confettiController: _confettiController,
      );
    } finally {
      if (mounted) {
        setState(() => _savingShot = false);
      }
    }
  }

  Future<void> _onRepeatShotPressed() async {
    if (!_controller.canSaveShot) {
      return;
    }

    final startedAt = _controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    final shot = buildShotFromSession(
      samples: _controller.samples,
      startedAt: startedAt,
      endedAt: _controller.sessionEndedAt,
    );

    await startRepeatShotFromShot(
      context: context,
      shot: shot,
      profileRepository: await _ensureProfileRepository(),
      repeatController: _repeatShotController,
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[_controller];
    if (_repeatShotController != null) {
      listenables.add(_repeatShotController!);
    }

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final state = _controller.sessionState;
        final samples = _controller.samples;
        final latestSample = samples.isEmpty ? null : samples.last;
        final previousSample =
            samples.length < 2 ? null : samples[samples.length - 2];
        final canAnnotate =
            state != ShotSessionState.idle && samples.isNotEmpty;
        final repeatPrefill = _repeatShotController?.prefill;

        return ConfettiOverlay(
          controller: _confettiController,
          child: LiveShotEndListener(
            controller: _controller,
            shotEndFeedback: widget.shotEndFeedback,
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RecordingBeanFillIndicator(controller: _controller),
                    if (repeatPrefill != null)
                      RepeatShotBanner(
                        profileName: repeatPrefill.profile.name,
                        onDismiss: _repeatShotController!.clear,
                      ),
                    if (repeatPrefill != null) const SizedBox(height: 8),
                    DualCurveChart(
                      samplesNotifier: _samplesNotifier,
                      annotationsNotifier: _annotationsNotifier,
                      targetPressureSamples:
                          repeatPrefill?.targetPressureSamples ?? const [],
                      onAnnotateAtElapsedMs:
                          canAnnotate ? _onAnnotateAtElapsedMs : null,
                    ),
                    const SizedBox(height: 8),
                    AnnotationControls(
                      controller: _annotationController,
                      canMarkChannel: canAnnotate,
                      onMarkChannel: _onMarkChannel,
                    ),
                    const SizedBox(height: 8),
                    if (latestSample != null)
                      LiveMetricsRow(
                        sample: latestSample,
                        previousSample: previousSample,
                      )
                    else
                      const LiveMetricsRow(
                        metrics: LiveMetrics(elapsedMs: 0),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Session: ${state.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_controller.sampleCount} samples',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_controller.canSaveShot)
                      Align(
                        alignment: Alignment.center,
                        child: RepeatShotButton(
                          onPressed: _onRepeatShotPressed,
                        ),
                      ),
                    if (_controller.canSaveShot) const SizedBox(height: 16),
                    LiveControls(controller: _controller),
                  ],
                ),
              ),
              floatingActionButton: StarShotFab(
                enabled: _controller.canSaveShot && !_savingShot,
                onPressed: _onStarShotPressed,
              ),
            ),
          ),
        );
      },
    );
  }
}

String _defaultFixturePath() {
  const candidates = [
    '../../fixtures/sensor_streams/demo_shot.jsonl',
    '../../../fixtures/sensor_streams/demo_shot.jsonl',
    'fixtures/sensor_streams/demo_shot.jsonl',
  ];

  for (final candidate in candidates) {
    final file = File(candidate);
    if (file.existsSync()) {
      return file.path;
    }
  }

  throw StateError(
    'demo_shot.jsonl fixture not found; run from the Flowlog workspace root.',
  );
}