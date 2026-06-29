import 'dart:io';

import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Lists saved shots from [ShotRepository] as summary cards.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.shotRepository,
  });

  /// Optional repository override for tests or dependency injection.
  final ShotRepository? shotRepository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  ShotRepository? _shotRepository;
  FlowlogDatabase? _database;
  bool _ownsRepository = false;
  late Future<List<Shot>> _shotsFuture;

  @override
  void initState() {
    super.initState();
    _shotsFuture = _loadShots();
  }

  Future<ShotRepository> _ensureRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _shotRepository = ShotRepository(_database!);
    _ownsRepository = true;
    return _shotRepository!;
  }

  Future<List<Shot>> _loadShots() async {
    final repository = await _ensureRepository();
    return repository.listShots(includeSamples: true);
  }

  Future<void> _refresh() async {
    setState(() {
      _shotsFuture = _loadShots();
    });
    await _shotsFuture;
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
    return FutureBuilder<List<Shot>>(
      future: _shotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load shots: ${snapshot.error}'),
          );
        }

        final shots = snapshot.data ?? const <Shot>[];

        if (shots.isEmpty) {
          return const Center(
            child: Text('No saved shots yet'),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: shots.length,
            itemBuilder: (context, index) => HistoryShotCard(shot: shots[index]),
          ),
        );
      },
    );
  }
}