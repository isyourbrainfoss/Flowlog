import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/brew_metadata_sliders.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flutter/material.dart';

/// Edits default metadata and Coffeejack lever settings for new brews.
class BrewDefaultsScreen extends StatefulWidget {
  const BrewDefaultsScreen({
    super.key,
    this.brewDefaultsStore,
    this.coffeejackSettingsStore,
    this.autoStartController,
  });

  final BrewDefaultsSettingsStore? brewDefaultsStore;
  final CoffeejackSettingsStore? coffeejackSettingsStore;
  final AutoStartSettingsController? autoStartController;

  @override
  State<BrewDefaultsScreen> createState() => _BrewDefaultsScreenState();
}

class _BrewDefaultsScreenState extends State<BrewDefaultsScreen> {
  late final BrewDefaultsSettingsStore _brewDefaultsStore;
  late final CoffeejackSettingsStore _coffeejackStore;
  late final AutoStartSettingsController _autoStartController;
  late final bool _ownsAutoStartController;
  BrewDefaultsSettings _brewDefaults = const BrewDefaultsSettings();
  CoffeejackSettings _coffeejackSettings = const CoffeejackSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _brewDefaultsStore = widget.brewDefaultsStore ?? BrewDefaultsSettingsStore();
    _coffeejackStore =
        widget.coffeejackSettingsStore ?? CoffeejackSettingsStore();
    _ownsAutoStartController = widget.autoStartController == null;
    _autoStartController =
        widget.autoStartController ?? AutoStartSettingsController();
    _load();
  }

  @override
  void dispose() {
    if (_ownsAutoStartController) {
      _autoStartController.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _brewDefaultsStore.load(),
      _coffeejackStore.load(),
      _autoStartController.load(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() {
      _brewDefaults = results[0] as BrewDefaultsSettings;
      _coffeejackSettings = results[1] as CoffeejackSettings;
      _loading = false;
    });
  }

  Future<void> _updateDose(double doseG) async {
    final updated = _brewDefaults.copyWith(defaultDoseG: doseG);
    setState(() => _brewDefaults = updated);
    await _brewDefaultsStore.save(updated);
  }

  Future<void> _updateGrind(double grindSetting) async {
    final updated = _brewDefaults.copyWith(defaultGrindSetting: grindSetting);
    setState(() => _brewDefaults = updated);
    await _brewDefaultsStore.save(updated);
  }

  Future<void> _updateCoffeejack(CoffeejackSettings settings) async {
    setState(() => _coffeejackSettings = settings);
    await _coffeejackStore.save(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brew defaults')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: _autoStartController,
              builder: (context, _) {
                final autoStart = _autoStartController.settings;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'New brews',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Applied automatically when a shot is saved. Grind falls '
                      'back to these defaults when you have no previous brew.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    BrewMetadataSliders(
                      doseG: _brewDefaults.defaultDoseG,
                      grindSetting: _brewDefaults.defaultGrindSetting,
                      coffeejackSettings: _coffeejackSettings,
                      onDoseChanged: _updateDose,
                      onGrindChanged: _updateGrind,
                      onCoffeejackChanged: _updateCoffeejack,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Auto-start',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When a pressensor is connected, brewing starts '
                      'automatically once pressure crosses the threshold.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      key: const Key('brew_defaults_auto_start_switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable auto-start'),
                      value: autoStart.enabled,
                      onChanged: (enabled) =>
                          _autoStartController.setEnabled(enabled),
                    ),
                    if (autoStart.enabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Threshold: ${autoStart.startThresholdBar.toStringAsFixed(1)} bar',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Slider(
                        key: const Key('brew_defaults_auto_start_threshold'),
                        value: autoStart.startThresholdBar.clamp(0.5, 2.5),
                        min: 0.5,
                        max: 2.5,
                        divisions: 20,
                        label:
                            '${autoStart.startThresholdBar.toStringAsFixed(1)} bar',
                        onChanged: (value) =>
                            _autoStartController.setThresholdBar(value),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}