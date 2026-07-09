import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flutter/material.dart';

/// Sliders for dose, grind, and Coffeejack turn counts.
class BrewMetadataSliders extends StatelessWidget {
  const BrewMetadataSliders({
    super.key,
    required this.doseG,
    required this.grindSetting,
    required this.coffeejackSettings,
    required this.onDoseChanged,
    required this.onGrindChanged,
    required this.onCoffeejackChanged,
    this.showCoffeejack = true,
  });

  final double doseG;
  final double grindSetting;
  final CoffeejackSettings coffeejackSettings;
  final ValueChanged<double> onDoseChanged;
  final ValueChanged<double> onGrindChanged;
  final ValueChanged<CoffeejackSettings> onCoffeejackChanged;
  final bool showCoffeejack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snappedGrind = snapGrindSetting(grindSetting);
    final canDecrementGrind = snappedGrind > kBrewGrindMin;
    final canIncrementGrind = snappedGrind < kBrewGrindMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dose: ${doseG.toStringAsFixed(1)} g',
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          key: const Key('metadata_dose_slider'),
          value: doseG.clamp(kBrewDoseMinG, kBrewDoseMaxG),
          min: kBrewDoseMinG,
          max: kBrewDoseMaxG,
          divisions: ((kBrewDoseMaxG - kBrewDoseMinG) * 2).round(),
          label: '${doseG.toStringAsFixed(1)} g',
          onChanged: onDoseChanged,
        ),
        const SizedBox(height: 8),
        Text(
          'Grind: ${formatGrindSetting(snappedGrind)}',
          style: theme.textTheme.titleSmall,
        ),
        Row(
          children: [
            IconButton(
              key: const Key('metadata_grind_decrement'),
              tooltip: 'Finer (−0.1)',
              onPressed: canDecrementGrind
                  ? () => onGrindChanged(
                        snapGrindSetting(snappedGrind - kBrewGrindStep),
                      )
                  : null,
              icon: const Icon(Icons.remove),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Slider(
                key: const Key('metadata_grind_slider'),
                value: snappedGrind,
                min: kBrewGrindMin,
                max: kBrewGrindMax,
                divisions: ((kBrewGrindMax - kBrewGrindMin) * 10).round(),
                label: formatGrindSetting(snappedGrind),
                onChanged: (value) => onGrindChanged(snapGrindSetting(value)),
              ),
            ),
            IconButton(
              key: const Key('metadata_grind_increment'),
              tooltip: 'Coarser (+0.1)',
              onPressed: canIncrementGrind
                  ? () => onGrindChanged(
                        snapGrindSetting(snappedGrind + kBrewGrindStep),
                      )
                  : null,
              icon: const Icon(Icons.add),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        if (showCoffeejack) ...[
          const SizedBox(height: 16),
          Text(
            'Coffeejack',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Turns back before filling water: '
            '${coffeejackSettings.rewindTurnsBeforeFill}',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            key: const Key('metadata_coffeejack_rewind_slider'),
            value: coffeejackSettings.rewindTurnsBeforeFill.toDouble(),
            min: kCoffeejackMinTurns.toDouble(),
            max: kCoffeejackMaxTurns.toDouble(),
            divisions: kCoffeejackMaxTurns - kCoffeejackMinTurns,
            label: '${coffeejackSettings.rewindTurnsBeforeFill} turns',
            onChanged: (value) => onCoffeejackChanged(
              coffeejackSettings.copyWith(
                rewindTurnsBeforeFill: value.round(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Slow turns for pre-infusion: '
            '${coffeejackSettings.slowPreinfusionTurns}',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            key: const Key('metadata_coffeejack_preinfusion_slider'),
            value: coffeejackSettings.slowPreinfusionTurns.toDouble(),
            min: kCoffeejackMinTurns.toDouble(),
            max: kCoffeejackMaxTurns.toDouble(),
            divisions: kCoffeejackMaxTurns - kCoffeejackMinTurns,
            label: '${coffeejackSettings.slowPreinfusionTurns} turns',
            onChanged: (value) => onCoffeejackChanged(
              coffeejackSettings.copyWith(
                slowPreinfusionTurns: value.round(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}