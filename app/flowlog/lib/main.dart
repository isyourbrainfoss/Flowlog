import 'dart:async';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/settings/appearance_settings_store.dart';
import 'package:flowlog/settings/paired_sensors_store.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
import 'package:flowlog/shell/screen_wake_lock.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlowlogApp());
}

class FlowlogApp extends StatefulWidget {
  const FlowlogApp({
    super.key,
    this.themeController,
    this.sensorHub,
    this.appearanceSettingsStore,
    this.pairedSensorsStore,
    this.autoReconnectSensors = true,
  });

  /// Optional controller for tests; created internally when omitted.
  final FlowlogThemeController? themeController;

  /// Optional sensor registry for tests; created internally when omitted.
  final SensorHub? sensorHub;

  /// Optional appearance store override for tests.
  final AppearanceSettingsStore? appearanceSettingsStore;

  /// Optional paired-sensors store override for tests.
  final PairedSensorsStore? pairedSensorsStore;

  /// When false, skips background BLE reconnect on startup (widget tests).
  final bool autoReconnectSensors;

  @override
  State<FlowlogApp> createState() => _FlowlogAppState();
}

class _FlowlogAppState extends State<FlowlogApp> with WidgetsBindingObserver {
  late final FlowlogThemeController _themeController;
  late final SensorHub _sensorHub;
  late final bool _ownsController;
  late final bool _ownsSensorHub;
  late final AppearanceSettingsStore _appearanceSettingsStore;
  late final PairedSensorsStore _pairedSensorsStore;
  final List<Timer> _autoReconnectTimers = [];
  Timer? _resumeReconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appearanceSettingsStore =
        widget.appearanceSettingsStore ?? AppearanceSettingsStore();
    _pairedSensorsStore = widget.pairedSensorsStore ?? PairedSensorsStore();
    _ownsController = widget.themeController == null;
    _themeController =
        widget.themeController ??
        FlowlogThemeController(
          onThemeModeChanged: (mode) => _appearanceSettingsStore.save(
            AppearanceSettings(themeMode: mode),
          ),
        );
    _ownsSensorHub = widget.sensorHub == null;
    _sensorHub =
        widget.sensorHub ??
        SensorHub(
          bleBackend: createBleConnectionBackend(),
          pairedSensorsStore: _pairedSensorsStore,
        );
    unawaited(_restorePersistedPreferences());
  }

  Future<void> _restorePersistedPreferences() async {
    await FlowlogStorage.shared.rootPath();

    final appearance = await _appearanceSettingsStore.load();
    if (mounted && widget.themeController == null) {
      _themeController.setThemeMode(appearance.themeMode);
    }

    if (_ownsSensorHub) {
      final records = await _pairedSensorsStore.load();
      for (final record in records) {
        _sensorHub.restoreDevice(SensorHub.entryFromRecord(record));
      }
      if (widget.autoReconnectSensors && mounted) {
        _scheduleStartupReconnects();
      }
    }
  }

  static const _startupReconnectDelays = [
    Duration(milliseconds: 600),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  void _scheduleStartupReconnects() {
    _cancelAutoReconnectTimers();
    for (final delay in _startupReconnectDelays) {
      _autoReconnectTimers.add(Timer(delay, _attemptAutoReconnect));
    }
  }

  void _cancelAutoReconnectTimers() {
    for (final timer in _autoReconnectTimers) {
      timer.cancel();
    }
    _autoReconnectTimers.clear();
  }

  void _attemptAutoReconnect() {
    if (!mounted || !widget.autoReconnectSensors) {
      return;
    }
    if (!_sensorHub.scaleRecoveryEnabled) {
      return;
    }
    unawaited(_sensorHub.reconnectPairedDevices());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    if (!widget.autoReconnectSensors) {
      return;
    }
    _resumeReconnectTimer?.cancel();
    _resumeReconnectTimer = Timer(
      const Duration(milliseconds: 400),
      _attemptAutoReconnect,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeReconnectTimer?.cancel();
    _resumeReconnectTimer = null;
    _cancelAutoReconnectTimers();
    if (_ownsController) {
      _themeController.dispose();
    }
    if (_ownsSensorHub) {
      _sensorHub.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenWakeLock(
      child: SensorHubScope(
        hub: _sensorHub,
        child: FlowlogThemeScope(
          controller: _themeController,
          child: ListenableBuilder(
            listenable: _themeController,
            builder: (context, _) {
              return MaterialApp(
                title: 'Flowlog',
                debugShowCheckedModeBanner: false,
                theme: FlowlogTheme.cafeLight,
                darkTheme: FlowlogTheme.coffeeDark,
                themeMode: _themeController.themeMode,
                home: const FlowlogShell(),
                onGenerateRoute: (settings) {
                  final builder = buildAppRoutes()[settings.name];
                  if (builder == null) {
                    return null;
                  }
                  return MaterialPageRoute<void>(
                    settings: settings,
                    builder: builder,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
