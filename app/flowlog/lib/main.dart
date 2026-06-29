import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlowlogApp());
}

class FlowlogApp extends StatefulWidget {
  const FlowlogApp({super.key, this.themeController});

  /// Optional controller for tests; created internally when omitted.
  final FlowlogThemeController? themeController;

  @override
  State<FlowlogApp> createState() => _FlowlogAppState();
}

class _FlowlogAppState extends State<FlowlogApp> {
  late final FlowlogThemeController _themeController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.themeController == null;
    _themeController =
        widget.themeController ?? FlowlogThemeController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _themeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlowlogThemeScope(
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
    );
  }
}