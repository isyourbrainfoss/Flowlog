import 'package:flowlog/settings/target_brew_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Holds the persisted default target brew curve for the Live tab chart.
class TargetBrewController extends ChangeNotifier {
  TargetBrewController({
    TargetBrewSettingsStore? settingsStore,
  }) : _settingsStore = settingsStore ?? TargetBrewSettingsStore();

  final TargetBrewSettingsStore _settingsStore;

  String? _profileId;
  String? _profileName;
  List<ShotSample> _pressureSamples = const [];

  String? get profileId => _profileId;
  String? get profileName => _profileName;
  List<ShotSample> get pressureSamples => _pressureSamples;
  bool get hasTarget => _pressureSamples.isNotEmpty;

  Future<void> load(ProfileRepository profileRepository) async {
    final settings = await _settingsStore.load();
    if (!settings.hasTarget) {
      _clearInMemory();
      notifyListeners();
      return;
    }

    final profile =
        await profileRepository.getProfileWithSamples(settings.profileId!);
    if (profile == null || profile.pressureSamples.isEmpty) {
      _profileId = settings.profileId;
      _profileName = settings.profileName;
      _pressureSamples = const [];
      notifyListeners();
      return;
    }

    _applyProfile(profile);
    notifyListeners();
  }

  Future<void> setProfile(
    SavedProfile profile, {
    ProfileRepository? profileRepository,
  }) async {
    if (profile.pressureSamples.isEmpty && profileRepository != null) {
      final loaded =
          await profileRepository.getProfileWithSamples(profile.id);
      if (loaded != null) {
        profile = loaded;
      }
    }

    await _settingsStore.save(
      TargetBrewSettings(
        profileId: profile.id,
        profileName: profile.name,
      ),
    );
    _applyProfile(profile);
    notifyListeners();
  }

  Future<void> clear() async {
    await _settingsStore.clear();
    _clearInMemory();
    notifyListeners();
  }

  void _applyProfile(SavedProfile profile) {
    _profileId = profile.id;
    _profileName = profile.name;
    _pressureSamples = List<ShotSample>.from(profile.pressureSamples);
  }

  void _clearInMemory() {
    _profileId = null;
    _profileName = null;
    _pressureSamples = const [];
  }
}

/// Provides [TargetBrewController] to the widget tree.
class TargetBrewScope extends InheritedNotifier<TargetBrewController> {
  const TargetBrewScope({
    required TargetBrewController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static TargetBrewController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TargetBrewScope>()
        ?.notifier;
  }
}

/// Persists [profile] as the default target brew curve.
Future<void> setDefaultTargetBrew({
  required BuildContext context,
  required SavedProfile profile,
  ProfileRepository? profileRepository,
  TargetBrewController? targetBrewController,
}) async {
  final controller =
      targetBrewController ?? TargetBrewScope.maybeOf(context);
  await controller?.setProfile(
    profile,
    profileRepository: profileRepository,
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('target_brew_set_snackbar'),
        content: Text('Target brew set — ${profile.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Saves a shot curve as the persistent default target brew.
Future<void> setDefaultTargetBrewFromShot({
  required BuildContext context,
  required Shot shot,
  required ProfileRepository profileRepository,
  TargetBrewController? targetBrewController,
}) async {
  final profile = SavedProfile.fromShot(
    shot,
    id: generateProfileId(),
  );
  await profileRepository.insertProfile(profile);
  await setDefaultTargetBrew(
    context: context,
    profile: profile,
    profileRepository: profileRepository,
    targetBrewController: targetBrewController,
  );
}

/// Button for setting a shot as the default target brew.
class SetTargetBrewButton extends StatelessWidget {
  const SetTargetBrewButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const Key('set_target_brew_button'),
      onPressed: onPressed,
      icon: const Icon(Icons.timeline),
      label: const Text('Set as target brew'),
    );
  }
}

/// Banner shown on Live when a default target brew is active.
class TargetBrewBanner extends StatelessWidget {
  const TargetBrewBanner({
    required this.profileName,
    this.onTap,
    super.key,
  });

  final String profileName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.timeline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target brew: $profileName',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}