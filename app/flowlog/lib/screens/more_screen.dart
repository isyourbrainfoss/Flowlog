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
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Settings & sensors'),
          ),
        ),
      ],
    );
  }
}