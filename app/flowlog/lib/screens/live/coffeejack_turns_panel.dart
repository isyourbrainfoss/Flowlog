import 'package:flowlog/screens/more/brew_defaults_screen.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flutter/material.dart';

/// Shows Coffeejack rewind and pre-infusion turn counts on the Live tab.
class CoffeejackTurnsPanel extends StatelessWidget {
  const CoffeejackTurnsPanel({
    super.key,
    required this.settings,
    this.onTap,
  });

  final CoffeejackSettings settings;
  final VoidCallback? onTap;

  Future<void> _openSettings(BuildContext context) async {
    if (onTap != null) {
      onTap!();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const BrewDefaultsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('live_coffeejack_turns_panel'),
        onTap: () => _openSettings(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.settings_backup_restore,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coffeejack',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rewind ${settings.rewindTurnsBeforeFill} turns · '
                      'Pre-infusion ${settings.slowPreinfusionTurns} slow turns',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}