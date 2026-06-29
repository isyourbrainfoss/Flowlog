import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = FlowlogThemeScope.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          title: const Text('Appearance'),
          subtitle: Text(
            themeController.isDark ? 'Coffee dark' : 'Café light',
          ),
          trailing: Switch(
            value: themeController.isDark,
            onChanged: (isDark) {
              themeController.setThemeMode(
                isDark ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Export shots'),
          subtitle: const Text('Batch CSV export and share'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openExportScreen(context),
        ),
        ListTile(
          leading: const Icon(Icons.sensors),
          title: const Text('Sensors'),
          subtitle: const Text('Pair Pressensor and scale'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Sensors')),
                  body: const SensorsScreen(),
                ),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('more_diagnostics_tile'),
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Sensor diagnostics'),
          subtitle: const Text('RSSI, reconnect log, last error'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openSensorDiagnosticsScreen(context),
        ),
      ],
    );
  }
}