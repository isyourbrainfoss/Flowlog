import 'dart:async';

import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/settings/coffeejack_settings_store.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Generates a unique shot id for persistence.
typedef ShotIdGenerator = String Function();

/// Default id format: `shot-<utc-milliseconds>`.
String generateShotId() {
  return 'shot-${DateTime.now().toUtc().millisecondsSinceEpoch}';
}

/// Builds a [Shot] from a stopped session and optional metadata.
Shot buildShotFromSession({
  required List<ShotSample> samples,
  required DateTime startedAt,
  DateTime? endedAt,
  ShotMetadata? metadata,
  List<ShotAnnotation> annotations = const [],
  String? id,
  String? location,
  double? latitude,
  double? longitude,
  double? autoStartPressureBar,
  ShotIdGenerator idGenerator = generateShotId,
}) {
  var shot = Shot(
    id: id ?? idGenerator(),
    startedAt: startedAt,
    endedAt: endedAt ?? DateTime.now().toUtc(),
    location: location,
    latitude: latitude,
    longitude: longitude,
    autoStartPressureBar: autoStartPressureBar,
    samples: List<ShotSample>.from(samples),
    annotations: List<ShotAnnotation>.from(annotations),
    lastModifiedAt: endedAt ?? DateTime.now().toUtc(),
  );

  if (metadata != null) {
    shot = metadata.applyTo(shot);
  }

  return shot;
}

/// Persists [shot] via [repository].
Future<Shot> saveShot({
  required ShotRepository repository,
  required Shot shot,
}) async {
  await repository.insertShot(shot);
  return shot;
}

/// Shows a brief confirmation after a shot is saved.
void showShotSavedSnackBar(BuildContext context, {String? message}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: const Key('shot_saved_snackbar'),
      content: Text(message ?? 'Shot saved'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<ShotMetadata> defaultMetadataFromSamples(
  List<ShotSample> samples, {
  BeanRepository? beanRepository,
  ShotRepository? shotRepository,
  BrewDefaultsSettingsStore? brewDefaultsStore,
  CoffeejackSettingsStore? coffeejackSettingsStore,
  String? activeBeanName,
  String? activeBeanId,
}) async {
  final last = samples.last;
  final beanId = beanRepository == null
      ? activeBeanId
      : await beanRepository.resolveActiveBeanId(
          beanId: activeBeanId,
          name: activeBeanName,
        );
  final defaults = await (brewDefaultsStore ?? BrewDefaultsSettingsStore())
      .load();
  final coffeejack =
      await (coffeejackSettingsStore ?? CoffeejackSettingsStore()).load();
  final lastGrind = shotRepository == null
      ? null
      : await shotRepository.lastGrindSetting();

  final brewTemp = brewTempRangeFromSamples(samples);
  return ShotMetadata(
    doseG: defaults.useDefaultDose ? defaults.defaultDoseG : null,
    grindSetting: defaults.useDefaultGrind
        ? (lastGrind ?? defaults.defaultGrindSetting)
        : null,
    waterTempC: brewTemp.endTempC ?? last.tempC,
    beanId: beanId,
    coffeejackRewindTurns: defaults.useDefaultCoffeejack ? coffeejack.rewindTurnsBeforeFill : null,
    coffeejackPreinfusionTurns: defaults.useDefaultCoffeejack ? coffeejack.slowPreinfusionTurns : null,
  );
}

ShotMetadata applyShotMetadataDefaults(
  ShotMetadata metadata, {
  required double defaultDoseG,
  required double defaultGrindSetting,
  bool useDefaultDose = true,
  bool useDefaultGrind = true,
  double? lastGrindSetting,
}) {
  return metadata.copyWith(
    doseG: metadata.doseG ?? (useDefaultDose ? defaultDoseG : null),
    grindSetting: metadata.grindSetting ??
        (useDefaultGrind ? (lastGrindSetting ?? defaultGrindSetting) : null),
  );
}

/// Returns the explicit yieldG stored on the shot if present.
/// Otherwise falls back to the last weight sample (the measured end weight).
/// This fallback is used for history cards, ratios, etc. even when the user
/// has not manually noted a yield in metadata (yieldG is now null by default
/// on new shots unless entered in the metadata sheet).
double? inferredYieldG(Shot shot) {
  if (shot.yieldG != null) {
    return shot.yieldG;
  }
  if (shot.samples.isEmpty) {
    return null;
  }
  return shot.samples.last.weightG;
}

/// Metadata for history display. Fills safe defaults (dose, grind, temp, coffeejack)
/// but does *not* auto-populate yieldG (it is empty by default unless the user
/// explicitly entered a value via the metadata editor).
Future<ShotMetadata> displayMetadataForShot(
  Shot shot, {
  BrewDefaultsSettingsStore? brewDefaultsStore,
  CoffeejackSettingsStore? coffeejackSettingsStore,
  ShotRepository? shotRepository,
}) async {
  final defaults = await (brewDefaultsStore ?? BrewDefaultsSettingsStore())
      .load();
  final coffeejack =
      await (coffeejackSettingsStore ?? CoffeejackSettingsStore()).load();
  final lastGrind = shotRepository == null
      ? null
      : await shotRepository.lastGrindSetting();

  var metadata = applyShotMetadataDefaults(
    ShotMetadata.fromShot(shot),
    defaultDoseG: defaults.defaultDoseG,
    defaultGrindSetting: defaults.defaultGrindSetting,
    useDefaultDose: defaults.useDefaultDose,
    useDefaultGrind: defaults.useDefaultGrind,
    lastGrindSetting: lastGrind,
  );

  if (shot.samples.isNotEmpty) {
    final last = shot.samples.last;
    final brewTemp = brewTempRangeFromSamples(shot.samples);
    metadata = metadata.copyWith(
      // Yield is intentionally left as stored on the shot (null by default).
      // Only set via explicit user input in the metadata editor.
      // Callers that need a fallback for ratios etc. use inferredYieldG(shot).
      // yieldG: metadata.yieldG ?? last.weightG,
      waterTempC: metadata.waterTempC ?? brewTemp.endTempC ?? last.tempC,
    );
  }

  if (defaults.useDefaultCoffeejack) {
    return metadata.copyWith(
      coffeejackRewindTurns: metadata.coffeejackRewindTurns ??
          coffeejack.rewindTurnsBeforeFill,
      coffeejackPreinfusionTurns: metadata.coffeejackPreinfusionTurns ??
          coffeejack.slowPreinfusionTurns,
    );
  }
  return metadata;
}

/// Persists a stopped session immediately with inferred metadata.
Future<Shot?> runAutoSaveFlow({
  required BuildContext context,
  required ShotRepository repository,
  required List<ShotSample> samples,
  required DateTime startedAt,
  DateTime? endedAt,
  ShotMetadata? initialMetadata,
  BeanRepository? beanRepository,
  ShotRepository? shotRepository,
  BrewDefaultsSettingsStore? brewDefaultsStore,
  String? activeBeanName,
  String? activeBeanId,
  List<ShotAnnotation> annotations = const [],
  String? location,
  double? latitude,
  double? longitude,
  double? autoStartPressureBar,
  ShotIdGenerator idGenerator = generateShotId,
  void Function(Shot shot)? onSaved,
  Future<void> Function(Shot shot)? onAddNotes,
  Future<void> Function(Shot shot)? onDiscard,
}) async {
  if (samples.isEmpty) {
    return null;
  }

  final defaultsStore = brewDefaultsStore ?? BrewDefaultsSettingsStore();
  final defaults = await defaultsStore.load();
  final lastGrind = shotRepository == null
      ? null
      : await shotRepository.lastGrindSetting();

  ShotMetadata metadata;
  if (initialMetadata != null) {
    metadata = applyShotMetadataDefaults(
      initialMetadata,
      defaultDoseG: defaults.defaultDoseG,
      defaultGrindSetting: defaults.defaultGrindSetting,
      useDefaultDose: defaults.useDefaultDose,
      useDefaultGrind: defaults.useDefaultGrind,
      lastGrindSetting: lastGrind,
    );
    if (metadata.beanId == null && beanRepository != null) {
      final resolvedId = await beanRepository.resolveActiveBeanId(
        beanId: activeBeanId,
        name: activeBeanName,
      );
      if (resolvedId != null) {
        metadata = metadata.copyWith(beanId: resolvedId);
      }
    }
  } else {
    metadata = await defaultMetadataFromSamples(
      samples,
      beanRepository: beanRepository,
      shotRepository: shotRepository,
      brewDefaultsStore: defaultsStore,
      activeBeanName: activeBeanName,
      activeBeanId: activeBeanId,
    );
  }

  final shot = buildShotFromSession(
    samples: samples,
    startedAt: startedAt,
    endedAt: endedAt,
    metadata: metadata,
    annotations: annotations,
    location: location,
    latitude: latitude,
    longitude: longitude,
    autoStartPressureBar: autoStartPressureBar,
    idGenerator: idGenerator,
  );

  await saveShot(repository: repository, shot: shot);
  onSaved?.call(shot);

  if (context.mounted) {
    showAutoSavedSnackBar(
      context,
      summary: BrewSummary.fromShot(shot),
      onAddNotes: onAddNotes == null
          ? null
          : () async {
              await onAddNotes(shot);
            },
      onDiscard: onDiscard == null
          ? null
          : () async {
              await onDiscard(shot);
            },
    );
  }

  return shot;
}

/// Snackbar after auto-save with optional follow-up actions.
void showAutoSavedSnackBar(
  BuildContext context, {
  BrewSummary? summary,
  Future<void> Function()? onAddNotes,
  Future<void> Function()? onDiscard,
}) {
  final message = summary?.savedMessage() ?? 'Shot saved';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: const Key('shot_saved_snackbar'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
      content: Row(
        children: [
          Expanded(child: Text(message)),
          if (onAddNotes != null)
            TextButton(
              key: const Key('shot_add_notes_action'),
              onPressed: () => unawaited(onAddNotes()),
              child: const Text('Add notes'),
            ),
          if (onDiscard != null)
            TextButton(
              key: const Key('shot_discard_action'),
              onPressed: () => unawaited(onDiscard()),
              child: const Text('Discard'),
            ),
        ],
      ),
    ),
  );
}

/// Opens the metadata sheet and updates an already-saved shot.
Future<Shot?> runAddNotesFlow({
  required BuildContext context,
  required ShotRepository repository,
  required Shot shot,
  BeanRepository? beanRepository,
  void Function(Shot shot)? onSaved,
}) async {
  final metadata = await showMetadataSheet(
    context,
    initial: ShotMetadata.fromShot(shot),
    beanRepository: beanRepository,
  );
  if (metadata == null || !context.mounted) {
    return null;
  }

  final updated = metadata.applyTo(shot);
  await saveShot(repository: repository, shot: updated);
  onSaved?.call(updated);

  if (context.mounted) {
    showShotSavedSnackBar(context, message: 'Notes saved');
  }

  return updated;
}

/// Opens the metadata sheet and persists the stopped session when confirmed.
Future<Shot?> runStarShotSaveFlow({
  required BuildContext context,
  required ShotRepository repository,
  required List<ShotSample> samples,
  required DateTime startedAt,
  DateTime? endedAt,
  ShotMetadata? initialMetadata,
  List<ShotAnnotation> annotations = const [],
  ShotIdGenerator idGenerator = generateShotId,
  void Function(Shot shot)? onSaved,
}) async {
  if (samples.isEmpty) {
    return null;
  }

  final ShotMetadata? initial;
  if (initialMetadata != null) {
    initial = initialMetadata;
  } else {
    initial = await defaultMetadataFromSamples(samples);
    if (!context.mounted) {
      return null;
    }
  }

  final metadata = await showMetadataSheet(
    context,
    initial: initial,
  );
  if (metadata == null || !context.mounted) {
    return null;
  }

  final shot = buildShotFromSession(
    samples: samples,
    startedAt: startedAt,
    endedAt: endedAt,
    metadata: metadata,
    annotations: annotations,
    idGenerator: idGenerator,
  );

  await saveShot(repository: repository, shot: shot);
  onSaved?.call(shot);

  if (context.mounted) {
    showShotSavedSnackBar(context);
  }

  return shot;
}