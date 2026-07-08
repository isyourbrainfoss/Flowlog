import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Read-only summary of taste score and flavour intensities for a saved brew.
class FlavourProfileSection extends StatelessWidget {
  const FlavourProfileSection({
    required this.tasteScore,
    required this.flavourTags,
    this.flavourIntensities = const {},
    super.key,
  });

  final int? tasteScore;
  final List<String> flavourTags;
  final Map<String, int> flavourIntensities;

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
                      'Overall taste',
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
                    value: tasteScore! / kMaxFlavourIntensity,
                    minHeight: 8,
                  ),
                ),
              ],
              if (flavourTags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Flavour notes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  key: const Key('flavour_profile_tags'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _sortedTags(flavourTags))
                      Chip(
                        key: Key('flavour_profile_tag_$tag'),
                        label: Text(
                          '$tag ${_intensityLabel(tag)}',
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _FlavourIntensityBars(
                  tags: flavourTags,
                  intensities: flavourIntensities,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _intensityLabel(String tag) {
    final intensity = flavourIntensityForTag(
      tag: tag,
      tags: flavourTags,
      intensities: flavourIntensities,
    );
    return intensity == null ? '' : '$intensity/10';
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

class _FlavourIntensityBars extends StatelessWidget {
  const _FlavourIntensityBars({
    required this.tags,
    required this.intensities,
  });

  final List<String> tags;
  final Map<String, int> intensities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedTags = FlavourProfileSection._sortedTags(tags);

    return Column(
      key: const Key('flavour_profile_bars'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Intensity',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final tag in sortedTags)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FlavourIntensityBarRow(
              tag: tag,
              intensity: flavourIntensityForTag(
                tag: tag,
                tags: tags,
                intensities: intensities,
              )!,
            ),
          ),
      ],
    );
  }
}

class _FlavourIntensityBarRow extends StatelessWidget {
  const _FlavourIntensityBarRow({
    required this.tag,
    required this.intensity,
  });

  final String tag;
  final int intensity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            tag,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: Key('flavour_profile_bar_$tag'),
              value: intensity / kMaxFlavourIntensity,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            key: Key('flavour_profile_intensity_$tag'),
            '$intensity/10',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}