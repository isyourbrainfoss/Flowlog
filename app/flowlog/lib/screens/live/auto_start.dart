import 'dart:async';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/settings/auto_start_settings_store.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart' hide ConnectionState;

/// Default pressure (bar) that triggers an automatic brew start.
const double kDefaultAutoStartPressureBar = 0.5;

/// Minimum allowed auto-start threshold (bar).
const double kMinAutoStartPressureBar = 0.1;

/// Maximum allowed auto-start threshold (bar).
const double kMaxAutoStartPressureBar = 2.5;

/// Pressure must fall below this fraction of [startThresholdBar] to re-arm.
const double kAutoStartReleaseFraction = 0.5;

/// Settings for pressure-triggered auto brew start on the Live tab.
class AutoStartSettings {
  const AutoStartSettings({
    this.enabled = true,
    this.startThresholdBar = kDefaultAutoStartPressureBar,
    this.releaseFraction = kAutoStartReleaseFraction,
  });

  final bool enabled;
  final double startThresholdBar;
  final double releaseFraction;

  double get releaseThresholdBar => startThresholdBar * releaseFraction;

  AutoStartSettings copyWith({
    bool? enabled,
    double? startThresholdBar,
    double? releaseFraction,
  }) {
    return AutoStartSettings(
      enabled: enabled ?? this.enabled,
      startThresholdBar: startThresholdBar ?? this.startThresholdBar,
      releaseFraction: releaseFraction ?? this.releaseFraction,
    );
  }
}

/// File-backed auto-start preferences shared by Live and Brew defaults.
class AutoStartSettingsController extends ChangeNotifier {
  AutoStartSettingsController({
    AutoStartSettingsStore? settingsStore,
  }) : _settingsStore = settingsStore ?? AutoStartSettingsStore();

  final AutoStartSettingsStore _settingsStore;
  AutoStartSettings _settings = const AutoStartSettings();

  AutoStartSettings get settings => _settings;

  Future<void> load() async {
    _settings = await _settingsStore.load();
    notifyListeners();
  }

  Future<void> updateSettings(AutoStartSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _settingsStore.save(settings);
  }

  Future<void> setEnabled(bool enabled) {
    return updateSettings(_settings.copyWith(enabled: enabled));
  }

  Future<void> setThresholdBar(double thresholdBar) {
    return updateSettings(_settings.copyWith(startThresholdBar: thresholdBar));
  }
}

/// Provides [AutoStartSettingsController] to the widget tree.
class AutoStartSettingsScope
    extends InheritedNotifier<AutoStartSettingsController> {
  const AutoStartSettingsScope({
    required AutoStartSettingsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Watches the scope (rebuilds when settings change). Prefer for widgets
  /// that display live threshold / enabled state.
  static AutoStartSettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AutoStartSettingsScope>()
        ?.notifier;
  }

  /// One-shot lookup without registering a dependency (e.g. before a push).
  static AutoStartSettingsController? maybeOfStatic(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<AutoStartSettingsScope>()
        ?.notifier;
  }
}

/// Tracks hysteresis so auto-start only fires once per pressure rise.
class AutoStartArming {
  const AutoStartArming({this.armed = true});

  final bool armed;

  AutoStartArming update({
    required double? pressureBar,
    required AutoStartSettings settings,
  }) {
    final pressure = pressureBar;
    if (pressure == null) {
      return this;
    }

    if (!armed && pressure <= settings.releaseThresholdBar) {
      return const AutoStartArming(armed: true);
    }

    if (armed && pressure >= settings.startThresholdBar) {
      return const AutoStartArming(armed: false);
    }

    return this;
  }

  bool shouldTriggerStart({
    required double? pressureBar,
    required AutoStartSettings settings,
  }) {
    final pressure = pressureBar;
    if (pressure == null || !armed) {
      return false;
    }
    return pressure >= settings.startThresholdBar;
  }
}

/// Starts a brew when live pressensor pressure crosses [AutoStartSettings].
class LiveAutoStartListener extends StatefulWidget {
  const LiveAutoStartListener({
    required this.controller,
    required this.hub,
    required this.child,
    this.sensorSource,
    this.settings = const AutoStartSettings(),
    this.isDemoMode = false,
    this.pressureBarNotifier,
    this.pressureLastUpdateNotifier,
    super.key,
  });

  final LiveShotController controller;
  final SensorHub hub;
  final LiveSensorSource? sensorSource;
  final AutoStartSettings settings;
  final bool isDemoMode;

  /// Updated with the latest live pressensor reading while monitoring.
  final ValueNotifier<double?>? pressureBarNotifier;

  /// Updated with the timestamp of the last pressure reading (for staleness indication).
  final ValueNotifier<DateTime?>? pressureLastUpdateNotifier;
  final Widget child;

  @override
  State<LiveAutoStartListener> createState() => _LiveAutoStartListenerState();
}

/// How long a monitored pressure sample stays valid before idle UI treats the
/// pressensor as disconnected (and we drop the leftover value).
const Duration kLivePressureFreshWindow = Duration(seconds: 3);

class _LiveAutoStartListenerState extends State<LiveAutoStartListener> {
  StreamSubscription<SensorSample>? _pressureSub;
  SensorAdapter? _ownedMonitorAdapter;
  /// Armed only after pressure has been at/below the release level, then fires
  /// on the next rise through the start threshold (classic hysteresis).
  AutoStartArming _arming = const AutoStartArming(armed: false);
  bool _starting = false;
  double? _lastPressure;
  Timer? _freshnessTimer;
  int _monitorGeneration = 0;
  bool _wasBrewing = false;
  bool _wantMonitor = false;
  bool _applyingMonitor = false;
  DateTime? _monitorStartedAt;
  DateTime? _lastResubscribeAt;

  @override
  void initState() {
    super.initState();
    _wasBrewing = widget.controller.isBrewing;
    widget.controller.addListener(_onControllerChanged);
    widget.hub.addListener(_onHubChanged);
    _syncMonitoring();
  }

  @override
  void didUpdateWidget(covariant LiveAutoStartListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.hub != widget.hub) {
      oldWidget.hub.removeListener(_onHubChanged);
      widget.hub.addListener(_onHubChanged);
    }
    final settingsChanged =
        oldWidget.settings.startThresholdBar != widget.settings.startThresholdBar ||
        oldWidget.settings.enabled != widget.settings.enabled;
    if (settingsChanged) {
      _arming = _armingForCurrentPressure();
    }
    _syncMonitoring();
  }

  AutoStartArming _armingForCurrentPressure() {
    final p = _lastPressure;
    if (p == null) {
      return const AutoStartArming(armed: false);
    }
    if (p <= widget.settings.releaseThresholdBar) {
      return const AutoStartArming(armed: true);
    }
    return const AutoStartArming(armed: false);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.hub.removeListener(_onHubChanged);
    _wantMonitor = false;
    _freshnessTimer?.cancel();
    unawaited(_stopMonitoringBody());
    super.dispose();
  }

  void _onControllerChanged() {
    final brewing = widget.controller.isBrewing;
    if (brewing != _wasBrewing) {
      if (brewing) {
        _arming = const AutoStartArming(armed: false);
      } else {
        // Shot ended: wait for a low pressure sample before re-arming so a
        // stuck high residual cannot fire immediately.
        _lastPressure = null;
        _arming = const AutoStartArming(armed: false);
        // If start/stop left the session unusable, recover so Start works.
        unawaited(widget.controller.recoverIfStuck());
      }
      _clearLivePressure();
      _wasBrewing = brewing;
    }
    _syncMonitoring();
  }

  void _onHubChanged() {
    if (!_hasPressureSource) {
      _clearLivePressure();
      _lastPressure = null;
    }
    _syncMonitoring();
  }

  void _clearLivePressure() {
    widget.pressureBarNotifier?.value = null;
    widget.pressureLastUpdateNotifier?.value = null;
  }

  bool get _shouldMonitor {
    // Always monitor pressure for live display when a source is available and
    // we can start. Auto-start logic below is gated by enabled.
    if (widget.isDemoMode) {
      return false;
    }
    return widget.controller.canStart && _hasPressureSource;
  }

  bool get _hasPressureSource {
    if (widget.hub.activeAdapterFor(SensorKind.pressensor) != null) {
      return true;
    }

    // Paired pressensor still linking via hub — wait for the hub adapter.
    // Opening a second BLE client steals notifications from the hub link.
    if (widget.hub.hasKind(SensorKind.pressensor) &&
        widget.hub.pressensorState != ConnectionState.connected) {
      return false;
    }

    final source = widget.sensorSource;
    if (source == null || !source.hasConnectedSensors) {
      return false;
    }

    return source.resolveSampleAdapter() is! IdleSensorAdapter;
  }

  void _syncMonitoring() {
    _wantMonitor = _shouldMonitor;
    unawaited(_applyMonitoring());
  }

  /// Serializes start/stop so a brew end cannot race a pending stop and leave
  /// monitoring permanently off (or keep a leftover sample as "ready").
  Future<void> _applyMonitoring() async {
    if (_applyingMonitor) {
      return;
    }
    _applyingMonitor = true;
    try {
      while (mounted) {
        final want = _wantMonitor;
        final active = _pressureSub != null || _ownedMonitorAdapter != null;
        if (want && !active) {
          await _startMonitoringBody();
        } else if (!want && active) {
          await _stopMonitoringBody();
        } else if (!want && !active) {
          _clearLivePressure();
          _cancelFreshnessTimer();
          break;
        } else {
          break;
        }
      }
    } finally {
      _applyingMonitor = false;
    }
    // A brew start/stop may flip _wantMonitor while we were mid-connect.
    if (!mounted) {
      return;
    }
    final want = _wantMonitor;
    final active = _pressureSub != null || _ownedMonitorAdapter != null;
    if ((want && !active) || (!want && active)) {
      unawaited(_applyMonitoring());
    }
  }

  void _ensureFreshnessTimer() {
    if (_freshnessTimer != null) {
      return;
    }
    _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_wantMonitor || !mounted) {
        return;
      }
      // Skip work while Live tab is offstage (History etc.) to reduce jank.
      if (!TickerMode.valuesOf(context).enabled) {
        return;
      }
      final now = DateTime.now();
      final last = widget.pressureLastUpdateNotifier?.value;
      final hubConnected =
          widget.hub.activeAdapterFor(SensorKind.pressensor) != null;

      // Clear aged UI readings (does not touch arming).
      if (last != null && now.difference(last) > kLivePressureFreshWindow) {
        _clearLivePressure();
      }

      // Resubscribe only when the stream has gone quiet while BLE is up —
      // rate-limited so a rising shot is not interrupted every second.
      final quietSinceStart = last == null &&
          _monitorStartedAt != null &&
          now.difference(_monitorStartedAt!) > const Duration(seconds: 4);
      final quietAfterSamples = last != null &&
          now.difference(last) > const Duration(seconds: 5);
      final canResubscribe = _lastResubscribeAt == null ||
          now.difference(_lastResubscribeAt!) > const Duration(seconds: 6);

      if (hubConnected &&
          canResubscribe &&
          (quietSinceStart || quietAfterSamples)) {
        unawaited(_resubscribeMonitoring());
      }
    });
  }

  Future<void> _resubscribeMonitoring() async {
    if (!_wantMonitor || _applyingMonitor) {
      return;
    }
    _lastResubscribeAt = DateTime.now();
    await _stopMonitoringBody();
    if (_wantMonitor && mounted) {
      await _startMonitoringBody();
    }
  }

  void _cancelFreshnessTimer() {
    _freshnessTimer?.cancel();
    _freshnessTimer = null;
  }

  Future<void> _startMonitoringBody() async {
    if (_pressureSub != null) {
      return;
    }

    final generation = ++_monitorGeneration;
    // Fresh slate: ready only after a sample arrives on this monitor session.
    _clearLivePressure();
    _monitorStartedAt = DateTime.now();
    _ensureFreshnessTimer();

    final hubAdapter = widget.hub.activeAdapterFor(SensorKind.pressensor);
    if (hubAdapter != null) {
      if (!_wantMonitor || generation != _monitorGeneration) {
        return;
      }
      _pressureSub = hubAdapter.samples.listen(
        (sample) => _onPressureSample(sample, generation),
        onDone: () => _onMonitorStreamEnded(generation),
        onError: (_) => _onMonitorStreamEnded(generation),
      );
      return;
    }

    // Prefer hub adapter only. If the hub reports connected but has no active
    // adapter (tests / rare race), fall through to sensorSource factories.
    if (widget.hub.hasKind(SensorKind.pressensor) &&
        widget.hub.pressensorState != ConnectionState.connected) {
      return;
    }

    final source = widget.sensorSource;
    if (source == null || !source.hasConnectedSensors) {
      return;
    }
    final adapter = source.resolveSampleAdapter();
    if (adapter is IdleSensorAdapter) {
      return;
    }

    _ownedMonitorAdapter = adapter;
    await adapter.connect();
    if (!_wantMonitor || generation != _monitorGeneration) {
      _ownedMonitorAdapter = null;
      await adapter.disconnect();
      if (adapter is MergedSampleStreamAdapter) {
        await adapter.dispose();
      }
      return;
    }
    _pressureSub = adapter.samples.listen(
      (sample) => _onPressureSample(sample, generation),
      onDone: () => _onMonitorStreamEnded(generation),
      onError: (_) => _onMonitorStreamEnded(generation),
    );
  }

  void _onMonitorStreamEnded(int generation) {
    if (generation != _monitorGeneration) {
      return;
    }
    _pressureSub = null;
    _clearLivePressure();
    _syncMonitoring();
  }

  Future<void> _stopMonitoringBody() async {
    _monitorGeneration++;
    _cancelFreshnessTimer();
    await _pressureSub?.cancel();
    _pressureSub = null;
    _clearLivePressure();
    _monitorStartedAt = null;

    final owned = _ownedMonitorAdapter;
    _ownedMonitorAdapter = null;
    if (owned != null) {
      await owned.disconnect();
      if (owned is MergedSampleStreamAdapter) {
        await owned.dispose();
      }
    }
  }

  void _onPressureSample(SensorSample sample, int generation) {
    if (generation != _monitorGeneration) {
      return;
    }
    // Never update idle pressure while a brew is active (session owns the stream).
    if (widget.controller.isBrewing || !widget.controller.canStart) {
      return;
    }

    final current = sample.pressureBar;

    widget.pressureBarNotifier?.value = current;
    widget.pressureLastUpdateNotifier?.value = DateTime.now();
    _lastPressure = current;

    if (!mounted || _starting) {
      return;
    }

    if (!widget.settings.enabled) {
      return;
    }

    final release = widget.settings.releaseThresholdBar;

    // Classic hysteresis: arm only after a low, fire on next high.
    // After a brew that ends near 0.0 bar, the next samples re-arm, then a
    // pump-up through the threshold starts the shot.
    if (current != null && current <= release) {
      _arming = const AutoStartArming(armed: true);
    }

    if (_arming.shouldTriggerStart(
      pressureBar: current,
      settings: widget.settings,
    )) {
      _arming = const AutoStartArming(armed: false);
      unawaited(_triggerStart());
    }
  }

  Future<void> _triggerStart() async {
    if (_starting) {
      return;
    }

    _starting = true;
    try {
      await widget.controller.start(
        autoStartPressureBar: widget.settings.startThresholdBar,
      );
    } on Object {
      // Recover so a failed auto-start does not brick manual Start either.
      await widget.controller.recoverIfStuck();
      // Re-arm only after another low reading.
      _arming = const AutoStartArming(armed: false);
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Expandable threshold control shown below [AutoStartArmedBanner].
class AutoStartThresholdPanel extends StatelessWidget {
  const AutoStartThresholdPanel({
    required this.thresholdBar,
    required this.onThresholdChanged,
    super.key,
  });

  final double thresholdBar;
  final ValueChanged<double> onThresholdChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          'Auto-start threshold',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text('${thresholdBar.toStringAsFixed(1)} bar'),
        children: [
          Slider(
            key: const Key('auto_start_threshold_slider'),
            value: thresholdBar.clamp(kMinAutoStartPressureBar, kMaxAutoStartPressureBar),
            min: kMinAutoStartPressureBar,
            max: kMaxAutoStartPressureBar,
            divisions: 24,
            label: '${thresholdBar.toStringAsFixed(1)} bar',
            onChanged: onThresholdChanged,
          ),
        ],
      ),
    );
  }
}

/// Banner shown when auto-start is monitoring pressure while idle.
class AutoStartArmedBanner extends StatelessWidget {
  const AutoStartArmedBanner({
    required this.thresholdBar,
    this.pressureBarNotifier,
    this.lastUpdateNotifier,
    super.key,
  });

  final double thresholdBar;
  final ValueNotifier<double?>? pressureBarNotifier;
  final ValueNotifier<DateTime?>? lastUpdateNotifier;

  @override
  Widget build(BuildContext context) {
    final pressureWidget = pressureBarNotifier == null
        ? const SizedBox.shrink()
        : ValueListenableBuilder<double?>(
            valueListenable: pressureBarNotifier!,
            builder: (context, pressureBar, _) {
              return ValueListenableBuilder<DateTime?>(
                valueListenable: lastUpdateNotifier ?? ValueNotifier<DateTime?>(null),
                builder: (context, lastUpdate, _) {
                  return LivePressureReadout(
                    pressureBar: pressureBar,
                    lastUpdated: lastUpdate,
                  );
                },
              );
            },
          );

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.sensors, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Auto-start armed — brew begins at '
                '${thresholdBar.toStringAsFixed(1)} bar',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            pressureWidget,
          ],
        ),
      ),
    );
  }
}

/// Live pressensor reading shown before a brew starts.
/// If [lastUpdated] is old, renders with muted styling to indicate a stale reading.
class LivePressureReadout extends StatefulWidget {
  const LivePressureReadout({
    required this.pressureBar,
    this.lastUpdated,
    super.key,
  });

  final double? pressureBar;
  final DateTime? lastUpdated;

  @override
  State<LivePressureReadout> createState() => _LivePressureReadoutState();
}

class _LivePressureReadoutState extends State<LivePressureReadout> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool get _isStale {
    final t = widget.lastUpdated;
    if (t == null) return false;
    return DateTime.now().difference(t) > kLivePressureFreshWindow;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.pressureBar;
    final label = value == null ? '—' : value.toStringAsFixed(2);
    final isStale = _isStale;
    final valueColor = isStale
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : theme.colorScheme.onSurface;

    return Semantics(
      label: value == null
          ? 'Live pressure unavailable'
          : isStale
              ? 'Live pressure $label bar (stale)'
              : 'Live pressure $label bar',
      readOnly: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            key: const Key('live_pressure_readout'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'bar',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isStale) ...[
                const SizedBox(width: 4),
                Text(
                  '(stale)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 9,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}