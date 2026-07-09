import 'dart:async';
import 'dart:io';

import 'package:flowlog/location/brew_gps.dart';
import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/live/annotations.dart';
import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/brew_complete_banner.dart';
import 'package:flowlog/screens/live/coffeejack_turns_panel.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog/screens/live/fullscreen_chart.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/screens/more/target_brew_screen.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/screens/more/brew_defaults_screen.dart';
import 'package:flowlog/settings/auto_start_settings_store.dart';
import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog/shell/active_brew_scope.dart';
import 'package:flowlog/shell/shot_events.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';

/// Live shot tab: recording controls, live chart, metrics, and god-shot save.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    this.controller,
    this.shotRepository,
    this.beanRepository,
    this.profileRepository,
    this.repeatShotController,
    this.onShotSaved,
    this.shotEndFeedback = const ShotEndFeedback(),
    this.shotIdGenerator = generateShotId,
    this.sensorSource,
    this.pressureAdapterFactory,
    this.weightAdapterFactory,
    this.brewLocationStore,
    this.brewGpsCapture,
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

  /// Optional bean repository override for tests.
  final BeanRepository? beanRepository;

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

  /// Optional brew location settings override for tests.
  final BrewLocationStore? brewLocationStore;

  /// Optional GPS capture override for tests.
  final BrewGpsCapture? brewGpsCapture;

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
  BeanRepository? _beanRepository;
  ProfileRepository? _profileRepository;
  FlowlogDatabase? _database;

  bool _autoSavingShot = false;
  String? _lastAutoSavedShotId;
  ShotSessionState _lastSessionState = ShotSessionState.idle;
  bool _wasBrewing = false;
  FlowlogShortcutRegistry? _shortcutRegistry;
  RepeatShotController? _repeatShotController;
  TargetBrewController? _targetBrewController;
  final ConfettiController _confettiController = ConfettiController();
  late final ChartInteractionController _chartInteractionController;
  final AutoStartSettingsStore _autoStartSettingsStore = AutoStartSettingsStore();
  late final BrewLocationStore _brewLocationStore;
  late final BrewGpsCapture _brewGpsCapture;
  AutoStartSettings _autoStartSettings = const AutoStartSettings();
  CoffeejackSettings _coffeejackSettings = const CoffeejackSettings();
  final CoffeejackSettingsStore _coffeejackSettingsStore =
      CoffeejackSettingsStore();
  BrewSummary? _lastBrewSummary;
  SensorHub? _sensorHub;
  ConnectionState? _lastPressensorState;
  ActiveBrewNotifier? _activeBrewNotifier;
  ShotEventsNotifier? _shotEventsNotifier;
  late final ValueNotifier<double?> _livePressureBarNotifier;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _brewLocationStore = widget.brewLocationStore ?? BrewLocationStore();
    _brewGpsCapture = widget.brewGpsCapture ?? const BrewGpsCapture();

    _samplesNotifier = ValueNotifier<List<ShotSample>>(const []);
    _annotationController = ShotAnnotationController();
    _annotationsNotifier = ValueNotifier<List<ShotAnnotation>>(
      List<ShotAnnotation>.from(_annotationController.annotations),
    );
    _annotationController.addListener(_syncAnnotations);
    _chartInteractionController = ChartInteractionController();
    _livePressureBarNotifier = ValueNotifier<double?>(null);

    if (widget.controller != null) {
      _sensorSource = widget.sensorSource;
      _bindController(widget.controller!);
      _controllerReady = true;
    }

    unawaited(_loadAutoStartSettings());
    unawaited(_loadCoffeejackSettings());
  }

  Future<void> _loadAutoStartSettings() async {
    final settings = await _autoStartSettingsStore.load();
    if (mounted) {
      setState(() => _autoStartSettings = settings);
    }
  }

  Future<void> _loadCoffeejackSettings() async {
    final settings = await _coffeejackSettingsStore.load();
    if (mounted) {
      setState(() => _coffeejackSettings = settings);
    }
  }

  Future<void> _openCoffeejackSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BrewDefaultsScreen(
          coffeejackSettingsStore: _coffeejackSettingsStore,
        ),
      ),
    );
    await _loadCoffeejackSettings();
  }

  Future<void> _onAutoStartThresholdChanged(double value) async {
    final updated = AutoStartSettings(
      enabled: _autoStartSettings.enabled,
      startThresholdBar: value,
      releaseFraction: _autoStartSettings.releaseFraction,
    );
    setState(() => _autoStartSettings = updated);
    await _autoStartSettingsStore.save(updated);
  }

  void _onSensorHubChanged() {
    final hub = _sensorHub;
    if (hub == null) {
      return;
    }

    final current = hub.pressensorState;
    final previous = _lastPressensorState;
    _lastPressensorState = current;

    if (previous != null &&
        previous != ConnectionState.connected &&
        current == ConnectionState.connected &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('pressensor_connected_snackbar'),
          content: Text(
            'Pressensor connected — auto-start at '
            '${_autoStartSettings.startThresholdBar.toStringAsFixed(1)} bar',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _bindController(LiveShotController controller) {
    _controller?.removeListener(_syncSamples);
    _controller?.removeListener(_onSessionLifecycle);
    _controller = controller;
    _controller!.addListener(_syncSamples);
    _controller!.addListener(_onSessionLifecycle);
    _wasBrewing = _controller!.isBrewing;
    _syncSamples();
  }

  void _ensureProductionController() {
    final hub = SensorHubScope.of(context);
    _sensorSource = widget.sensorSource ??
        LiveSensorSource(
          hub: hub,
          demoFixturePath: _resolveDemoFixtureFilePath(),
          demoFixtureLoader: _loadBundledDemoFixture,
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
      _shortcutRegistry!.setStartDemoShot(_onTryDemoShot);
    }
    _repeatShotController =
        widget.repeatShotController ?? RepeatShotScope.maybeOf(context);
    _targetBrewController = TargetBrewScope.maybeOf(context);

    _activeBrewNotifier = ActiveBrewScope.maybeOf(context);
    _shotEventsNotifier = ShotEventsScope.maybeOf(context);

    final hub = SensorHubScope.maybeOf(context);
    if (hub != _sensorHub) {
      _sensorHub?.removeListener(_onSensorHubChanged);
      _sensorHub = hub;
      _lastPressensorState = hub?.pressensorState;
      hub?.addListener(_onSensorHubChanged);
    }
  }

  @override
  void dispose() {
    _sensorHub?.removeListener(_onSensorHubChanged);
    _shortcutRegistry?.setToggleLiveShot(null);
    _shortcutRegistry?.setStartDemoShot(null);
    _confettiController.dispose();
    _chartInteractionController.dispose();
    _activeBrewNotifier?.setBrewing(false);
    _controller?.removeListener(_syncSamples);
    _controller?.removeListener(_onSessionLifecycle);
    _annotationController.removeListener(_syncAnnotations);
    _annotationController.dispose();
    _annotationsNotifier.dispose();
    _livePressureBarNotifier.dispose();
    _samplesNotifier.dispose();
    if (_ownsController) {
      _controller?.dispose();
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

    _database = await openFlowlogDatabase();
    return _database!;
  }

  Future<BeanRepository> _ensureBeanRepository() async {
    if (widget.beanRepository != null) {
      return widget.beanRepository!;
    }
    if (_beanRepository != null) {
      return _beanRepository!;
    }

    final database = await _ensureDatabase();
    _beanRepository = BeanRepository(database);
    return _beanRepository!;
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

  void _onSessionLifecycle() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final brewing = controller.isBrewing;
    _activeBrewNotifier?.setBrewing(brewing);
    if (brewing && _lastBrewSummary != null) {
      setState(() => _lastBrewSummary = null);
    }
    if (_wasBrewing && !brewing && controller.canSaveShot) {
      unawaited(_autoSaveStoppedSession());
    }
    _wasBrewing = brewing;
  }

  Future<void> _autoSaveStoppedSession() async {
    final controller = _controller;
    if (controller == null || !controller.canSaveShot || _autoSavingShot) {
      return;
    }

    final startedAt = controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    setState(() => _autoSavingShot = true);
    try {
      final repository = await _ensureShotRepository();
      if (!mounted) {
        return;
      }

      final activeBean = ActiveBeanScope.maybeOf(context);
      final locationSettings = await _brewLocationStore.loadSettings();
      BrewGpsPosition? gps;
      if (locationSettings.autoGpsEnabled) {
        gps = await _brewGpsCapture.captureCurrentPosition();
      }
      final shot = await runAutoSaveFlow(
        context: context,
        repository: repository,
        shotRepository: repository,
        samples: controller.samples,
        startedAt: startedAt,
        endedAt: controller.sessionEndedAt,
        initialMetadata: _repeatShotController?.prefill?.metadata,
        beanRepository: await _ensureBeanRepository(),
        activeBeanName: activeBean?.name,
        activeBeanId: activeBean?.beanId,
        annotations: _annotationController.annotations,
        location: locationSettings.currentLocation,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        idGenerator: widget.shotIdGenerator,
        onSaved: (saved) {
          _lastAutoSavedShotId = saved.id;
          widget.onShotSaved?.call(saved);
        },
        onAddNotes: (saved) => _onAddNotesToSavedShot(saved),
        onDiscard: (saved) => _onDiscardSavedShot(saved),
      );

      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: shot,
        confettiController: _confettiController,
      );

      if (shot != null) {
        if (mounted) {
          setState(() => _lastBrewSummary = BrewSummary.fromShot(shot));
        }
        _shotEventsNotifier?.notifyShotsChanged();
        final database = await _ensureDatabase();
        unawaited(
          FlowlogSyncCoordinator.syncIfEnabled(database: database),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _autoSavingShot = false);
      }
    }
  }

  Future<void> _onAddNotesToSavedShot(Shot shot) async {
    final repository = await _ensureShotRepository();
    if (!mounted) {
      return;
    }

    final updated = await runAddNotesFlow(
      context: context,
      repository: repository,
      beanRepository: await _ensureBeanRepository(),
      shot: shot,
      onSaved: widget.onShotSaved,
    );

    if (updated != null) {
      _shotEventsNotifier?.notifyShotsChanged();
      await celebratePersonalBestTasteScore(
        repository: repository,
        shot: updated,
        confettiController: _confettiController,
      );
    }
  }

  Future<void> _onDiscardSavedShot(Shot shot) async {
    final repository = await _ensureShotRepository();
    await repository.deleteShot(shot.id);
    if (_lastAutoSavedShotId == shot.id) {
      _lastAutoSavedShotId = null;
    }
    _shotEventsNotifier?.notifyShotsChanged();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('shot_discarded_snackbar'),
          content: Text('Shot discarded'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<ShotSample> _chartTargetPressureSamples() {
    final repeatSamples =
        _repeatShotController?.prefill?.targetPressureSamples;
    if (repeatSamples != null && repeatSamples.isNotEmpty) {
      return repeatSamples;
    }
    return _targetBrewController?.pressureSamples ?? const [];
  }

  void _onOpenFullscreenChart() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    unawaited(
      openLiveFullscreenChart(
        context,
        controller: controller,
        samplesNotifier: _samplesNotifier,
        annotationsNotifier: _annotationsNotifier,
        interactionController: _chartInteractionController,
        targetPressureSamples: _chartTargetPressureSamples(),
        onAnnotateAtElapsedMs: _controller?.sessionState ==
                ShotSessionState.idle
            ? null
            : _onAnnotateAtElapsedMs,
      ),
    );
  }

  bool _showAutoStartBanner({
    required bool demoModeActive,
    required bool canStart,
  }) {
    if (demoModeActive || !canStart) {
      return false;
    }

    final hub = SensorHubScope.maybeOf(context);
    final source = _sensorSource;
    if (hub?.activeAdapterFor(SensorKind.pressensor) != null) {
      return true;
    }

    if (source == null || !source.hasConnectedSensors) {
      return false;
    }

    return source.resolveSampleAdapter() is! IdleSensorAdapter;
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
      repeatController:
          _repeatShotController ?? widget.repeatShotController,
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
    if (_targetBrewController != null) {
      listenables.add(_targetBrewController!);
    }

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final state = controller.sessionState;
        final samples = controller.samples;
        final demoModeActive = _sensorSource?.isDemoMode ?? false;
        final latestSample = samples.isEmpty ? null : samples.last;
        final previousSample =
            samples.length < 2 ? null : samples[samples.length - 2];
        final canAnnotate =
            state != ShotSessionState.idle && samples.isNotEmpty;
        final repeatPrefill = _repeatShotController?.prefill;
        final targetBrew = _targetBrewController;
        final chartTargetSamples = _chartTargetPressureSamples();
        final showDefaultTargetBanner = repeatPrefill == null &&
            targetBrew != null &&
            targetBrew.hasTarget;

        final showAutoStart = _showAutoStartBanner(
          demoModeActive: demoModeActive,
          canStart: controller.canStart,
        );

        final shell = ConfettiOverlay(
          controller: _confettiController,
          child: LiveShotEndListener(
            controller: controller,
            shotEndFeedback: widget.shotEndFeedback,
            child: LayoutBuilder(
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
                        if (showDefaultTargetBanner)
                          TargetBrewBanner(
                            profileName: targetBrew.profileName ?? 'Target',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (context) => TargetBrewScreen(
                                    targetBrewController: targetBrew,
                                  ),
                                ),
                              );
                            },
                          ),
                        if (showDefaultTargetBanner) const SizedBox(height: 8),
                        if (showAutoStart)
                          AutoStartArmedBanner(
                            thresholdBar: _autoStartSettings.startThresholdBar,
                            pressureBarNotifier: _livePressureBarNotifier,
                          ),
                        if (showAutoStart)
                          AutoStartThresholdPanel(
                            thresholdBar: _autoStartSettings.startThresholdBar,
                            onThresholdChanged: (value) =>
                                unawaited(_onAutoStartThresholdChanged(value)),
                          ),
                        if (showAutoStart) const SizedBox(height: 8),
                        if (_lastBrewSummary != null && !controller.isBrewing) ...[
                          BrewCompleteBanner(
                            summary: _lastBrewSummary!,
                            onDismiss: () =>
                                setState(() => _lastBrewSummary = null),
                          ),
                          const SizedBox(height: 8),
                        ],
                        LiveFullscreenChartButton(
                          onPressed: _onOpenFullscreenChart,
                        ),
                        DualCurveChart(
                          height: chartHeight,
                          samplesNotifier: _samplesNotifier,
                          annotationsNotifier: _annotationsNotifier,
                          interactionController: _chartInteractionController,
                          denseTimeAxis: true,
                          targetPressureSamples: chartTargetSamples,
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
                        const SizedBox(height: 8),
                        Text(
                          '${controller.sampleCount} samples',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        if (!controller.isBrewing) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Session: ${state.name}',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          CoffeejackTurnsPanel(
                            settings: _coffeejackSettings,
                            onTap: () => unawaited(_openCoffeejackSettings()),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (controller.canSaveShot)
                          Align(
                            alignment: Alignment.center,
                            child: RepeatShotButton(
                              onPressed: () => unawaited(_onRepeatShotPressed()),
                            ),
                          ),
                        if (controller.canSaveShot) const SizedBox(height: 16),
                      ],
                    ),
                  );

                  final pinChart = constraints.maxHeight.isFinite &&
                      constraints.maxHeight >= 360;

                  final body = pinChart
                      ? Column(
                          key: const ValueKey('live-pinned-layout'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            chartSection,
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  top: useCompactLayout ? 0 : 8,
                                ),
                                child: controlsSection,
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          key: const ValueKey('live-scroll-layout'),
                          padding: EdgeInsets.symmetric(
                            vertical: useCompactLayout ? 12 : 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              chartSection,
                              controlsSection,
                            ],
                          ),
                        );

                  return Scaffold(
                    primary: false,
                    bottomNavigationBar: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          useCompactLayout ? 8 : 12,
                        ),
                        child: LiveControls(
                          controller: controller,
                          prominent: useCompactLayout,
                        ),
                      ),
                    ),
                    body: body,
                  );
                },
              ),
            ),
        );

        final hub = SensorHubScope.maybeOf(context);
        if (hub == null) {
          return shell;
        }

        return LiveAutoStartListener(
          controller: controller,
          hub: hub,
          sensorSource: _sensorSource,
          settings: _autoStartSettings,
          isDemoMode: demoModeActive,
          pressureBarNotifier: _livePressureBarNotifier,
          child: shell,
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

const String kBundledDemoFixtureAsset = 'assets/demo_shot.jsonl';

String? _resolveDemoFixtureFilePath() {
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

  return null;
}

Future<List<SensorSample>> _loadBundledDemoFixture() async {
  final content = await rootBundle.loadString(kBundledDemoFixtureAsset);
  return MockReplayAdapter.parseLines(
    content.split('\n'),
    source: kBundledDemoFixtureAsset,
  );
}