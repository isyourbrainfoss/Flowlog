import 'dart:async';

import 'package:flowlog/screens/history/filters.dart';
import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/history/shot_detail.dart';
import 'package:flowlog/shell/shot_events.dart';
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

  late ShotListFilters _filters;
  late Future<_HistoryData> _historyFuture;
  ShotEventsNotifier? _shotEventsNotifier;
  Timer? _deleteSnackBarTimer;
  int _pendingDeleteSnackBarCount = 0;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _historyFuture = _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final events = ShotEventsScope.maybeOf(context);
    if (events == _shotEventsNotifier) {
      return;
    }
    _shotEventsNotifier?.removeListener(_onShotsChanged);
    _shotEventsNotifier = events;
    _shotEventsNotifier?.addListener(_onShotsChanged);
  }

  void _onShotsChanged() {
    if (!mounted) {
      return;
    }
    unawaited(_refresh());
  }

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (_database != null) {
      return _database!;
    }

    _database = await openFlowlogDatabase();
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
      shotRepository.topTargetScores(limit: 5),
    ]);

    return _HistoryData(
      shots: results[0] as List<Shot>,
      tags: results[1] as List<Tag>,
      topScores: results[2] as List<Shot>,
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
    _scheduleDeleteSnackBar();
  }

  void _scheduleDeleteSnackBar() {
    _pendingDeleteSnackBarCount += 1;
    _deleteSnackBarTimer?.cancel();
    _deleteSnackBarTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) {
        return;
      }

      final count = _pendingDeleteSnackBarCount;
      _pendingDeleteSnackBarCount = 0;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('history_deleted_snackbar'),
          content: Text(
            count == 1 ? 'Brew deleted' : '$count brews deleted',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    });
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
    _deleteSnackBarTimer?.cancel();
    _shotEventsNotifier?.removeListener(_onShotsChanged);
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
            if (data.topScores.isNotEmpty) ...[
              _LeaderboardSection(
                topScores: data.topScores,
                onOpenShot: _openShotDetail,
              ),
              const SizedBox(height: 8),
            ],
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
    this.topScores = const [],
  });

  final List<Shot> shots;
  final List<Tag> tags;
  final List<Shot> topScores;
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
      final theme = Theme.of(context);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filters.isActive ? Icons.filter_alt_off : Icons.coffee_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              filters.isActive
                  ? 'No shots match your filters'
                  : 'No saved shots yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              filters.isActive
                  ? 'Try clearing some filters to see more results.'
                  : 'Start a brew on the Live tab to record your first shot.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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

/// Leaderboard section for highest target-curve scores among saved shots.
class _LeaderboardSection extends StatelessWidget {
  const _LeaderboardSection({
    required this.topScores,
    required this.onOpenShot,
    super.key,
  });

  final List<Shot> topScores;
  final Future<void> Function(Shot shot) onOpenShot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, size: 18),
              const SizedBox(width: 6),
              Text(
                'High scores',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Text(
                '— target curve',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 78,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: topScores.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final shot = topScores[index];
              final rank = index + 1;
              final score = shot.targetScore!;
              final close = shot.targetClosenessPercent;
              final streak = shot.targetMaxStreakSeconds;
              return InkWell(
                onTap: () => unawaited(onOpenShot(shot)),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rank <= 3 ? theme.colorScheme.primary : theme.colorScheme.outline,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$rank',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: rank <= 3 ? theme.colorScheme.onPrimary : theme.colorScheme.surface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            score.toStringAsFixed(0),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _shortDate(shot.startedAt),
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (close != null) '${close.toStringAsFixed(0)}%',
                          if (streak != null && streak > 0) '${streak}s',
                        ].join(' · '),
                        style: theme.textTheme.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _shortDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}