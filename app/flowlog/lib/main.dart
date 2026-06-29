import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
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
      home: const FlowlogHomePage(),
    );
  }
}

class FlowlogHomePage extends StatelessWidget {
  const FlowlogHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flowlog'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.coffee,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Coffee intelligence hub',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'core $flowlogCoreVersion · sensors $flowlogSensorsVersion · charts $flowlogChartsVersion',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}