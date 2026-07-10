import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Active repeat-shot prefill: metadata + target pressure curve.
@immutable
class RepeatShotPrefill {
  const RepeatShotPrefill({
    required this.profile,
    required this.metadata,
    required this.targetPressureSamples,
  });

  final SavedProfile profile;
  final ShotMetadata metadata;
  final List<ShotSample> targetPressureSamples;

  factory RepeatShotPrefill.fromProfile(SavedProfile profile) {
    final metadata = ProfileMetadata.fromProfile(profile);
    return RepeatShotPrefill(
      profile: profile,
      metadata: ShotMetadata(
        doseG: metadata.doseG,
        yieldG: metadata.yieldG,
        grindSetting: metadata.grindSetting,
        beanId: metadata.beanId,
        waterTempC: metadata.waterTempC,
      ),
      targetPressureSamples: List<ShotSample>.from(profile.pressureSamples),
    );
  }

  factory RepeatShotPrefill.fromShot(Shot shot) {
    final profile = SavedProfile.fromShot(
      shot,
      id: generateProfileId(),
    );
    return RepeatShotPrefill.fromProfile(profile);
  }
}

/// Holds the active repeat-shot prefill for the Live tab.
class RepeatShotController extends ChangeNotifier {
  RepeatShotPrefill? _prefill;

  RepeatShotPrefill? get prefill => _prefill;

  void setPrefill(RepeatShotPrefill prefill) {
    _prefill = prefill;
    notifyListeners();
  }

  void clear() {
    if (_prefill == null) {
      return;
    }
    _prefill = null;
    notifyListeners();
  }
}

/// Provides [RepeatShotController] to the widget tree.
class RepeatShotScope extends InheritedNotifier<RepeatShotController> {
  const RepeatShotScope({
    required RepeatShotController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static RepeatShotController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RepeatShotScope>()
        ?.notifier;
  }
}

/// Persists [shot] as a profile and activates repeat prefill on the Live tab.
Future<void> startRepeatShotFromShot({
  required BuildContext context,
  required Shot shot,
  required ProfileRepository profileRepository,
  RepeatShotController? repeatController,
  void Function(AppTab tab)? switchTab,
}) async {
  final profile = SavedProfile.fromShot(
    shot,
    id: generateProfileId(),
  );
  await profileRepository.insertProfile(profile);
  if (!context.mounted) {
    return;
  }

  final controller =
      repeatController ?? RepeatShotScope.maybeOf(context);
  controller?.setPrefill(RepeatShotPrefill.fromProfile(profile));

  final tabSwitcher = switchTab ?? FlowlogShellScope.maybeOf(context)?.switchTab;
  tabSwitcher?.call(AppTab.live);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('repeat_shot_snackbar'),
        content: Text('Repeating ${profile.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Repeat button for history detail and stopped live sessions.
class RepeatShotButton extends StatelessWidget {
  const RepeatShotButton({
    required this.onPressed,
    super.key,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      key: const Key('repeat_shot_button'),
      onPressed: onPressed,
      icon: const Icon(Icons.replay),
      label: const Text('Repeat shot'),
    );
  }
}

/// Banner shown on Live when a repeat profile is active.
class RepeatShotBanner extends StatelessWidget {
  const RepeatShotBanner({
    required this.profileName,
    required this.onDismiss,
    super.key,
  });

  final String profileName;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.replay, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Target: $profileName',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              key: const Key('repeat_shot_dismiss'),
              tooltip: 'Clear repeat target',
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}