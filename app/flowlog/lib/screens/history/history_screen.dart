import 'dart:io';

import 'package:flowlog/screens/history/filters.dart';
import 'package:flowlog/screens/history/history_shot_card.dart';
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
  });

  final List<Shot> shots;
  final ShotListFilters filters;
  final Future<void> Function() onRefresh;

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
        itemBuilder: (context, index) => HistoryShotCard(shot: shots[index]),
      ),
    );
  }
}