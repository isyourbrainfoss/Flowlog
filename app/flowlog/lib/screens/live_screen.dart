import 'dart:async';

import 'package:flowlog/location/brew_gps.dart';
import 'package:flowlog/screens/live/annotations.dart';
import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live/delight.dart';
import 'package:flowlog/screens/live/demo_fixture.dart';
import 'package:flowlog/screens/live/feedback.dart';
import 'package:flowlog/screens/live/fullscreen_chart.dart';
import 'package:flowlog/screens/live/live_auto_stop.dart';
import 'package:flowlog/screens/live/live_brew_complete_overlay.dart';
import 'package:flowlog/screens/live/live_brew_hud.dart';
import 'package:flowlog/screens/live/live_idle_layout.dart';
import 'package:flowlog/screens/live/live_repositories.dart';
import 'package:flowlog/screens/live/live_scale_push.dart';
import 'package:flowlog/screens/live/live_sensor_actions.dart';
import 'package:flowlog/screens/live/live_shot_saver.dart';
import 'package:flowlog/screens/live/live_target_gamification.dart';
import 'package:flowlog/screens/live/live_weight_tracker.dart';
import 'package:flowlog/screens/live/live_yield_bar.dart';
import 'package:flowlog/screens/live/live_yield_warn.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flowlog/shell/active_brew_scope.dart';
import 'package:flowlog/shell/shell_breakpoints.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog/shell/shot_events.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;

export 'package:flowlog/screens/live/demo_fixture.dart'
    show kBundledDemoFixtureAsset;

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

  ShotSessionState _lastSessionState = ShotSessionState.idle;
  bool _wasBrewing = false;
  FlowlogShortcutRegistry? _shortcutRegistry;
  RepeatShotController? _repeatShotController;
  TargetBrewController? _targetBrewController;
  final ConfettiController _confettiController = ConfettiController();
  late final BrewDefaultsSettingsStore _brewDefaultsStore;
  BrewDefaultsSettings? _brewDefaults;
  late final ChartInteractionController _chartInteractionController;
  late final AutoStartSettingsController _ownedAutoStartController;
  AutoStartSettingsController? _autoStartController;
  SensorHub? _sensorHub;
  ConnectionState? _lastPressensorState;
  ActiveBrewNotifier? _activeBrewNotifier;
  ShotEventsNotifier? _shotEventsNotifier;

  late final LiveRepositories _repositories;
  late final BrewCompleteBannerController _brewCompleteBanner;
  late final LiveShotSaver _shotSaver;
  late final LiveAutoStopGuard _autoStop;
  late final LiveWeightTracker _weightTracker;
  final LiveYieldWarnTracker _yieldWarn = LiveYieldWarnTracker();

  late final ValueNotifier<double?> _livePressureNotifier;
  late final ValueNotifier<DateTime?> _livePressureLastUpdate;
  DateTime _lastSamplesUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;

    _samplesNotifier = ValueNotifier<List<ShotSample>>(const []);
    _livePressureNotifier = ValueNotifier<double?>(null);
    _livePressureLastUpdate = ValueNotifier<DateTime?>(null);
    _weightTracker = LiveWeightTracker(
      resolveHub: () => _sensorHub ?? SensorHubScope.maybeOf(context),
      resolveSource: () => _sensorSource,
      resolveController: () => _controller,
    );
    _autoStop = LiveAutoStopGuard(
      onAutoStop: () {
        if (mounted &&
            _controller != null &&
            _controller!.sessionState == ShotSessionState.recording) {
          _controller!.stop();
        }
      },
    );
    _annotationController = ShotAnnotationController();
    _annotationsNotifier = ValueNotifier<List<ShotAnnotation>>(
      List<ShotAnnotation>.from(_annotationController.annotations),
    );
    _annotationController.addListener(_syncAnnotations);
    _chartInteractionController = ChartInteractionController();
    _ownedAutoStartController = AutoStartSettingsController();
    unawaited(_ownedAutoStartController.load());
    _brewDefaultsStore = BrewDefaultsSettingsStore();
    unawaited(
      _brewDefaultsStore.load().then((d) {
        _brewDefaults = d;
        if (mounted) setState(() {});
      }),
    );

    _repositories = LiveRepositories(
      shotOverride: () => widget.shotRepository,
      beanOverride: () => widget.beanRepository,
      profileOverride: () => widget.profileRepository,
    );
    _brewCompleteBanner = BrewCompleteBannerController()..addListener(_rebuild);
    _shotSaver = LiveShotSaver(
      repositories: _repositories,
      brewLocationStore: widget.brewLocationStore ?? BrewLocationStore(),
      brewGpsCapture: widget.brewGpsCapture ?? const BrewGpsCapture(),
      banner: _brewCompleteBanner,
      confettiController: _confettiController,
      resolveController: () => _controller,
      resolveInitialMetadata: () => _repeatShotController?.prefill?.metadata,
      resolveAnnotations: () => _annotationController.annotations,
      resolveTargetPressureSamples: _chartTargetPressureSamples,
      resolveIdGenerator: () => widget.shotIdGenerator,
      resolveOnShotSaved: () => widget.onShotSaved,
      resolveShotEvents: () => _shotEventsNotifier,
      onStateChanged: _rebuild,
    );

    if (widget.controller != null) {
      _sensorSource = widget.sensorSource;
      _bindController(widget.controller!);
      _controllerReady = true;
    }
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
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

    // Snackbars during a pull hitch the brew UI and sit on the stop control.
    if (_controller?.isBrewing ?? false) {
      return;
    }

    if (previous != null &&
        previous != ConnectionState.connected &&
        current == ConnectionState.connected &&
        mounted) {
      showPressensorConnectedSnackBar(
        context,
        autoStartThresholdBar:
            _resolvedAutoStartController.settings.startThresholdBar,
        batteryPercent: hub.pressensorBatteryPercent,
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
    _shotSaver.resetForNewSession();
    _syncSamples();
  }

  void _ensureProductionController() {
    final hub = SensorHubScope.of(context);
    _sensorSource =
        widget.sensorSource ??
        LiveSensorSource(
          hub: hub,
          demoFixturePath: resolveDemoFixtureFilePath(),
          demoFixtureLoader: loadBundledDemoFixture,
          pressureAdapterFactory: widget.pressureAdapterFactory,
          weightAdapterFactory: widget.weightAdapterFactory,
        );

    _bindController(
      LiveShotController(
        sampleAdapter: SessionSensorAdapter(
          resolve: _sensorSource!.resolveSampleAdapter,
        ),
        onTare: _sensorSource!.onTare,
        onPhoneBrewStart: _sensorSource!.onPhoneBrewStart,
        onPhoneBrewEnd: _sensorSource!.onPhoneBrewEnd,
        onForwardPressure: _sensorSource!.forwardPressure,
        onPushScaleConfig: _pushScaleConfigToDevice,
      ),
    );
  }

  Future<void> _pushScaleConfigToDevice() async {
    final source = _sensorSource;
    if (source == null) {
      return;
    }
    await pushLiveScaleDisplayConfig(source, brewDefaults: _brewDefaults);
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
    _autoStartController =
        widget.autoStartController ?? AutoStartSettingsScope.maybeOf(context);

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
    _livePressureNotifier.dispose();
    _livePressureLastUpdate.dispose();
    _weightTracker.dispose();
    _autoStop.dispose();
    _brewCompleteBanner
      ..removeListener(_rebuild)
      ..dispose();
    _sensorHub?.setScaleRecoveryEnabled(true);
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

    // Full samples list to chart at ~20 fps to reduce copy/GC lag.
    // Individual pressure value updates at full sensor rate (see _livePressureNotifier).
    final now = DateTime.now();
    if (now.difference(_lastSamplesUpdate).inMilliseconds >= 50) {
      _samplesNotifier.value = List<ShotSample>.from(controller.samples);
      _lastSamplesUpdate = now;
    }

    _weightTracker.track(controller);
    _autoStop.check(controller);
    _maybeFireYieldWarn(controller);
  }

  void _maybeFireYieldWarn(LiveShotController controller) {
    final fire = _yieldWarn.check(
      controller,
      defaults: _brewDefaults,
      fallbackWeightG: _weightTracker.weight.value,
    );
    if (!fire) {
      return;
    }
    unawaited(playYieldWarnCue());
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onRearmWeightPressed() async {
    await _sensorSource?.rearmWeightStream();
    if (!mounted || (_controller?.isBrewing ?? false)) {
      return;
    }
    showWeightRearmSnackBar(context);
  }

  void _syncAnnotations() {
    _annotationsNotifier.value = List<ShotAnnotation>.from(
      _annotationController.annotations,
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

  Future<void> _onReconnectSensors() async {
    if (_controller?.isBrewing ?? false) {
      return;
    }
    // Clear leftover post-shot readings so the status banner does not keep
    // showing a stale "last" value while reconnect is in progress.
    _livePressureNotifier.value = null;
    _livePressureLastUpdate.value = null;
    _weightTracker.clear();

    final hub = SensorHubScope.maybeOf(context);
    if (hub == null) {
      return;
    }

    await reconnectSensorsWithFeedback(context, hub);
  }

  void _onPairSensors() => openPairSensorsScreen(context);

  void _onSessionLifecycle() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final brewing = controller.isBrewing;
    _activeBrewNotifier?.setBrewing(brewing);
    if (brewing && _brewCompleteBanner.isVisible) {
      _brewCompleteBanner.dismiss();
    }
    // Trigger auto-save on stop transition (covers both manual stop and auto-stop).
    if (_wasBrewing &&
        !brewing &&
        controller.canSaveShot &&
        !_shotSaver.savedCurrent) {
      unawaited(_shotSaver.autoSaveStoppedSession(context));
    }
    // Also catch stopped state directly (helps auto-stop timer path reliability)
    if (controller.sessionState == ShotSessionState.stopped &&
        controller.canSaveShot &&
        !_shotSaver.savedCurrent) {
      unawaited(_shotSaver.autoSaveStoppedSession(context));
    }
    if (brewing && !_wasBrewing) {
      _shotSaver.resetForNewSession();
      _yieldWarn.reset();
      _weightTracker.resetForNewBrew();
      _sensorHub?.setScaleRecoveryEnabled(false);
      // Re-enable live follow for the new pull.
      _chartInteractionController.resetViewport();
      // Reload brew defaults so yield target/warn edits apply to this shot.
      unawaited(
        _brewDefaultsStore.load().then((d) {
          if (mounted) setState(() => _brewDefaults = d);
        }),
      );
    }
    if (!brewing && _wasBrewing) {
      _sensorHub?.setScaleRecoveryEnabled(true);
      // Show the whole pull after stop (not the live last-~30s window).
      _chartInteractionController.fitFullShot();
      // In-brew "wind back" cue is stale once recording ends, and it sits
      // on top of Repeat / save actions on a phone-sized screen.
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      }
    }
    _wasBrewing = brewing;
  }

  List<ShotSample> _chartTargetPressureSamples() {
    final repeatSamples = _repeatShotController?.prefill?.targetPressureSamples;
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

    final profileRepository = await _repositories.profiles();
    if (!mounted) {
      return;
    }

    await startRepeatShotFromShot(
      context: context,
      shot: shot,
      profileRepository: profileRepository,
      repeatController: _repeatShotController ?? widget.repeatShotController,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(primary: false, body: SizedBox.shrink());
    }

    final listenables = <Listenable>[controller];
    if (_repeatShotController != null) {
      listenables.add(_repeatShotController!);
    }
    if (_targetBrewController != null) {
      listenables.add(_targetBrewController!);
    }
    listenables.add(_resolvedAutoStartController);
    // Do not merge SensorHub here. BLE connect / reconnect notifies several
    // times a second and was rebuilding the whole brew tree (and fighting
    // any snackbar overlay). Idle chrome listens to the hub locally.

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final state = controller.sessionState;
        final samples = controller.samples;
        final demoModeActive = _sensorSource?.isDemoMode ?? false;
        final latestSample = samples.isEmpty ? null : samples.last;
        final chartTargetSamples = _chartTargetPressureSamples();
        final autoStartSettings = _resolvedAutoStartController.settings;
        final gamification = LiveTargetGamificationStats.forSession(
          state: state,
          samples: samples,
          targets: chartTargetSamples,
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
                final isBrewing = controller.isBrewing;
                final targetYield =
                    _brewDefaults?.targetYieldG ?? kDefaultTargetYieldG;
                final warnAt =
                    _brewDefaults?.effectiveYieldWarnAtG ??
                    kDefaultYieldWarnAtG;
                final targetP = latestSample == null
                    ? null
                    : _targetPressureAtElapsed(latestSample.elapsedMs);
                final liveWeightG = _weightTracker.weight.value;
                void onRearmWeight() => unawaited(_onRearmWeightPressed());

                final Widget body;
                if (isBrewing) {
                  body = LiveBrewHud(
                    controller: controller,
                    samples: samples,
                    latestSample: latestSample,
                    fallbackChartHeight: chartHeight,
                    samplesNotifier: _samplesNotifier,
                    annotationsNotifier: _annotationsNotifier,
                    interactionController: _chartInteractionController,
                    targetPressureSamples: chartTargetSamples,
                    liveWeightG: liveWeightG,
                    targetYieldG: targetYield,
                    warnAtG: warnAt,
                    showYieldWarnBanner: _yieldWarn.fired,
                    weightHealth: _weightTracker.health(isBrewing: true),
                    targetPressure: targetP,
                    onRearmWeight: onRearmWeight,
                  );
                } else {
                  final showSensorStatus =
                      state == ShotSessionState.idle ||
                      state == ShotSessionState.stopped;
                  final showStoppedBars =
                      state == ShotSessionState.stopped && latestSample != null;
                  body = LiveIdleLayout(
                    pinChart:
                        constraints.maxHeight.isFinite &&
                        constraints.maxHeight >= 360,
                    useCompactLayout: useCompactLayout,
                    chartSection: LiveIdleChartSection(
                      horizontalPadding: horizontalPadding,
                      demoModeActive: demoModeActive,
                      onDismissDemoMode: _onDismissDemoMode,
                      repeatController: _repeatShotController,
                      sensorStatus: showSensorStatus
                          ? LiveIdleSensorStatus(
                              hub: _sensorHub,
                              autoStartController: _resolvedAutoStartController,
                              pressureBarNotifier: _livePressureNotifier,
                              lastUpdateNotifier: _livePressureLastUpdate,
                              onReconnect: _onReconnectSensors,
                              onPair: _onPairSensors,
                            )
                          : null,
                      chartHeight: chartHeight,
                      samplesNotifier: _samplesNotifier,
                      annotationsNotifier: _annotationsNotifier,
                      interactionController: _chartInteractionController,
                      targetPressureSamples: chartTargetSamples,
                      onOpenFullscreenChart: _onOpenFullscreenChart,
                    ),
                    controlsSection: LiveIdleControlsSection(
                      controller: controller,
                      horizontalPadding: horizontalPadding,
                      useCompactLayout: useCompactLayout,
                      latestSample: latestSample,
                      liveWeightG: liveWeightG,
                      targetYieldG: targetYield,
                      warnAtG: warnAt,
                      // Stopped => not brewing; only computed when shown.
                      weightHealth: showStoppedBars
                          ? _weightTracker.health(isBrewing: false)
                          : null,
                      onRearmWeight: onRearmWeight,
                      targetPressure: targetP,
                      hasTargetCurve: chartTargetSamples.isNotEmpty,
                      gamification: gamification,
                      showSaveButton: !_shotSaver.savedCurrent,
                      onRepeatShot: () => unawaited(_onRepeatShotPressed()),
                      onSaveShot: () =>
                          unawaited(_shotSaver.saveCurrentSession(context)),
                    ),
                  );
                }

                final summary = _brewCompleteBanner.summary;
                final lastSavedId = _shotSaver.lastSavedShotId;
                final brewBanner = !isBrewing && summary != null
                    ? LiveBrewCompleteOverlay(
                        summary: summary,
                        onDismiss: _brewCompleteBanner.dismiss,
                        onEdit: lastSavedId != null
                            ? () => unawaited(
                                _shotSaver.editLastSavedShot(context),
                              )
                            : null,
                        onDiscard: lastSavedId != null
                            ? () => unawaited(
                                _shotSaver.discardAutoSavedShotById(
                                  context,
                                  lastSavedId,
                                ),
                              )
                            : null,
                      )
                    : null;

                return Scaffold(
                  primary: false,
                  // During brew the stop control is embedded in the HUD so
                  // the shell can go fully immersive (no bottom tab bar).
                  bottomNavigationBar: isBrewing
                      ? null
                      : SafeArea(
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
                  // Stack the post-brew banner above Live content so it does
                  // not scroll under the chart or fight shell chrome.
                  body: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      body,
                      if (brewBanner != null)
                        Positioned(
                          left: horizontalPadding,
                          right: horizontalPadding,
                          top: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: brewBanner,
                            ),
                          ),
                        ),
                    ],
                  ),
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
