import 'dart:async';
import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/history/history_fullscreen_chart.dart';
import 'package:flowlog/screens/library/share_profile.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog/screens/live/metadata_sheet.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/target_brew.dart';
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
    this.beanRepository,
    this.profileRepository,
    this.repeatShotController,
  });

  final Shot shot;

  /// Optional repository override for tests.
  final ShotRepository? shotRepository;

  /// Optional repository override for tests.
  final BeanRepository? beanRepository;

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
  BeanRepository? _beanRepository;
  ProfileRepository? _profileRepository;
  FlowlogDatabase? _database;
  bool _ownsShotRepository = false;
  bool _ownsProfileRepository = false;
  bool _repeating = false;
  bool _settingTarget = false;
  bool _editing = false;
  bool _deleting = false;
  RepeatShotController? _repeatShotController;
  String? _beanLabel;
  ShotMetadata? _displayMetadata;

  @override
  void initState() {
    super.initState();
    _currentShot = widget.shot;
    unawaited(_reloadShotAndDisplayMetadata());
  }

  Future<void> _reloadShotAndDisplayMetadata() async {
    final repository = await _ensureShotRepository();
    final loaded = await repository.getShotWithSamples(_currentShot.id);
    if (!mounted) {
      return;
    }

    if (loaded != null) {
      setState(() => _currentShot = loaded);
    }
    await _loadBeanLabel();
    await _loadDisplayMetadata();
  }

  Future<void> _loadDisplayMetadata() async {
    final metadata = await displayMetadataForShot(
      _currentShot,
      shotRepository: await _ensureShotRepository(),
    );
    if (mounted) {
      setState(() => _displayMetadata = metadata);
    }
  }

  Future<void> _loadBeanLabel() async {
    final beanId = _currentShot.beanId;
    if (beanId == null || beanId.trim().isEmpty) {
      return;
    }

    final repository = await _ensureBeanRepository();
    final bean = await repository.getBeanById(beanId);
    if (!mounted) {
      return;
    }

    setState(() {
      if (bean != null) {
        _beanLabel = formatBeanDisplayLabel(bean);
      } else {
        _beanLabel = beanId;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repeatShotController =
        widget.repeatShotController ?? RepeatShotScope.maybeOf(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<BeanRepository> _ensureBeanRepository() async {
    if (widget.beanRepository != null) {
      return widget.beanRepository!;
    }
    if (_beanRepository != null) {
      return _beanRepository!;
    }

    final database = await _ensureDatabase();
    _beanRepository = BeanRepository(database);
    return _beanRepository!;
  }

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (_database != null) {
      return _database!;
    }

    _database = await openFlowlogDatabase();
    _ownsShotRepository = true;
    return _database!;
  }

  Future<ShotRepository> _ensureShotRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    final database = await _ensureDatabase();
    _shotRepository = ShotRepository(database);
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
      _database = await openFlowlogDatabase();
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
        beanRepository: await _ensureBeanRepository(),
        shot: _currentShot,
      );
      if (updated != null && mounted) {
        setState(() => _currentShot = updated);
        await _loadBeanLabel();
        await _loadDisplayMetadata();
      }
    } finally {
      if (mounted) {
        setState(() => _editing = false);
      }
    }
  }

  Future<void> _onDeletePressed() async {
    if (_deleting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key('shot_delete_dialog_${_currentShot.id}'),
        title: const Text('Delete brew'),
        content: const Text(
          'Delete this brew from history? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);
    try {
      final repository = await _ensureShotRepository();
      await repository.deleteShot(_currentShot.id);

      if (widget.shotRepository == null) {
        final database = await _ensureDatabase();
        unawaited(FlowlogSyncCoordinator.syncIfEnabled(database: database));
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
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

  Future<void> _onSetTargetBrewPressed() async {
    if (_settingTarget) {
      return;
    }

    setState(() => _settingTarget = true);
    try {
      await setDefaultTargetBrewFromShot(
        context: context,
        shot: _currentShot,
        profileRepository: await _ensureProfileRepository(),
        targetBrewController: TargetBrewScope.maybeOf(context),
      );
    } finally {
      if (mounted) {
        setState(() => _settingTarget = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shot = _currentShot;
    final theme = Theme.of(context);
    final metadata = _displayMetadata ?? ShotMetadata.fromShot(shot);
    final brewSummary = BrewSummary.fromShot(shot);

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
          IconButton(
            key: const Key('shot_delete'),
            tooltip: 'Delete brew',
            onPressed: _deleting ? null : _onDeletePressed,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HistoryFullscreenChartButton(
              onPressed: () => unawaited(
                openHistoryFullscreenChart(context, shot: shot),
              ),
            ),
            DualCurveChart(
              samples: shot.samples,
              annotations: shot.annotations,
              maxDurationMs: _chartDurationMs(shot),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _MetadataField(
                        label: 'Brew time',
                        value: brewSummary.formatDuration(),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        valueStyle: theme.textTheme.titleMedium,
                      ),
                    ),
                    Expanded(
                      child: _MetadataField(
                        label: 'Peak pressure',
                        value: brewSummary.formatPeakPressure(),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        valueStyle: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Metadata',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _MetadataGrid(
              metadata: metadata,
              shot: shot,
              beanLabel: _beanLabel,
            ),
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
            const SizedBox(height: 8),
            SetTargetBrewButton(
              onPressed: _settingTarget ? null : _onSetTargetBrewPressed,
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
  const _MetadataGrid({
    required this.metadata,
    required this.shot,
    this.beanLabel,
  });

  final ShotMetadata metadata;
  final Shot shot;
  final String? beanLabel;

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
        Row(
          children: [
            Expanded(
              child: _MetadataField(
                label: 'Rewind turns',
                value: _formatTurns(metadata.coffeejackRewindTurns),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
            Expanded(
              child: _MetadataField(
                label: 'Pre-infusion',
                value: _formatPreinfusionTurns(metadata.coffeejackPreinfusionTurns),
                labelStyle: labelStyle,
                valueStyle: valueStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MetadataField(
          label: 'Bean',
          value: beanLabel ?? metadata.beanId ?? '—',
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        if (metadata.location != null) ...[
          const SizedBox(height: 12),
          _MetadataField(
            label: 'Location',
            value: metadata.location!,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
        if (shot.latitude != null && shot.longitude != null) ...[
          const SizedBox(height: 12),
          _MetadataField(
            label: 'GPS',
            value:
                '${shot.latitude!.toStringAsFixed(5)}, ${shot.longitude!.toStringAsFixed(5)}',
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
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

  static String _formatTurns(int? turns) {
    if (turns == null) {
      return '—';
    }
    return '$turns turns';
  }

  static String _formatPreinfusionTurns(int? turns) {
    if (turns == null) {
      return '—';
    }
    return '$turns slow turns';
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