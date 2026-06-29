import 'dart:io';

import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// One row in a simple horizontal bar chart.
@immutable
class InsightsBarEntry {
  const InsightsBarEntry({
    required this.label,
    required this.value,
    this.sampleCount = 0,
  });

  final String label;
  final double value;
  final int sampleCount;
}

/// Aggregated trend stats derived from saved shots and beans.
@immutable
class InsightsSnapshot {
  const InsightsSnapshot({
    required this.avgPeakPressureByRoast,
    required this.avgTasteByBean,
    required this.shotCountByDay,
  });

  final List<InsightsBarEntry> avgPeakPressureByRoast;
  final List<InsightsBarEntry> avgTasteByBean;
  final List<InsightsBarEntry> shotCountByDay;

  bool get hasData =>
      avgPeakPressureByRoast.isNotEmpty ||
      avgTasteByBean.isNotEmpty ||
      shotCountByDay.isNotEmpty;
}

/// Computes trend stats from [shots] and [beans].
InsightsSnapshot computeInsights({
  required List<Shot> shots,
  required List<Bean> beans,
}) {
  final beansById = {for (final bean in beans) bean.id: bean};

  final peakByRoast = <String, List<double>>{};
  for (final shot in shots) {
    final peak = HistoryShotCard.peakPressureBar(shot.samples);
    if (peak == null) {
      continue;
    }
    final roast = _roastLabelForShot(shot, beansById);
    peakByRoast.putIfAbsent(roast, () => []).add(peak);
  }

  final tasteByBean = <String, List<int>>{};
  for (final shot in shots) {
    final taste = shot.tasteScore;
    if (taste == null) {
      continue;
    }
    final label = _beanLabelForShot(shot, beansById);
    tasteByBean.putIfAbsent(label, () => []).add(taste);
  }

  final countByDay = <String, int>{};
  for (final shot in shots) {
    final day = _dayKey(shot.startedAt);
    countByDay[day] = (countByDay[day] ?? 0) + 1;
  }

  return InsightsSnapshot(
    avgPeakPressureByRoast: _averageEntries(peakByRoast, suffix: ' bar'),
    avgTasteByBean: _averageEntries(
      tasteByBean.map((key, values) => MapEntry(key, values.map((v) => v.toDouble()).toList())),
      suffix: '/10',
    ),
    shotCountByDay: _sortedDayCounts(countByDay),
  );
}

String _roastLabelForShot(Shot shot, Map<String, Bean> beansById) {
  final beanId = shot.beanId;
  if (beanId == null) {
    return 'Unknown roast';
  }
  final roast = beansById[beanId]?.roastLevel?.trim();
  if (roast == null || roast.isEmpty) {
    return 'Unknown roast';
  }
  return roast;
}

String _beanLabelForShot(Shot shot, Map<String, Bean> beansById) {
  final beanId = shot.beanId;
  if (beanId == null) {
    return 'Unlinked';
  }
  final name = beansById[beanId]?.name.trim();
  if (name == null || name.isEmpty) {
    return beanId;
  }
  return name;
}

String _dayKey(DateTime startedAt) {
  final local = startedAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

List<InsightsBarEntry> _averageEntries(
  Map<String, List<double>> grouped, {
  required String suffix,
}) {
  final entries = <InsightsBarEntry>[];
  for (final entry in grouped.entries) {
    final values = entry.value;
    if (values.isEmpty) {
      continue;
    }
    final avg = values.reduce((a, b) => a + b) / values.length;
    entries.add(
      InsightsBarEntry(
        label: entry.key,
        value: avg,
        sampleCount: values.length,
      ),
    );
  }

  entries.sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

List<InsightsBarEntry> _sortedDayCounts(Map<String, int> countByDay) {
  final keys = countByDay.keys.toList()..sort();
  return [
    for (final key in keys)
      InsightsBarEntry(
        label: key,
        value: countByDay[key]!.toDouble(),
        sampleCount: countByDay[key]!,
      ),
  ];
}

/// Library insights: trend stats from saved shots.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({
    super.key,
    this.shotRepository,
    this.beanRepository,
  });

  /// Optional repository overrides for tests or dependency injection.
  final ShotRepository? shotRepository;
  final BeanRepository? beanRepository;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  ShotRepository? _shotRepository;
  BeanRepository? _beanRepository;
  FlowlogDatabase? _database;
  bool _ownsRepositories = false;
  late Future<InsightsSnapshot> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _insightsFuture = _loadInsights();
  }

  Future<({ShotRepository shots, BeanRepository beans})> _ensureRepositories() async {
    if (widget.shotRepository != null && widget.beanRepository != null) {
      return (shots: widget.shotRepository!, beans: widget.beanRepository!);
    }
    if (_shotRepository != null && _beanRepository != null) {
      return (shots: _shotRepository!, beans: _beanRepository!);
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _shotRepository = ShotRepository(_database!);
    _beanRepository = BeanRepository(_database!);
    _ownsRepositories = true;
    return (shots: _shotRepository!, beans: _beanRepository!);
  }

  Future<InsightsSnapshot> _loadInsights() async {
    final repos = await _ensureRepositories();
    final shots = await repos.shots.listShots(includeSamples: true);
    final beans = await repos.beans.listBeans();
    return computeInsights(shots: shots, beans: beans);
  }

  Future<void> _refresh() async {
    setState(() {
      _insightsFuture = _loadInsights();
    });
    await _insightsFuture;
  }

  @override
  void dispose() {
    if (_ownsRepositories) {
      _database?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InsightsSnapshot>(
      future: _insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load insights: ${snapshot.error}'),
          );
        }

        final insights = snapshot.data ?? const InsightsSnapshot(
          avgPeakPressureByRoast: [],
          avgTasteByBean: [],
          shotCountByDay: [],
        );

        if (!insights.hasData) {
          return const Center(
            key: Key('insights_empty'),
            child: Text('Save shots to see trends'),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const Key('insights_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              InsightsBarSection(
                key: const Key('insights_peak_by_roast'),
                title: 'Avg peak pressure by roast',
                subtitle: 'Bar average across linked shots',
                entries: insights.avgPeakPressureByRoast,
                valueFormatter: (value) => '${value.toStringAsFixed(1)} bar',
                emptyMessage: 'No pressure samples with roast data',
                barColor: FlowlogColors.espresso,
              ),
              const SizedBox(height: 20),
              InsightsBarSection(
                key: const Key('insights_taste_by_bean'),
                title: 'Avg taste by bean',
                subtitle: 'Rated shots only (0–10)',
                entries: insights.avgTasteByBean,
                valueFormatter: (value) => '${value.toStringAsFixed(1)}/10',
                valueMax: 10,
                emptyMessage: 'No taste ratings yet',
                barColor: FlowlogColors.crema,
              ),
              const SizedBox(height: 20),
              InsightsBarSection(
                key: const Key('insights_shots_over_time'),
                title: 'Shots over time',
                subtitle: 'Daily shot count',
                entries: insights.shotCountByDay,
                valueFormatter: (value) => value.round().toString(),
                emptyMessage: 'No shots recorded',
                barColor: FlowlogColors.espresso,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Section with a title and a simple horizontal bar chart.
class InsightsBarSection extends StatelessWidget {
  const InsightsBarSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.valueFormatter,
    required this.emptyMessage,
    required this.barColor,
    this.valueMax,
  });

  final String title;
  final String subtitle;
  final List<InsightsBarEntry> entries;
  final String Function(double value) valueFormatter;
  final String emptyMessage;
  final Color barColor;
  final double? valueMax;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text(emptyMessage, style: theme.textTheme.bodyMedium)
            else
              SimpleBarChart(
                entries: entries,
                valueFormatter: valueFormatter,
                barColor: barColor,
                valueMax: valueMax,
              ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight horizontal bar chart without external chart dependencies.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.entries,
    required this.valueFormatter,
    required this.barColor,
    this.valueMax,
    this.barHeight = 10,
  });

  final List<InsightsBarEntry> entries;
  final String Function(double value) valueFormatter;
  final Color barColor;
  final double? valueMax;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = valueMax ??
        entries.fold<double>(
          1,
          (current, entry) => entry.value > current ? entry.value : current,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          SimpleBarRow(
            key: Key('insights_bar_${entries[i].label}'),
            entry: entries[i],
            maxValue: maxValue,
            valueFormatter: valueFormatter,
            barColor: barColor,
            barHeight: barHeight,
            labelStyle: theme.textTheme.bodyMedium,
            valueStyle: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// Single labeled bar row.
class SimpleBarRow extends StatelessWidget {
  const SimpleBarRow({
    super.key,
    required this.entry,
    required this.maxValue,
    required this.valueFormatter,
    required this.barColor,
    required this.barHeight,
    required this.labelStyle,
    required this.valueStyle,
  });

  final InsightsBarEntry entry;
  final double maxValue;
  final String Function(double value) valueFormatter;
  final Color barColor;
  final double barHeight;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = (entry.value / maxValue).clamp(0.0, 1.0);
    final countLabel = entry.sampleCount > 0 ? ' (${entry.sampleCount})' : '';

    return Semantics(
      label: '${entry.label}: ${valueFormatter(entry.value)}$countLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(entry.label, style: labelStyle)),
              Text(
                '${valueFormatter(entry.value)}$countLabel',
                style: valueStyle,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(barHeight / 2),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: barHeight,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}