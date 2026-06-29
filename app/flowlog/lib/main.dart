import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlowlogApp());
}

class FlowlogApp extends StatelessWidget {
  const FlowlogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flowlog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6F4E37),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
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
  }
}