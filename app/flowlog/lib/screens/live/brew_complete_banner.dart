import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Brief summary shown on Live after a brew is saved.
class BrewCompleteBanner extends StatelessWidget {
  const BrewCompleteBanner({
    super.key,
    required this.summary,
    this.onDismiss,
    this.onEdit,
  });

  final BrewSummary summary;
  final VoidCallback? onDismiss;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('brew_complete_banner'),
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brew complete',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Time ${summary.formatDuration()} · Peak ${summary.formatPeakPressure()}',
                    key: const Key('brew_complete_summary'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (summary.preInfusionMs != null || summary.highPressureMs != null)
                    Text(
                      'Pre-inf ${summary.formatPreInfusion()} · High-press ${summary.formatHighPressure()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  if (summary.autoStartPressureBar != null)
                    Text(
                      'Auto-started at ${summary.formatAutoStartPressure()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            if (onEdit != null)
              TextButton(
                key: const Key('brew_complete_edit'),
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
            if (onDismiss != null)
              IconButton(
                key: const Key('brew_complete_dismiss'),
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}