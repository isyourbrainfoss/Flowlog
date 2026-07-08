import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flutter/material.dart';

/// Read-only summary of taste score and flavour tags for a saved brew.
class FlavourProfileSection extends StatelessWidget {
  const FlavourProfileSection({
    required this.tasteScore,
    required this.flavourTags,
    super.key,
  });

  final int? tasteScore;
  final List<String> flavourTags;

  bool get _hasProfile =>
      tasteScore != null || flavourTags.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      key: const Key('flavour_profile_section'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Flavour profile', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (!_hasProfile)
              Text(
                'No flavour notes recorded yet. Edit metadata to add a taste '
                'rating and flavour tags.',
                style: muted,
              )
            else ...[
              if (tasteScore != null) ...[
                Row(
                  children: [
                    Text(
                      'Taste',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      key: const Key('flavour_profile_taste_value'),
                      '$tasteScore/10',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    key: const Key('flavour_profile_taste_bar'),
                    value: tasteScore! / 10,
                    minHeight: 8,
                  ),
                ),
              ],
              if (flavourTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Flavour tags', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  key: const Key('flavour_profile_tags'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _sortedTags(flavourTags))
                      Chip(
                        key: Key('flavour_profile_tag_$tag'),
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                  ],
                ),
              ],
              if (flavourTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                _FlavourTagBars(tags: flavourTags, theme: theme),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static List<String> _sortedTags(List<String> tags) {
    final preset = <String>[];
    final custom = <String>[];
    for (final tag in tags) {
      if (kFlavourTagOptions.contains(tag)) {
        preset.add(tag);
      } else {
        custom.add(tag);
      }
    }
    preset.sort();
    custom.sort();
    return [...preset, ...custom];
  }
}

class _FlavourTagBars extends StatelessWidget {
  const _FlavourTagBars({
    required this.tags,
    required this.theme,
  });

  final List<String> tags;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final selected = tags.toSet();
    final custom = tags
        .where((tag) => !kFlavourTagOptions.contains(tag))
        .toList()
      ..sort();
    final labels = [...kFlavourTagOptions, ...custom];

    return Column(
      key: const Key('flavour_profile_bars'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Profile',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final tag in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _FlavourTagBarRow(
              tag: tag,
              active: selected.contains(tag),
            ),
          ),
      ],
    );
  }
}

class _FlavourTagBarRow extends StatelessWidget {
  const _FlavourTagBarRow({
    required this.tag,
    required this.active,
  });

  final String tag;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = active
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            tag,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 8,
              child: ColoredBox(color: barColor),
            ),
          ),
        ),
      ],
    );
  }
}