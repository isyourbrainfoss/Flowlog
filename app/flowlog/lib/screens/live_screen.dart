import 'dart:async';
import 'dart:io';

import 'package:flowlog/screens/live/annotations.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
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
    this.sensorSource,
    this.pressureAdapterFactory,
    this.weightAdapterFactory,
  });

  /// Optional override for tests or dependency injection.
  final LiveShotController? controller;

  /// Optional live sensor source override for tests.
  final LiveSensorSource? sensorSource;

  /// Builds pressensor adapters when sensors are connected (tests inject mocks).
  final PressureAdapterFactory? pressureAdapterFactory;

  /// Builds scale adapters when sensors are connected (tests inject mocks).
  final WeightAdapterFactory? weightAdapterFactory;

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
  LiveShotController? _controller;
  late final bool _ownsController;
  bool _controllerReady = false;
  LiveSensorSource? _sensorSource;
  late final ValueNotifier<List<ShotSample>> _samplesNotifier;
  late final ShotAnnotationController _annotationController;
  late final ValueNotifier<List<ShotAnnotation>> _annotationsNotifier;
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
    _ownsController = widget.controller == null;

    _samplesNotifier = ValueNotifier<List<ShotSample>>(const []);
    _annotationController = ShotAnnotationController();
    _annotationsNotifier = ValueNotifier<List<ShotAnnotation>>(
      List<ShotAnnotation>.from(_annotationController.annotations),
    );
    _annotationController.addListener(_syncAnnotations);

    if (widget.controller != null) {
      _bindController(widget.controller!);
      _controllerReady = true;
    }
  }

  void _bindController(LiveShotController controller) {
    _controller?.removeListener(_syncSamples);
    _controller = controller;
    _controller!.addListener(_syncSamples);
    _syncSamples();
  }

  void _ensureProductionController() {
    final hub = SensorHubScope.of(context);
    _sensorSource = widget.sensorSource ??
        LiveSensorSource(
          hub: hub,
          demoFixturePath: _defaultFixturePath(),
          pressureAdapterFactory: widget.pressureAdapterFactory,
          weightAdapterFactory: widget.weightAdapterFactory,
        );

    _bindController(
      LiveShotController(
        sampleAdapter: SessionSensorAdapter(
          resolve: _sensorSource!.resolveSampleAdapter,
        ),
        onTare: _sensorSource!.onTare,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllerReady && widget.controller == null) {
      _ensureProductionController();
      _controllerReady = true;
    }

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
    _controller?.removeListener(_syncSamples);
    _annotationController.removeListener(_syncAnnotations);
    _annotationController.dispose();
    _annotationsNotifier.dispose();
    _samplesNotifier.dispose();
    if (_ownsController) {
      _controller?.dispose();
    }
    if (_ownsRepository) {
      unawaited(_database?.close());
    }
    super.dispose();
  }

  void _syncSamples() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final state = controller.sessionState;
    if (state == ShotSessionState.recording &&
        _lastSessionState != ShotSessionState.recording) {
      _annotationController.clear();
    }
    _lastSessionState = state;
    _samplesNotifier.value = List<ShotSample>.from(controller.samples);
  }

  void _syncAnnotations() {
    _annotationsNotifier.value =
        List<ShotAnnotation>.from(_annotationController.annotations);
  }

  int? _currentElapsedMs() {
    final samples = _controller?.samples ?? const [];
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
    if (_controller?.sessionState == ShotSessionState.idle) {
      return;
    }

    await promptChartAnnotationAction(
      context: context,
      controller: _annotationController,
      elapsedMs: elapsedMs,
    );
  }

  Future<void> _onToggleShotShortcut() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    if (controller.canStart) {
      await controller.start();
    } else if (controller.canStop) {
      await controller.stop();
    }
  }

  Future<void> _onTryDemoShot() async {
    final controller = _controller;
    final source = _sensorSource;
    if (controller == null ||
        source == null ||
        controller.sessionState == ShotSessionState.recording ||
        controller.sessionState == ShotSessionState.paused ||
        source.isDemoMode) {
      return;
    }

    source.enterDemoMode();
    setState(() {});
    await controller.start();
  }

  void _onDismissDemoMode() {
    _sensorSource?.exitDemoMode();
    setState(() {});
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
    final controller = _controller;
    if (controller == null || !controller.canSaveShot || _savingShot) {
      return;
    }

    final startedAt = controller.sessionStartedAt;
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
        samples: controller.samples,
        startedAt: startedAt,
        endedAt: controller.sessionEndedAt,
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
    final controller = _controller;
    if (controller == null || !controller.canSaveShot) {
      return;
    }

    final startedAt = controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    final shot = buildShotFromSession(
      samples: controller.samples,
      startedAt: startedAt,
      endedAt: controller.sessionEndedAt,
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
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(
        primary: false,
        body: SizedBox.shrink(),
      );
    }

    final listenables = <Listenable>[controller];
    if (_repeatShotController != null) {
      listenables.add(_repeatShotController!);
    }

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final state = controller.sessionState;
        final samples = controller.samples;
        final demoModeActive = _sensorSource?.isDemoMode ?? false;
        final showTryDemoButton = !demoModeActive &&
            state != ShotSessionState.recording &&
            state != ShotSessionState.paused;
        final latestSample = samples.isEmpty ? null : samples.last;
        final previousSample =
            samples.length < 2 ? null : samples[samples.length - 2];
        final canAnnotate =
            state != ShotSessionState.idle && samples.isNotEmpty;
        final repeatPrefill = _repeatShotController?.prefill;

        return ConfettiOverlay(
          controller: _confettiController,
          child: LiveShotEndListener(
            controller: controller,
            shotEndFeedback: widget.shotEndFeedback,
            child: Scaffold(
              primary: false,
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final useCompactLayout =
                      constraints.maxWidth < ShellBreakpoints.sidebar ||
                      constraints.maxHeight < ShellBreakpoints.minRailHeight;
                  final horizontalPadding = useCompactLayout ? 8.0 : 24.0;
                  final chartHeight = _liveChartHeight(constraints);

                  final chartSection = Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RecordingBeanFillIndicator(controller: controller),
                        if (demoModeActive)
                          DemoModeBanner(onDismiss: _onDismissDemoMode),
                        if (demoModeActive) const SizedBox(height: 8),
                        if (repeatPrefill != null)
                          RepeatShotBanner(
                            profileName: repeatPrefill.profile.name,
                            onDismiss: _repeatShotController!.clear,
                          ),
                        if (repeatPrefill != null) const SizedBox(height: 8),
                        DualCurveChart(
                          height: chartHeight,
                          samplesNotifier: _samplesNotifier,
                          annotationsNotifier: _annotationsNotifier,
                          targetPressureSamples:
                              repeatPrefill?.targetPressureSamples ?? const [],
                          onAnnotateAtElapsedMs:
                              canAnnotate ? _onAnnotateAtElapsedMs : null,
                        ),
                      ],
                    ),
                  );

                  final controlsSection = Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      8,
                      horizontalPadding,
                      useCompactLayout ? 12 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          '${controller.sampleCount} samples',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (showTryDemoButton)
                          Align(
                            alignment: Alignment.center,
                            child: OutlinedButton.icon(
                              key: const Key('live_try_demo'),
                              onPressed: _onTryDemoShot,
                              icon: const Icon(Icons.science_outlined),
                              label: const Text('Try demo shot'),
                            ),
                          ),
                        if (showTryDemoButton) const SizedBox(height: 16),
                        if (controller.canSaveShot)
                          Align(
                            alignment: Alignment.center,
                            child: RepeatShotButton(
                              onPressed: _onRepeatShotPressed,
                            ),
                          ),
                        if (controller.canSaveShot) const SizedBox(height: 16),
                        LiveControls(controller: controller),
                      ],
                    ),
                  );

                  final pinChart = useCompactLayout &&
                      constraints.maxHeight.isFinite &&
                      constraints.maxHeight >= 360;

                  if (pinChart) {
                    // Pin the chart on phone / bottom-nav layouts so it stays
                    // visible while controls scroll underneath.
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        chartSection,
                        Expanded(child: SingleChildScrollView(child: controlsSection)),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: useCompactLayout ? 12 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        chartSection,
                        controlsSection,
                      ],
                    ),
                  );
                },
              ),
              floatingActionButton: StarShotFab(
                enabled: controller.canSaveShot && !_savingShot,
                onPressed: _onStarShotPressed,
              ),
            ),
          ),
        );
      },
    );
  }
}

double _liveChartHeight(BoxConstraints constraints) {
  if (!constraints.maxHeight.isFinite) {
    return 220;
  }

  if (constraints.maxWidth < ShellBreakpoints.sidebar ||
      constraints.maxHeight < ShellBreakpoints.minRailHeight) {
    return (constraints.maxHeight * 0.34).clamp(140.0, 200.0);
  }

  return 220;
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