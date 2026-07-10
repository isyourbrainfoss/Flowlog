import 'dart:async';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/settings/auto_start_settings_store.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/material.dart' hide ConnectionState;

/// Default pressure (bar) that triggers an automatic brew start.
const double kDefaultAutoStartPressureBar = 1.0;

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
    super.key,
  });

  final LiveShotController controller;
  final SensorHub hub;
  final LiveSensorSource? sensorSource;
  final AutoStartSettings settings;
  final bool isDemoMode;

  /// Updated with the latest live pressensor reading while monitoring.
  final ValueNotifier<double?>? pressureBarNotifier;
  final Widget child;

  @override
  State<LiveAutoStartListener> createState() => _LiveAutoStartListenerState();
}

class _LiveAutoStartListenerState extends State<LiveAutoStartListener> {
  StreamSubscription<SensorSample>? _pressureSub;
  SensorAdapter? _ownedMonitorAdapter;
  AutoStartArming _arming = const AutoStartArming();
  bool _starting = false;

  @override
  void initState() {
    super.initState();
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
    _syncMonitoring();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.hub.removeListener(_onHubChanged);
    unawaited(_stopMonitoring());
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.isBrewing) {
      _arming = const AutoStartArming(armed: false);
    }
    _syncMonitoring();
  }

  void _onHubChanged() {
    _syncMonitoring();
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
    if (_shouldMonitor) {
      unawaited(_startMonitoring());
      return;
    }
    unawaited(_stopMonitoring());
  }

  Future<void> _startMonitoring() async {
    if (_pressureSub != null) {
      return;
    }

    final hubAdapter = widget.hub.activeAdapterFor(SensorKind.pressensor);
    if (hubAdapter != null) {
      _pressureSub = hubAdapter.samples.listen(_onPressureSample);
      return;
    }

    final source = widget.sensorSource;
    if (source == null || !source.hasConnectedSensors) {
      await _stopMonitoring();
      return;
    }

    final adapter = source.resolveSampleAdapter();
    if (adapter is IdleSensorAdapter) {
      await _stopMonitoring();
      return;
    }

    _ownedMonitorAdapter = adapter;
    await adapter.connect();
    _pressureSub = adapter.samples.listen(_onPressureSample);
  }

  Future<void> _stopMonitoring() async {
    await _pressureSub?.cancel();
    _pressureSub = null;
    widget.pressureBarNotifier?.value = null;

    final owned = _ownedMonitorAdapter;
    _ownedMonitorAdapter = null;
    if (owned == null) {
      return;
    }

    await owned.disconnect();
    if (owned is MergedSampleStreamAdapter) {
      await owned.dispose();
    }
  }

  void _onPressureSample(SensorSample sample) {
    widget.pressureBarNotifier?.value = sample.pressureBar;

    if (!mounted || _starting || !widget.controller.canStart) {
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
    super.key,
  });

  final double thresholdBar;
  final ValueNotifier<double?>? pressureBarNotifier;

  @override
  Widget build(BuildContext context) {
    final pressureWidget = pressureBarNotifier == null
        ? const SizedBox.shrink()
        : ValueListenableBuilder<double?>(
            valueListenable: pressureBarNotifier!,
            builder: (context, pressureBar, _) {
              return LivePressureReadout(pressureBar: pressureBar);
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
class LivePressureReadout extends StatelessWidget {
  const LivePressureReadout({
    required this.pressureBar,
    super.key,
  });

  final double? pressureBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = pressureBar;
    final label = value == null ? '—' : value.toStringAsFixed(2);

    return Semantics(
      label: value == null
          ? 'Live pressure unavailable'
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
            ),
          ),
          Text(
            'bar',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}