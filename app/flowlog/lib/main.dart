import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
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
  });

  /// Optional controller for tests; created internally when omitted.
  final FlowlogThemeController? themeController;

  /// Optional sensor registry for tests; created internally when omitted.
  final SensorHub? sensorHub;

  @override
  State<FlowlogApp> createState() => _FlowlogAppState();
}

class _FlowlogAppState extends State<FlowlogApp> {
  late final FlowlogThemeController _themeController;
  late final SensorHub _sensorHub;
  late final bool _ownsController;
  late final bool _ownsSensorHub;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.themeController == null;
    _themeController =
        widget.themeController ?? FlowlogThemeController();
    _ownsSensorHub = widget.sensorHub == null;
    _sensorHub = widget.sensorHub ?? SensorHub();
  }

  @override
  void dispose() {
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
    return SensorHubScope(
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
    );
  }
}