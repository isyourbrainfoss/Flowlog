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

  static AutoStartSettingsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AutoStartSettingsScope>()
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
  AutoStartArming _arming = const AutoStartArming();
  bool _starting = false;
  double? _lastPressure;
  Timer? _freshnessTimer;
  int _monitorGeneration = 0;
  bool _wasBrewing = false;
  bool _wantMonitor = false;
  bool _applyingMonitor = false;

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
      _arming = _rearmForCurrentSettings();
    }
    _syncMonitoring();
  }

  AutoStartArming _rearmForCurrentSettings() {
    final p = _lastPressure;
    if (p == null) {
      return const AutoStartArming(armed: true);
    }
    if (p >= widget.settings.startThresholdBar) {
      return const AutoStartArming(armed: false);
    }
    return const AutoStartArming(armed: true);
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
    if (brewing) {
      _arming = const AutoStartArming(armed: false);
    }
    // Only clear on brew start/stop edges. Continuous idle notifies must not
    // wipe a healthy live pressure stream.
    if (brewing != _wasBrewing) {
      _clearLivePressure();
      _wasBrewing = brewing;
    }
    _syncMonitoring();
  }

  void _onHubChanged() {
    if (!_hasPressureSource) {
      _clearLivePressure();
    }
    _syncMonitoring();
  }

  void _clearLivePressure() {
    widget.pressureBarNotifier?.value = null;
    widget.pressureLastUpdateNotifier?.value = null;
  }

  bool get _shouldMonitor {
    // Always monitor pressure for live display (reassurance that Pressensor is connected)
    // when a source is available and we can start. Auto-start logic below is gated by enabled.
    if (widget.isDemoMode) {
      return false;
    }
    return widget.controller.canStart && _hasPressureSource;
  }

  bool get _hasPressureSource {
    if (widget.hub.activeAdapterFor(SensorKind.pressensor) != null) {
      return true;
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
    // Drop aged samples so idle never shows "ready" with a leftover reading.
    _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final last = widget.pressureLastUpdateNotifier?.value;
      if (last == null) {
        return;
      }
      if (DateTime.now().difference(last) > kLivePressureFreshWindow) {
        _clearLivePressure();
      }
    });
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
      // Stop requested while connecting — tear down owned adapter.
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

    widget.pressureBarNotifier?.value = sample.pressureBar;
    widget.pressureLastUpdateNotifier?.value = DateTime.now();
    _lastPressure = sample.pressureBar;

    if (!mounted || _starting) {
      return;
    }

    // Only perform auto-start arming/trigger if the feature is enabled.
    if (!widget.settings.enabled) {
      return;
    }

    if (_arming.shouldTriggerStart(
      pressureBar: sample.pressureBar,
      settings: widget.settings,
    )) {
      _arming = const AutoStartArming(armed: false);
      unawaited(_triggerStart());
      return;
    }

    _arming = _arming.update(
      pressureBar: sample.pressureBar,
      settings: widget.settings,
    );
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