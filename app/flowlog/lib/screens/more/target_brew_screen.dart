import 'dart:async';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/library/profile_picker.dart';
import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/settings/target_brew_store.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Configures the default target brew curve shown on the Live tab.
class TargetBrewScreen extends StatefulWidget {
  const TargetBrewScreen({
    super.key,
    this.targetBrewController,
    this.settingsStore,
    this.profileRepository,
  });

  final TargetBrewController? targetBrewController;
  final TargetBrewSettingsStore? settingsStore;
  final ProfileRepository? profileRepository;

  @override
  State<TargetBrewScreen> createState() => _TargetBrewScreenState();
}

class _TargetBrewScreenState extends State<TargetBrewScreen> {
  late final TargetBrewController _targetBrewController;
  late final bool _ownsController;
  ProfileRepository? _profileRepository;
  FlowlogDatabase? _database;
  bool _loading = true;
  String? _profileName;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.targetBrewController == null;
    _targetBrewController =
        widget.targetBrewController ?? TargetBrewController(
          settingsStore: widget.settingsStore,
        );
    _targetBrewController.addListener(_syncFromController);
    unawaited(_load());
  }

  @override
  void dispose() {
    _targetBrewController.removeListener(_syncFromController);
    if (_ownsController) {
      _targetBrewController.dispose();
    }
    super.dispose();
  }

  void _syncFromController() {
    if (mounted) {
      setState(() => _profileName = _targetBrewController.profileName);
    }
  }

  Future<ProfileRepository> _ensureProfileRepository() async {
    if (widget.profileRepository != null) {
      return widget.profileRepository!;
    }
    if (_profileRepository != null) {
      return _profileRepository!;
    }
    _database = await openFlowlogDatabase();
    _profileRepository = ProfileRepository(_database!);
    return _profileRepository!;
  }

  Future<void> _load() async {
    final repository = await _ensureProfileRepository();
    await _targetBrewController.load(repository);
    if (mounted) {
      setState(() {
        _profileName = _targetBrewController.profileName;
        _loading = false;
      });
    }
  }

  TargetBrewController _effectiveController(BuildContext context) {
    return widget.targetBrewController ??
        TargetBrewScope.maybeOf(context) ??
        _targetBrewController;
  }

  Future<void> _pickProfile() async {
    final repository = await _ensureProfileRepository();
    if (!mounted) {
      return;
    }
    final profile = await showProfilePickerDialog(
      context: context,
      profileRepository: repository,
      title: 'Choose target brew',
    );
    if (profile == null || !mounted) {
      return;
    }

    if (!mounted) {
      return;
    }
    await _effectiveController(context).setProfile(
      profile,
      profileRepository: repository,
    );
  }

  Future<void> _clearTarget() async {
    if (!mounted) {
      return;
    }
    await _effectiveController(context).clear();
  }

  void _openSimulator() {
    FlowlogShellScope.maybeOf(context)?.switchTab(AppTab.library);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasTarget = _targetBrewController.hasTarget;

    return Scaffold(
      appBar: AppBar(title: const Text('Target brew')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Live chart overlay',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your target brew appears as a dotted pressure line on the '
                  'Live tab at all times — even before you start recording.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Current target',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasTarget
                              ? (_profileName ?? 'Saved profile')
                              : 'None set',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('target_brew_pick_profile'),
                  onPressed: () => unawaited(_pickProfile()),
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Choose saved profile'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('target_brew_open_simulator'),
                  onPressed: _openSimulator,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Build in Simulator'),
                ),
                if (hasTarget) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('target_brew_clear'),
                    onPressed: () => unawaited(_clearTarget()),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear target brew'),
                  ),
                ],
              ],
            ),
    );
  }
}