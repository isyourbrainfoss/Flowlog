import 'dart:async';
import 'dart:io';

import 'package:flowlog/location/brew_gps.dart';
import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/live/annotations.dart';
import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/brew_complete_banner.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog/screens/live/fullscreen_chart.dart';
import 'package:flowlog/screens/live/metrics_row.dart';
import 'package:flowlog/screens/live/live_pressure_bar.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/active_bean_scope.dart';
import 'package:flowlog/shell/active_brew_scope.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shot_events.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/shell_scope.dart';
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
    this.autoStartController,
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

  /// Optional auto-start controller override for tests.
  final AutoStartSettingsController? autoStartController;

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
  bool _autoSavedCurrent = false;
  ShotSessionState _lastSessionState = ShotSessionState.idle;
  bool _wasBrewing = false;
  Timer? _autoStopTimer;
  FlowlogShortcutRegistry? _shortcutRegistry;
  RepeatShotController? _repeatShotController;
  TargetBrewController? _targetBrewController;
  final ConfettiController _confettiController = ConfettiController();
  late final BrewDefaultsSettingsStore _brewDefaultsStore;
  BrewDefaultsSettings? _brewDefaults;
  late final ChartInteractionController _chartInteractionController;
  late final AutoStartSettingsController _ownedAutoStartController;
  AutoStartSettingsController? _autoStartController;
  late final BrewLocationStore _brewLocationStore;
  late final BrewGpsCapture _brewGpsCapture;
  BrewSummary? _lastBrewSummary;
  SensorHub? _sensorHub;
  ConnectionState? _lastPressensorState;
  ActiveBrewNotifier? _activeBrewNotifier;
  ShotEventsNotifier? _shotEventsNotifier;
  /// Fires once per brew when cup weight crosses the early-stop warn level.
  bool _yieldWarnFired = false;
  bool _showYieldWarnBanner = false;

  late final ValueNotifier<double?> _livePressureNotifier;
  late final ValueNotifier<DateTime?> _livePressureLastUpdate;
  DateTime _lastSamplesUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _brewLocationStore = widget.brewLocationStore ?? BrewLocationStore();
    _brewGpsCapture = widget.brewGpsCapture ?? const BrewGpsCapture();

    _samplesNotifier = ValueNotifier<List<ShotSample>>(const []);
    _livePressureNotifier = ValueNotifier<double?>(null);
    _livePressureLastUpdate = ValueNotifier<DateTime?>(null);
    _annotationController = ShotAnnotationController();
    _annotationsNotifier = ValueNotifier<List<ShotAnnotation>>(
      List<ShotAnnotation>.from(_annotationController.annotations),
    );
    _annotationController.addListener(_syncAnnotations);
    _chartInteractionController = ChartInteractionController();
    _ownedAutoStartController = AutoStartSettingsController();
    unawaited(_ownedAutoStartController.load());
    _brewDefaultsStore = BrewDefaultsSettingsStore();
    unawaited(_brewDefaultsStore.load().then((d) {
      _brewDefaults = d;
      if (mounted) setState(() {});
    }));

    if (widget.controller != null) {
      _sensorSource = widget.sensorSource;
      _bindController(widget.controller!);
      _controllerReady = true;
    }

  }

  AutoStartSettingsController get _resolvedAutoStartController {
    return _autoStartController ??
        widget.autoStartController ??
        _ownedAutoStartController;
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
      final threshold =
          _resolvedAutoStartController.settings.startThresholdBar;
      final batteryWarning =
          pressensorLowBatteryWarning(hub.pressensorBatteryPercent);
      final message = StringBuffer(
        'Pressensor connected — auto-start at ${threshold.toStringAsFixed(1)} bar',
      );
      if (batteryWarning != null) {
        message.write('. $batteryWarning');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('pressensor_connected_snackbar'),
          content: Text(message.toString()),
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
    _autoSavedCurrent = false;
    _lastAutoSavedShotId = null;
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
    _autoStartController = widget.autoStartController ??
        AutoStartSettingsScope.maybeOf(context);

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
    _ownedAutoStartController.dispose();
    _samplesNotifier.dispose();
    _autoStopTimer?.cancel();
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

    // Full samples list to chart at ~30 fps to reduce repaint lag/cost.
    // Individual pressure value updates at full sensor rate (see _livePressureNotifier).
    final now = DateTime.now();
    if (now.difference(_lastSamplesUpdate).inMilliseconds >= 33) {
      _samplesNotifier.value = List<ShotSample>.from(controller.samples);
      _lastSamplesUpdate = now;
    }

    _checkAutoStop(controller);
    _maybeFireYieldWarn(controller);
  }

  void _maybeFireYieldWarn(LiveShotController controller) {
    if (!controller.isBrewing || _yieldWarnFired) {
      return;
    }
    final defaults = _brewDefaults;
    if (defaults == null || !defaults.yieldAlertEnabled) {
      return;
    }
    final samples = controller.samples;
    if (samples.isEmpty) {
      return;
    }
    final weight = samples.last.weightG;
    if (!shouldFireYieldWarn(
      weightG: weight,
      warnAtG: defaults.effectiveYieldWarnAtG,
      targetYieldG: defaults.targetYieldG,
      alreadyFired: _yieldWarnFired,
    )) {
      return;
    }

    _yieldWarnFired = true;
    if (mounted) {
      setState(() => _showYieldWarnBanner = true);
    }
    unawaited(playYieldWarnCue());
  }

  void _checkAutoStop(LiveShotController controller) {
    if (controller.sessionState != ShotSessionState.recording) {
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      return;
    }

    final samples = controller.samples;
    if (samples.length < 8) return; // need some history (~0.8s at 100ms)

    // Look at last ~8 samples (~800ms). If pressure has been near zero after
    // we have seen meaningful pressure, auto-stop so forgotten brews don't
    // save huge zero tails. Do not auto-stop during initial low-pressure
    // pre-infusion or when user manually starts the brew button before the
    // pump has built pressure.
    final recent = samples.sublist(samples.length - 8);
    final allLow = recent.every((s) => (s.pressureBar ?? 100) < 0.4);

    if (allLow) {
      final hasSeenPressure = samples.any((s) => (s.pressureBar ?? 0) >= 0.8);
      if (hasSeenPressure) {
        _autoStopTimer ??= Timer(const Duration(milliseconds: 1500), () {
          if (mounted &&
              _controller != null &&
              _controller!.sessionState == ShotSessionState.recording) {
            _controller!.stop();
          }
          _autoStopTimer = null;
        });
      } else {
        _autoStopTimer?.cancel();
        _autoStopTimer = null;
      }
    } else {
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
    }
  }

  void _syncAnnotations() {
    _annotationsNotifier.value =
        List<ShotAnnotation>.from(_annotationController.annotations);
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

  void _onReconnectSensors() {
    // Clear leftover post-shot readings so the status banner does not keep
    // showing a stale "last" value while reconnect is in progress.
    _livePressureNotifier.value = null;
    _livePressureLastUpdate.value = null;

    final hub = SensorHubScope.maybeOf(context);
    if (hub != null) {
      unawaited(hub.reconnectPairedDevices());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnecting paired sensors...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onPairSensors() {
    FlowlogShellScope.maybeOf(context)?.switchTab(AppTab.more);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Sensors')),
          body: const SensorsScreen(),
        ),
      ),
    );
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
    // Trigger auto-save on stop transition (covers both manual stop and auto-stop).
    if (_wasBrewing && !brewing && controller.canSaveShot && !_autoSavedCurrent) {
      unawaited(_autoSaveStoppedSession());
    }
    // Also catch stopped state directly (helps auto-stop timer path reliability)
    if (controller.sessionState == ShotSessionState.stopped &&
        controller.canSaveShot &&
        !_autoSavedCurrent) {
      unawaited(_autoSaveStoppedSession());
    }
    if (brewing && !_wasBrewing) {
      _autoSavedCurrent = false;
      _lastAutoSavedShotId = null;
      _yieldWarnFired = false;
      _showYieldWarnBanner = false;
      _chartInteractionController.resetViewport();
      // Reload brew defaults so yield target/warn edits apply to this shot.
      unawaited(_brewDefaultsStore.load().then((d) {
        if (mounted) setState(() => _brewDefaults = d);
      }));
    }
    if (!brewing && _wasBrewing) {
      // Keep banner briefly after stop is fine; clear when leaving brew UI noise.
      // Banner stays until next brew start.
    }
    _wasBrewing = brewing;
  }

  Future<void> _autoSaveStoppedSession() async {
    final controller = _controller;
    if (controller == null ||
        !controller.canSaveShot ||
        _autoSavingShot ||
        _autoSavedCurrent) {
      return;
    }

    final startedAt = controller.sessionStartedAt;
    if (startedAt == null) {
      return;
    }

    _autoSavedCurrent = true;
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
      final beanRepository = await _ensureBeanRepository();
      if (!mounted) {
        return;
      }

      final targetSamples = _chartTargetPressureSamples();
      final shot = await runAutoSaveFlow(
        context: context,
        repository: repository,
        shotRepository: repository,
        samples: controller.samples,
        startedAt: startedAt,
        endedAt: controller.sessionEndedAt,
        initialMetadata: _repeatShotController?.prefill?.metadata,
        beanRepository: beanRepository,
        activeBeanName: activeBean?.name,
        activeBeanId: activeBean?.beanId,
        annotations: _annotationController.annotations,
        location: locationSettings.currentLocation,
        latitude: gps?.latitude,
        longitude: gps?.longitude,
        autoStartPressureBar: controller.autoStartPressureBar,
        targetPressureSamples: targetSamples,
        idGenerator: widget.shotIdGenerator,
        onSaved: (saved) {
          _lastAutoSavedShotId = saved.id;
          _autoSavedCurrent = true;
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
          _autoSavedCurrent = true;
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

    final beanRepository = await _ensureBeanRepository();
    if (!mounted) {
      return;
    }

    final updated = await runAddNotesFlow(
      context: context,
      repository: repository,
      beanRepository: beanRepository,
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
      final database = await _ensureDatabase();
      unawaited(
        FlowlogSyncCoordinator.syncIfEnabled(database: database),
      );
    }
  }

  Future<void> _onDiscardSavedShot(Shot shot) async {
    final repository = await _ensureShotRepository();
    if (!mounted) {
      return;
    }
    await repository.deleteShot(shot.id);
    if (_lastAutoSavedShotId == shot.id) {
      _lastAutoSavedShotId = null;
      _autoSavedCurrent = false;
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

  Future<void> _saveCurrentSession() async {
    final controller = _controller;
    if (controller == null || !controller.canSaveShot || _autoSavedCurrent) {
      return;
    }
    await _autoSaveStoppedSession();
  }

  Future<void> _editLastSavedShot() async {
    if (_lastAutoSavedShotId == null) return;
    final repository = await _ensureShotRepository();
    if (!mounted) return;
    final shot = await repository.getShotWithSamples(_lastAutoSavedShotId!);
    if (shot == null || !mounted) return;
    await _onAddNotesToSavedShot(shot);
  }

  List<ShotSample> _chartTargetPressureSamples() {
    final repeatSamples =
        _repeatShotController?.prefill?.targetPressureSamples;
    if (repeatSamples != null && repeatSamples.isNotEmpty) {
      return repeatSamples;
    }
    if (_brewDefaults?.useDefaultTargetBrew ?? true) {
      return _targetBrewController?.pressureSamples ?? const [];
    }
    return const [];
  }

  double? _targetPressureAtElapsed(int elapsedMs) {
    final targets = _chartTargetPressureSamples();
    return interpolateTargetPressure(targets, elapsedMs);
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
      ),
    );
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

    final profileRepository = await _ensureProfileRepository();
    if (!mounted) {
      return;
    }

    await startRepeatShotFromShot(
      context: context,
      shot: shot,
      profileRepository: profileRepository,
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
    listenables.add(_resolvedAutoStartController);
    final sensorHub = SensorHubScope.maybeOf(context);
    if (sensorHub != null) {
      listenables.add(sensorHub);
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
        final repeatPrefill = _repeatShotController?.prefill;
        final chartTargetSamples = _chartTargetPressureSamples();
        final autoStartSettings = _resolvedAutoStartController.settings;

        // Live gamification stats (recomputed cheaply on each sample update)
        final bool showLiveGamif =
            (state == ShotSessionState.recording ||
                state == ShotSessionState.paused ||
                state == ShotSessionState.stopped) &&
            samples.isNotEmpty &&
            chartTargetSamples.isNotEmpty;
        final Map<String, dynamic> liveGamif = showLiveGamif
            ? computeTargetGamification(samples, chartTargetSamples)
            : const <String, dynamic>{
                'closenessPercent': null,
                'maxStreakSeconds': 0,
                'currentStreakSeconds': 0,
                'penaltyCount': 0,
                'score': null,
              };

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
                        if (demoModeActive)
                          DemoModeBanner(onDismiss: _onDismissDemoMode),
                        if (demoModeActive) const SizedBox(height: 8),
                        if (repeatPrefill != null)
                          RepeatShotBanner(
                            profileName: repeatPrefill.profile.name,
                            onDismiss: _repeatShotController!.clear,
                          ),
                        if (repeatPrefill != null) const SizedBox(height: 8),
                        if (_lastBrewSummary != null && !controller.isBrewing) ...[
                          BrewCompleteBanner(
                            summary: _lastBrewSummary!,
                            onDismiss: () =>
                                setState(() => _lastBrewSummary = null),
                            onEdit: _lastAutoSavedShotId != null
                                ? () => unawaited(_editLastSavedShot())
                                : null,
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Prominent sensor readiness shown with the plot after a shot,
                        // so it's obvious whether pressensor is still connected and
                        // ready for the next brew (was clear on first shot, now reinforced).
                        if ((state == ShotSessionState.idle || state == ShotSessionState.stopped) &&
                            !controller.isBrewing)
                          _IdleSensorStatus(
                            pressureBarNotifier: _livePressureNotifier,
                            lastUpdateNotifier: _livePressureLastUpdate,
                            pressensorPaired: SensorHubScope.maybeOf(context)
                                    ?.hasKind(SensorKind.pressensor) ??
                                false,
                            pressensorLinkState: SensorHubScope.maybeOf(context)
                                    ?.pressensorState ??
                                ConnectionState.disconnected,
                            onReconnect: _onReconnectSensors,
                            onPair: _onPairSensors,
                            autoStartEnabled: _resolvedAutoStartController.settings.enabled,
                            autoStartThreshold: _resolvedAutoStartController.settings.startThresholdBar,
                          ),
                        if ((state == ShotSessionState.idle || state == ShotSessionState.stopped) &&
                            !controller.isBrewing)
                          const SizedBox(height: 8),
                        // Fullscreen control sits on the chart (lower-right) so
                        // the plot keeps full width/height.
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            DualCurveChart(
                              height: chartHeight,
                              samplesNotifier: _samplesNotifier,
                              annotationsNotifier: _annotationsNotifier,
                              interactionController:
                                  _chartInteractionController,
                              denseTimeAxis: true,
                              targetPressureSamples: chartTargetSamples,
                            ),
                            Positioned(
                              right: 4,
                              bottom: 28,
                              child: LiveFullscreenChartButton(
                                onPressed: _onOpenFullscreenChart,
                              ),
                            ),
                          ],
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
                        if ((state == ShotSessionState.recording || state == ShotSessionState.paused || state == ShotSessionState.stopped) && latestSample != null) ...[
                          LiveMetricsRow(
                            sample: latestSample,
                            previousSample: previousSample,
                          ),
                          const SizedBox(height: 8),
                          LiveYieldProgress(
                            weightG: latestSample.weightG,
                            targetYieldG:
                                _brewDefaults?.targetYieldG ?? kDefaultTargetYieldG,
                            warnAtG: _brewDefaults?.effectiveYieldWarnAtG ??
                                kDefaultYieldWarnAtG,
                            showWarnBanner: _showYieldWarnBanner &&
                                (state == ShotSessionState.recording ||
                                    state == ShotSessionState.paused),
                          ),
                          const SizedBox(height: 6),
                          LivePressureDeviationBar(
                            currentPressure: latestSample.pressureBar,
                            targetPressure: _targetPressureAtElapsed(latestSample.elapsedMs),
                          ),
                          if (chartTargetSamples.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _LiveTargetGamification(
                              closeness: liveGamif['closenessPercent'] as double?,
                              maxStreakSec: liveGamif['maxStreakSeconds'] as int? ?? 0,
                              currentStreakSec: liveGamif['currentStreakSeconds'] as int? ?? 0,
                              penaltyCount: liveGamif['penaltyCount'] as int? ?? 0,
                              score: liveGamif['score'] as double?,
                            ),
                          ],
                        ] else if (state == ShotSessionState.idle || state == ShotSessionState.stopped) ...[
                          // (sensor readiness and auto-start info is now shown prominently
                          // above the chart via _IdleSensorStatus for consistency before/after shots)
                        ] else
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
                        ],
                        if (controller.canSaveShot) ...[
                          Align(
                            alignment: Alignment.center,
                            child: RepeatShotButton(
                              onPressed: () => unawaited(_onRepeatShotPressed()),
                            ),
                          ),
                          if (!_autoSavedCurrent) ...[
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              key: const Key('save_current_shot_button'),
                              onPressed: () => unawaited(_saveCurrentSession()),
                              icon: const Icon(Icons.save),
                              label: const Text('Save shot'),
                            ),
                          ],
                        ],
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
          settings: autoStartSettings,
          isDemoMode: demoModeActive,
          pressureBarNotifier: _livePressureNotifier,
          pressureLastUpdateNotifier: _livePressureLastUpdate,
          child: shell,
        );
      },
    );
  }
}

double _liveChartHeight(BoxConstraints constraints) {
  if (!constraints.maxHeight.isFinite) {
    return 280;
  }

  if (constraints.maxWidth < ShellBreakpoints.sidebar ||
      constraints.maxHeight < ShellBreakpoints.minRailHeight) {
    // Give the plot more vertical space on phones; cap so controls still fit.
    return (constraints.maxHeight * 0.42).clamp(180.0, 280.0);
  }

  return 300;
}

/// Compact live gamification strip shown while brewing against a target curve.
/// Displays running closeness %, current/max green streak, number of distinct
/// penalty periods, and score (less strict event-based penalties).
class _LiveTargetGamification extends StatelessWidget {
  const _LiveTargetGamification({
    // ignore: unused_element_parameter
    super.key,
    required this.closeness,
    required this.maxStreakSec,
    required this.currentStreakSec,
    required this.penaltyCount,
    required this.score,
  });

  final double? closeness;
  final int maxStreakSec;
  final int currentStreakSec;
  final int penaltyCount;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTarget = closeness != null || score != null || maxStreakSec > 0 || currentStreakSec > 0;

    if (!hasTarget) {
      return const SizedBox.shrink();
    }

    final closenessStr = closeness != null ? '${closeness!.toStringAsFixed(0)}%' : '—';
    final scoreStr = score != null ? score!.toStringAsFixed(0) : '—';
    final streakStr = currentStreakSec > 0
        ? '${currentStreakSec}s / ${maxStreakSec}s'
        : (maxStreakSec > 0 ? 'max ${maxStreakSec}s' : '—');

    final isGoodStreak = currentStreakSec >= 3;
    final streakColor = isGoodStreak ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant;
    final hasPenalties = penaltyCount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                _GamifPill(label: 'Close', value: closenessStr),
                _GamifPill(
                  label: 'Streak',
                  value: streakStr,
                  valueColor: streakColor,
                ),
                if (hasPenalties)
                  _GamifPill(
                    label: 'Penalties',
                    value: '$penaltyCount',
                    valueColor: theme.colorScheme.error,
                  ),
                _GamifPill(label: 'Score', value: scoreStr),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GamifPill extends StatelessWidget {
  const _GamifPill({
    // ignore: unused_element_parameter
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valueColor ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// How long a pressure reading stays "live" before the home screen treats
/// the pressensor as not ready (same UX as a fresh app open).
///
/// Kept in sync with [kLivePressureFreshWindow] in auto_start.dart, which also
/// clears leftover values after this window so idle never looks "ready" with
/// a stale sample (especially right after a brew ends).
Duration get kIdlePressureLiveWindow => kLivePressureFreshWindow;

/// Clear sensor connection + readiness status shown above the plot in idle
/// (post-shot) state on the main/home view.
///
/// A leftover pressure value after a brew is NOT treated as "connected /
/// ready" once it goes stale — otherwise the UI looks ready when the
/// sensor has already dropped (common right after a shot). Stale and missing
/// readings both show the red "not ready" state. Action is **Reconnect** when
/// a pressensor is already paired, or **Pair sensor** when none is paired.
/// LiveAutoStartListener also clears notifiers on brew start/stop and when
/// samples age out.
class _IdleSensorStatus extends StatefulWidget {
  const _IdleSensorStatus({
    required this.pressureBarNotifier,
    required this.lastUpdateNotifier,
    required this.pressensorPaired,
    required this.pressensorLinkState,
    required this.onReconnect,
    required this.onPair,
    required this.autoStartEnabled,
    required this.autoStartThreshold,
  });

  final ValueNotifier<double?> pressureBarNotifier;
  final ValueNotifier<DateTime?> lastUpdateNotifier;
  final bool pressensorPaired;
  final ConnectionState pressensorLinkState;
  final VoidCallback onReconnect;
  final VoidCallback onPair;
  final bool autoStartEnabled;
  final double autoStartThreshold;

  @override
  State<_IdleSensorStatus> createState() => _IdleSensorStatusState();
}

class _IdleSensorStatusState extends State<_IdleSensorStatus> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Only tick while this route is animated (Live tab visible). Avoids
    // rebuilding Live every second while the user is on History / Library.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (!TickerMode.valuesOf(context).enabled) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _isLive(double? pressure, DateTime? lastUpdate) {
    if (pressure == null) {
      return false;
    }
    if (lastUpdate == null) {
      // Value without a timestamp is treated as not live (cannot prove freshness).
      return false;
    }
    return DateTime.now().difference(lastUpdate) <= kIdlePressureLiveWindow;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final paired = widget.pressensorPaired;
    final link = widget.pressensorLinkState;
    final linkConnected = link == ConnectionState.connected;
    final linkConnecting = link == ConnectionState.connecting;

    return ValueListenableBuilder<double?>(
      valueListenable: widget.pressureBarNotifier,
      builder: (context, pressure, _) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: widget.lastUpdateNotifier,
          builder: (context, lastUpdate, _) {
            final isLive = _isLive(pressure, lastUpdate);
            final hasStaleReading = pressure != null && !isLive;

            // BLE link is the source of truth for "connected". Live samples
            // only refine readiness for auto-start. Previously "not connected"
            // was shown whenever samples were missing even if BLE was up.
            final bool showReady = isLive && pressure != null;
            final bool showLinkedWaiting =
                !showReady && (linkConnected || linkConnecting);

            final Color color;
            final Color onColor;
            final IconData icon;
            if (showReady) {
              color = cs.primaryContainer;
              onColor = cs.onPrimaryContainer;
              icon = Icons.sensors;
            } else if (showLinkedWaiting) {
              color = cs.secondaryContainer;
              onColor = cs.onSecondaryContainer;
              icon = Icons.sensors;
            } else {
              color = cs.errorContainer;
              onColor = cs.onErrorContainer;
              icon = Icons.sensors_off;
            }

            final String title;
            final String subtitle;
            if (isLive && pressure != null) {
              title = 'Pressensor connected — ready for new shot';
              final pStr = pressure.toStringAsFixed(2);
              subtitle = widget.autoStartEnabled
                  ? 'Live: $pStr bar · Auto-start at ${widget.autoStartThreshold.toStringAsFixed(1)} bar'
                  : 'Live: $pStr bar';
            } else if (linkConnecting) {
              title = 'Pressensor connecting…';
              subtitle = 'Waiting for BLE link';
            } else if (linkConnected && hasStaleReading) {
              title = 'Pressensor connected — refreshing live pressure';
              final pStr = pressure.toStringAsFixed(2);
              subtitle =
                  'Last reading: $pStr bar. Auto-start needs a fresh stream.';
            } else if (linkConnected) {
              title = 'Pressensor connected';
              subtitle = widget.autoStartEnabled
                  ? 'Waiting for live pressure · Auto-start at ${widget.autoStartThreshold.toStringAsFixed(1)} bar'
                  : 'Waiting for live pressure readings';
            } else if (hasStaleReading) {
              title = 'Pressensor not ready — no live pressure';
              final pStr = pressure.toStringAsFixed(2);
              subtitle = paired
                  ? 'Last reading: $pStr bar (stale). Reconnect, then start the next shot.'
                  : 'Last reading: $pStr bar (stale). Pair a pressensor to continue.';
            } else if (!paired) {
              title = 'No pressensor paired';
              subtitle = 'Pair a pressensor to record pressure and auto-start';
            } else {
              title = 'Pressensor not connected';
              subtitle = 'Reconnect to start recording';
            }

            final showAction = !showReady && !linkConnecting;
            final actionLabel = paired
                ? (linkConnected ? 'Refresh' : 'Reconnect')
                : 'Pair sensor';
            final actionKey = paired
                ? const Key('idle_sensor_reconnect')
                : const Key('idle_sensor_pair');

            return Material(
              key: const Key('idle_sensor_status'),
              color: color,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, color: onColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showAction)
                      OutlinedButton(
                        key: actionKey,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: onColor,
                          side: BorderSide(
                            color: onColor.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed:
                            paired ? widget.onReconnect : widget.onPair,
                        child: Text(actionLabel),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
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