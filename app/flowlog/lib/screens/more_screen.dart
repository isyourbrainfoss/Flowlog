import 'dart:async';

import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/more/brew_defaults_screen.dart';
import 'package:flowlog/screens/more/equipment_screen.dart';
import 'package:flowlog/screens/more/brew_location_screen.dart';
import 'package:flowlog/screens/more/target_brew_screen.dart';

import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/settings/brew_location_store.dart';
import 'package:flowlog/shell/shortcuts.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final BrewLocationStore _brewLocationStore = BrewLocationStore();
  String? _brewLocation;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBrewLocation());
  }

  Future<void> _loadBrewLocation() async {
    final location = await _brewLocationStore.load();
    if (mounted) {
      setState(() => _brewLocation = location);
    }
  }

  Future<void> _openBrewLocationScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BrewLocationScreen(store: _brewLocationStore),
      ),
    );
    await _loadBrewLocation();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = FlowlogThemeScope.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          key: const Key('more_appearance_tile'),
          title: const Text('Appearance'),
          subtitle: Text(themeController.themeModeLabel),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SegmentedButton<ThemeMode>(
            key: const Key('more_theme_mode_segments'),
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
              ),
            ],
            selected: {themeController.themeMode},
            onSelectionChanged: (selected) {
              if (selected.isEmpty) {
                return;
              }
              themeController.setThemeMode(selected.first);
            },
            showSelectedIcon: false,
          ),
        ),
        ListTile(
          key: const Key('more_brew_defaults_tile'),
          leading: const Icon(Icons.tune),
          title: const Text('Brew defaults'),
          subtitle: const Text(
            'Dose, grind, Coffeejack turns & auto-start threshold',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => BrewDefaultsScreen(
                  autoStartController:
                      AutoStartSettingsScope.maybeOf(context),
                ),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('more_equipment_tile'),
          leading: const Icon(Icons.build),
          title: const Text('Equipment'),
          subtitle: const Text('Manage grinders, screens, baskets, scales & brewers + presets'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EquipmentScreen()),
            );
          },
        ),
        ListTile(
          key: const Key('more_target_brew_tile'),
          leading: const Icon(Icons.timeline),
          title: const Text('Target brew'),
          subtitle: const Text(
            'Dotted pressure line always shown on Live',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const TargetBrewScreen(),
              ),
            );
          },
        ),
        ListTile(
          key: const Key('more_brew_location_tile'),
          leading: const Icon(Icons.place_outlined),
          title: const Text('Brew location'),
          subtitle: Text(
            _brewLocation?.isNotEmpty == true
                ? _brewLocation!
                : 'Optional label for new shots',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => unawaited(_openBrewLocationScreen()),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_sync),
          title: const Text('Nextcloud sync'),
          subtitle: const Text('Auto-sync shots with your Nextcloud server'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openNextcloudSyncScreen(context),
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('Backup & restore'),
          subtitle: const Text('Export or merge shots, profiles, and beans'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openBackupScreen(context),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Export shots (CSV)'),
          subtitle: const Text('Batch CSV export and share'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openExportScreen(context),
        ),
        ListTile(
          key: const Key('more_sensors_tile'),
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