import 'dart:io';

import 'package:flowlog/screens/library/share_profile.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Read-only detail view for a saved shot: full chart and metadata.
class ShotDetailScreen extends StatefulWidget {
  const ShotDetailScreen({
    super.key,
    required this.shot,
    this.shotRepository,
    this.profileRepository,
    this.repeatShotController,
  });

  final Shot shot;

  /// Optional repository override for tests.
  final ShotRepository? shotRepository;

  /// Optional repository override for tests.
  final ProfileRepository? profileRepository;

  /// Optional repeat-shot controller override for tests.
  final RepeatShotController? repeatShotController;

  @override
  State<ShotDetailScreen> createState() => _ShotDetailScreenState();
}

class _ShotDetailScreenState extends State<ShotDetailScreen> {
  late Shot _currentShot;
  ShotRepository? _shotRepository;
  ProfileRepository? _profileRepository;
  FlowlogDatabase? _database;
  bool _ownsShotRepository = false;
  bool _ownsProfileRepository = false;
  bool _repeating = false;
  bool _editing = false;
  RepeatShotController? _repeatShotController;

  @override
  void initState() {
    super.initState();
    _currentShot = widget.shot;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repeatShotController =
        widget.repeatShotController ?? RepeatShotScope.maybeOf(context);
  }

  @override
  void dispose() {
    if (_ownsShotRepository || _ownsProfileRepository) {
      _database?.close();
    }
    super.dispose();
  }

  Future<ShotRepository> _ensureShotRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _shotRepository = ShotRepository(_database!);
    _ownsShotRepository = true;
    return _shotRepository!;
  }

  Future<ProfileRepository> _ensureProfileRepository() async {
    if (widget.profileRepository != null) {
      return widget.profileRepository!;
    }
    if (_profileRepository != null) {
      return _profileRepository!;
    }

    if (_database == null) {
      final dbPath = '${Directory.systemTemp.path}/flowlog.db';
      _database = FlowlogDatabase.openFile(dbPath);
    }
    _profileRepository = ProfileRepository(_database!);
    _ownsProfileRepository = true;
    return _profileRepository!;
  }

  Future<void> _onEditMetadataPressed() async {
    if (_editing) {
      return;
    }

    setState(() => _editing = true);
    try {
      final updated = await runAddNotesFlow(
        context: context,
        repository: await _ensureShotRepository(),
        shot: _currentShot,
      );
      if (updated != null && mounted) {
        setState(() => _currentShot = updated);
      }
    } finally {
      if (mounted) {
        setState(() => _editing = false);
      }
    }
  }

  Future<void> _onRepeatShotPressed() async {
    if (_repeating) {
      return;
    }

    setState(() => _repeating = true);
    try {
      await startRepeatShotFromShot(
        context: context,
        shot: _currentShot,
        profileRepository: await _ensureProfileRepository(),
        repeatController: _repeatShotController,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _repeating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shot = _currentShot;
    final theme = Theme.of(context);
    final metadata = ShotMetadata.fromShot(shot);

    return Scaffold(
      key: Key('shot_detail_${shot.id}'),
      appBar: AppBar(
        title: Text(_formatStartedAt(shot.startedAt)),
        actions: [
          IconButton(
            key: const Key('shot_edit_metadata'),
            tooltip: 'Edit metadata',
            onPressed: _editing ? null : _onEditMetadataPressed,
            icon: const Icon(Icons.edit_outlined),
          ),
          ShareProfileButton.fromShot(shot),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DualCurveChart(
              samples: shot.samples,
              annotations: shot.annotations,
              maxDurationMs: _chartDurationMs(shot),
            ),
            const SizedBox(height: 24),
            Text(
              'Metadata',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _MetadataGrid(metadata: metadata),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('shot_edit_metadata_button'),
              onPressed: _editing ? null : _onEditMetadataPressed,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit notes & metadata'),
            ),
            if (metadata.notes != null && metadata.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Notes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(metadata.notes!),
            ],
            if (metadata.flavourTags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Flavour tags', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in metadata.flavourTags)
                    Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            RepeatShotButton(
              onPressed: _repeating ? null : _onRepeatShotPressed,
            ),
          ],
        ),
      ),
    );
  }

  static int? _chartDurationMs(Shot shot) {
    if (shot.endedAt != null) {
      return shot.endedAt!.difference(shot.startedAt).inMilliseconds;
    }
    if (shot.samples.isEmpty) {
      return null;
    }
    return shot.samples.last.elapsedMs;
  }

  static String _formatStartedAt(DateTime startedAt) {
    final local = startedAt.toLocal();
    final year = local.year;
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

/// Pushes [ShotDetailScreen] for [shot].
void openShotDetail(BuildContext context, Shot shot) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ShotDetailScreen(shot: shot),
    ),
  );
}

class _MetadataGrid extends StatelessWidget {
  const _MetadataGrid({required this.metadata});

  final ShotMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    final valueStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetadataField(
                label: 'Dose',
                value: _formatGrams(metadata.doseG),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
            Expanded(
              child: _MetadataField(
                label: 'Yield',
                value: _formatGrams(metadata.yieldG),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetadataField(
                label: 'Grind',
                value: _formatNumber(metadata.grindSetting),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
            Expanded(
              child: _MetadataField(
                label: 'Water temp',
                value: _formatTemp(metadata.waterTempC),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetadataField(
          label: 'Bean',
          value: metadata.beanId ?? '—',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        const SizedBox(height: 12),
        _MetadataField(
          label: 'Taste',
          value: _formatTasteScore(metadata.tasteScore),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      ],
    );
  }

  static String _formatGrams(double? value) {
    if (value == null) {
      return '—';
    }
    return '${value.toStringAsFixed(1)} g';
  }

  static String _formatNumber(double? value) {
    if (value == null) {
      return '—';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String _formatTemp(double? value) {
    if (value == null) {
      return '—';
    }
    return '${value.toStringAsFixed(1)} °C';
  }

  static String _formatTasteScore(int? tasteScore) {
    if (tasteScore == null) {
      return '—';
    }
    return '$tasteScore/10';
  }
}

class _MetadataField extends StatelessWidget {
  const _MetadataField({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $value',
      readOnly: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 2),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}