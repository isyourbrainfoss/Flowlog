import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Brief summary shown on Live after a brew is saved.
class BrewCompleteBanner extends StatelessWidget {
  const BrewCompleteBanner({
    super.key,
    required this.summary,
    this.onDismiss,
  });

  final BrewSummary summary;
  final VoidCallback? onDismiss;

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
                ],
              ),
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