import 'dart:async';
import 'dart:io';

import 'package:flowlog/screens/history/filters.dart';
import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog/sync/flowlog_sync_coordinator.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Lists saved shots from [ShotRepository] as summary cards.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.shotRepository,
    this.tagRepository,
    this.initialFilters = ShotListFilters.empty,
  });

  /// Optional repository override for tests or dependency injection.
  final ShotRepository? shotRepository;

  /// Optional tag repository override for tests or dependency injection.
  final TagRepository? tagRepository;

  /// Initial filter state (primarily for tests).
  final ShotListFilters initialFilters;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ShotRepository? _shotRepository;
  TagRepository? _tagRepository;
  FlowlogDatabase? _database;
  bool _ownsRepository = false;
  late ShotListFilters _filters;
  late Future<_HistoryData> _historyFuture;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _historyFuture = _loadHistory();
  }

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _ownsRepository = true;
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
    return _shotRepository!;
  }

  Future<TagRepository> _ensureTagRepository() async {
    if (widget.tagRepository != null) {
      return widget.tagRepository!;
    }
    if (_tagRepository != null) {
      return _tagRepository!;
    }

    final database = await _ensureDatabase();
    _tagRepository = TagRepository(database);
    return _tagRepository!;
  }

  Future<_HistoryData> _loadHistory() async {
    final shotRepository = await _ensureShotRepository();
    final tagRepository = await _ensureTagRepository();
    final results = await Future.wait([
      shotRepository.listShots(
        includeSamples: true,
        filters: _filters,
      ),
      tagRepository.listTags(),
    ]);

    return _HistoryData(
      shots: results[0] as List<Shot>,
      tags: results[1] as List<Tag>,
    );
  }

  void _onFiltersChanged(ShotListFilters filters) {
    setState(() {
      _filters = filters;
      _historyFuture = _loadHistory();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
    await _historyFuture;
  }

  Future<void> _openShotDetail(Shot shot) async {
    final shotRepository = await _ensureShotRepository();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ShotDetailScreen(
          shot: shot,
          shotRepository: shotRepository,
        ),
      ),
    );

    if (mounted) {
      await _refresh();
    }
  }

  Future<bool> _confirmDeleteShot(Shot shot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key('history_delete_dialog_${shot.id}'),
        title: const Text('Delete brew'),
        content: Text(
          'Delete the brew from ${_formatStartedAt(shot.startedAt)}? '
          'This cannot be undone.',
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

    return confirmed == true;
  }

  Future<void> _deleteShot(Shot shot) async {
    if (!await _confirmDeleteShot(shot) || !mounted) {
      return;
    }
    await _deleteShotConfirmed(shot);
  }

  Future<void> _deleteShotConfirmed(Shot shot) async {
    final shotRepository = await _ensureShotRepository();
    await shotRepository.deleteShot(shot.id);

    if (widget.shotRepository == null) {
      final database = await _ensureDatabase();
      unawaited(FlowlogSyncCoordinator.syncIfEnabled(database: database));
    }

    if (!mounted) {
      return;
    }

    await _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: Key('history_deleted_snackbar_${shot.id}'),
        content: const Text('Brew deleted'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  @override
  void dispose() {
    if (_ownsRepository) {
      _database?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HistoryData>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load history: ${snapshot.error}'),
          );
        }

        final data = snapshot.data!;
        final shots = data.shots;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HistoryFiltersPanel(
              filters: _filters,
              tags: data.tags,
              onChanged: _onFiltersChanged,
            ),
            Expanded(
              child: _HistoryShotList(
                shots: shots,
                filters: _filters,
                onRefresh: _refresh,
                onOpenShot: _openShotDetail,
                onDeleteShot: _deleteShot,
                onDeleteShotConfirmed: _deleteShotConfirmed,
                confirmDeleteShot: _confirmDeleteShot,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryData {
  const _HistoryData({
    required this.shots,
    required this.tags,
  });

  final List<Shot> shots;
  final List<Tag> tags;
}

class _HistoryShotList extends StatelessWidget {
  const _HistoryShotList({
    required this.shots,
    required this.filters,
    required this.onRefresh,
    required this.onOpenShot,
    required this.onDeleteShot,
    required this.onDeleteShotConfirmed,
    required this.confirmDeleteShot,
  });

  final List<Shot> shots;
  final ShotListFilters filters;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Shot shot) onOpenShot;
  final Future<void> Function(Shot shot) onDeleteShot;
  final Future<void> Function(Shot shot) onDeleteShotConfirmed;
  final Future<bool> Function(Shot shot) confirmDeleteShot;

  @override
  Widget build(BuildContext context) {
    if (shots.isEmpty) {
      return Center(
        child: Text(
          filters.isActive ? 'No shots match filters' : 'No saved shots yet',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: shots.length,
        itemBuilder: (context, index) {
          final shot = shots[index];
          return Dismissible(
            key: Key('history_dismiss_${shot.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => confirmDeleteShot(shot),
            onDismissed: (_) => unawaited(onDeleteShotConfirmed(shot)),
            background: Container(
              alignment: Alignment.centerRight,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            child: HistoryShotCard(
              shot: shot,
              onTap: () => unawaited(onOpenShot(shot)),
              onDelete: () => unawaited(onDeleteShot(shot)),
            ),
          );
        },
      ),
    );
  }
}