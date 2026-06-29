import 'package:flowlog/screens/live/metadata_sheet.dart';
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
  String? id,
  ShotIdGenerator idGenerator = generateShotId,
}) {
  var shot = Shot(
    id: id ?? idGenerator(),
    startedAt: startedAt,
    endedAt: endedAt ?? DateTime.now().toUtc(),
    samples: List<ShotSample>.from(samples),
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

/// Opens the metadata sheet and persists the stopped session when confirmed.
Future<Shot?> runExcellentShotSaveFlow({
  required BuildContext context,
  required ShotRepository repository,
  required List<ShotSample> samples,
  required DateTime startedAt,
  DateTime? endedAt,
  ShotMetadata? initialMetadata,
  ShotIdGenerator idGenerator = generateShotId,
  void Function(Shot shot)? onSaved,
}) async {
  if (samples.isEmpty) {
    return null;
  }

  final metadata = await showMetadataSheet(
    context,
    initial: initialMetadata ?? _defaultMetadataFromSamples(samples),
  );
  if (metadata == null || !context.mounted) {
    return null;
  }

  final shot = buildShotFromSession(
    samples: samples,
    startedAt: startedAt,
    endedAt: endedAt,
    metadata: metadata,
    idGenerator: idGenerator,
  );

  await saveShot(repository: repository, shot: shot);
  onSaved?.call(shot);

  if (context.mounted) {
    showShotSavedSnackBar(context);
  }

  return shot;
}

ShotMetadata _defaultMetadataFromSamples(List<ShotSample> samples) {
  final last = samples.last;
  return ShotMetadata(
    yieldG: last.weightG,
    waterTempC: last.tempC,
  );
}

/// Floating action button for saving a standout completed shot.
class ExcellentShotFab extends StatelessWidget {
  const ExcellentShotFab({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloatingActionButton.extended(
      key: const Key('excellent_shot_fab'),
      onPressed: enabled ? onPressed : null,
      tooltip: 'Save excellent shot',
      icon: Icon(
        Icons.auto_awesome,
        color: enabled ? null : theme.disabledColor,
      ),
      label: const Text('Excellent shot'),
    );
  }
}