import 'package:flowlog/screens/more/sensors_screen.dart';
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
          leading: const Icon(Icons.sensors),
          title: const Text('Sensors'),
          subtitle: const Text('Paired pressure & scale devices'),
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
      ],
    );
  }
}