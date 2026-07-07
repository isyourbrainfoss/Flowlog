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
          'Grind: ${grindSetting.toStringAsFixed(1)}',
          style: theme.textTheme.titleSmall,
        ),
        Slider(
          key: const Key('metadata_grind_slider'),
          value: grindSetting.clamp(kBrewGrindMin, kBrewGrindMax),
          min: kBrewGrindMin,
          max: kBrewGrindMax,
          divisions: ((kBrewGrindMax - kBrewGrindMin) * 10).round(),
          label: grindSetting.toStringAsFixed(1),
          onChanged: onGrindChanged,
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