import 'dart:io';

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// A rule-based tweak suggestion derived from taste note keywords.
@immutable
class TweakSuggestion {
  const TweakSuggestion({
    required this.keyword,
    required this.title,
    required this.hint,
  });

  final String keyword;
  final String title;
  final String hint;
}

/// Kind of curve anomaly detected in shot samples.
enum CurveAnomalyKind {
  suddenPressureDrop,
  flatFlow,
  earlyHighFlow,
}

/// Anomaly hint from analyzing a shot's pressure/flow curve.
@immutable
class CurveAnomalyHint {
  const CurveAnomalyHint({
    required this.kind,
    required this.title,
    required this.description,
    this.elapsedMs,
  });

  final CurveAnomalyKind kind;
  final String title;
  final String description;
  final int? elapsedMs;
}

/// Keyword → tweak rules for taste-note coaching (stub, no ML).
const _tasteTweakRules = <String, TweakSuggestion>{
  'sour': TweakSuggestion(
    keyword: 'sour',
    title: 'Sour / under-extracted',
    hint: 'Try a finer grind or slightly higher brew temperature.',
  ),
  'under': TweakSuggestion(
    keyword: 'under',
    title: 'Under-extracted',
    hint: 'Extend the shot slightly or grind finer to increase extraction.',
  ),
  'bitter': TweakSuggestion(
    keyword: 'bitter',
    title: 'Bitter / over-extracted',
    hint: 'Try a coarser grind, lower temperature, or shorten the shot.',
  ),
  'harsh': TweakSuggestion(
    keyword: 'harsh',
    title: 'Harsh finish',
    hint: 'Reduce extraction: coarser grind or stop the shot a few grams earlier.',
  ),
  'thin': TweakSuggestion(
    keyword: 'thin',
    title: 'Thin body',
    hint: 'Grind finer or pull a slightly longer ratio for more solubles.',
  ),
  'watery': TweakSuggestion(
    keyword: 'watery',
    title: 'Watery cup',
    hint: 'Increase dose or grind finer; check that puck resistance is adequate.',
  ),
  'channeling': TweakSuggestion(
    keyword: 'channeling',
    title: 'Channeling',
    hint: 'WDT the puck, level and tamp evenly, and consider a slightly lower dose.',
  ),
  'channel': TweakSuggestion(
    keyword: 'channel',
    title: 'Possible channeling',
    hint: 'Review puck prep (WDT, distribution) and avoid knocking the portafilter.',
  ),
};

/// Returns tweak suggestions matching keywords in [tasteNotes] (case-insensitive).
List<TweakSuggestion> suggestTweaksFromTasteNotes(String tasteNotes) {
  final normalized = tasteNotes.trim().toLowerCase();
  if (normalized.isEmpty) {
    return const [];
  }

  final rules = _tasteTweakRules.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));

  final matches = <TweakSuggestion>[];
  final matchedKeywords = <String>{};

  for (final rule in rules) {
    if (!normalized.contains(rule.key)) {
      continue;
    }

    final overshadowed = matchedKeywords.any(
      (matched) => matched.contains(rule.key) && matched != rule.key,
    );
    if (overshadowed) {
      continue;
    }

    matchedKeywords.add(rule.key);
    matches.add(rule.value);
  }

  return matches;
}

/// Analyzes [samples] for pressure/flow anomalies (rule-based stub).
List<CurveAnomalyHint> detectCurveAnomalies(List<ShotSample> samples) {
  if (samples.length < 2) {
    return const [];
  }

  final hints = <CurveAnomalyHint>[];

  for (var i = 1; i < samples.length; i++) {
    final previous = samples[i - 1];
    final current = samples[i];
    final prevPressure = previous.pressureBar;
    final currentPressure = current.pressureBar;

    if (prevPressure != null &&
        currentPressure != null &&
        prevPressure >= 4.0 &&
        prevPressure - currentPressure >= 2.0 &&
        current.elapsedMs - previous.elapsedMs <= 2000) {
      hints.add(
        CurveAnomalyHint(
          kind: CurveAnomalyKind.suddenPressureDrop,
          title: 'Sudden pressure drop',
          description:
              'Pressure fell ${(prevPressure - currentPressure).toStringAsFixed(1)} bar '
              'between ${previous.elapsedMs} ms and ${current.elapsedMs} ms — '
              'check for channeling or a puck crack.',
          elapsedMs: current.elapsedMs,
        ),
      );
      break;
    }
  }

  if (_hasFlatFlow(samples)) {
    hints.add(
      const CurveAnomalyHint(
        kind: CurveAnomalyKind.flatFlow,
        title: 'Flat flow plateau',
        description:
            'Flow rate stayed nearly constant for several seconds — '
            'may indicate a choke or stalled extraction.',
      ),
    );
  }

  if (_hasEarlyHighFlow(samples)) {
    hints.add(
      const CurveAnomalyHint(
        kind: CurveAnomalyKind.earlyHighFlow,
        title: 'Early high flow',
        description:
            'High flow in the first 10 s can signal blonding or channeling — '
            'review grind and puck prep.',
      ),
    );
  }

  return hints;
}

bool _hasFlatFlow(List<ShotSample> samples) {
  const minSpanMs = 5000;
  const toleranceGs = 0.08;
  const minSamples = 3;

  var runStart = 0;
  for (var i = 1; i < samples.length; i++) {
    final prevFlow = samples[i - 1].flowGs;
    final currentFlow = samples[i].flowGs;
    if (prevFlow == null || currentFlow == null) {
      runStart = i;
      continue;
    }

    if ((prevFlow - currentFlow).abs() > toleranceGs) {
      runStart = i;
      continue;
    }

    final spanMs = samples[i].elapsedMs - samples[runStart].elapsedMs;
    final runLength = i - runStart + 1;
    if (runLength >= minSamples && spanMs >= minSpanMs && prevFlow > 0.1) {
      return true;
    }
  }

  return false;
}

bool _hasEarlyHighFlow(List<ShotSample> samples) {
  const earlyWindowMs = 10000;
  const highFlowThreshold = 2.5;

  for (final sample in samples) {
    if (sample.elapsedMs > earlyWindowMs) {
      break;
    }
    final flow = sample.flowGs;
    if (flow != null && flow >= highFlowThreshold) {
      return true;
    }
  }

  return false;
}

/// Library AI coach: taste-note tweaks and curve anomaly hints.
class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({
    super.key,
    this.shotRepository,
  });

  /// Optional repository override for tests or dependency injection.
  final ShotRepository? shotRepository;

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  ShotRepository? _shotRepository;
  FlowlogDatabase? _database;

  late Future<Shot?> _latestShotFuture;
  final _tasteNotesController = TextEditingController();
  List<TweakSuggestion> _tweakSuggestions = const [];
  List<CurveAnomalyHint> _anomalyHints = const [];

  @override
  void initState() {
    super.initState();
    _tasteNotesController.addListener(_onTasteNotesChanged);
    _latestShotFuture = _loadLatestShot();
  }

  void _onTasteNotesChanged() {
    setState(() {
      _tweakSuggestions = suggestTweaksFromTasteNotes(_tasteNotesController.text);
    });
  }

  Future<ShotRepository> _ensureRepository() async {
    if (widget.shotRepository != null) {
      return widget.shotRepository!;
    }
    if (_shotRepository != null) {
      return _shotRepository!;
    }

    _database = await openFlowlogDatabase();
    _shotRepository = ShotRepository(_database!);
    return _shotRepository!;
  }

  Future<Shot?> _loadLatestShot() async {
    final repository = await _ensureRepository();
    final shots = await repository.listShots(includeSamples: true);
    if (shots.isEmpty) {
      return null;
    }

    shots.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final latest = shots.first;

    if (mounted) {
      final notes = latest.notes?.trim();
      if (notes != null &&
          notes.isNotEmpty &&
          _tasteNotesController.text.trim().isEmpty) {
        _tasteNotesController.text = notes;
      }
      setState(() {
        _anomalyHints = detectCurveAnomalies(latest.samples);
      });
    }

    return latest;
  }

  Future<void> _refresh() async {
    setState(() {
      _latestShotFuture = _loadLatestShot();
    });
    await _latestShotFuture;
  }

  @override
  void dispose() {
    _tasteNotesController
      ..removeListener(_onTasteNotesChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Shot?>(
      future: _latestShotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load AI insights: ${snapshot.error}'),
          );
        }

        final latestShot = snapshot.data;
        final hasShot = latestShot != null && latestShot.samples.isNotEmpty;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            key: const Key('ai_insights_list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              AiInsightsTasteNotesCard(
                key: const Key('ai_insights_taste_notes'),
                controller: _tasteNotesController,
              ),
              const SizedBox(height: 20),
              AiInsightsSuggestionsCard(
                key: const Key('ai_insights_tweaks'),
                title: 'Tweak suggestions',
                subtitle: 'Rule-based hints from your taste notes',
                emptyMessage: 'Describe taste (e.g. sour, bitter, thin) for ideas',
                suggestions: _tweakSuggestions,
                accentColor: FlowlogColors.crema,
              ),
              const SizedBox(height: 20),
              AiInsightsAnomaliesCard(
                key: const Key('ai_insights_anomalies'),
                hints: _anomalyHints,
                shotLabel: hasShot ? _shotLabel(latestShot!) : null,
                emptyMessage: hasShot
                    ? 'No curve anomalies detected in the latest shot'
                    : 'Save a shot with samples to analyze the curve',
              ),
            ],
          ),
        );
      },
    );
  }
}

String _shotLabel(Shot shot) {
  final local = shot.startedAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

/// Taste notes input for AI coach suggestions.
class AiInsightsTasteNotesCard extends StatelessWidget {
  const AiInsightsTasteNotesCard({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Taste notes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Describe the cup — keywords drive tweak suggestions',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai_insights_taste_notes_field'),
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. a bit sour with thin body and some channeling',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card listing rule-based tweak suggestions.
class AiInsightsSuggestionsCard extends StatelessWidget {
  const AiInsightsSuggestionsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emptyMessage,
    required this.suggestions,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final String emptyMessage;
  final List<TweakSuggestion> suggestions;
  final Color accentColor;

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
            if (suggestions.isEmpty)
              Text(emptyMessage, style: theme.textTheme.bodyMedium)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < suggestions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    AiInsightSuggestionRow(
                      key: Key('ai_insights_tweak_${suggestions[i].keyword}'),
                      suggestion: suggestions[i],
                      accentColor: accentColor,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Single tweak suggestion row.
class AiInsightSuggestionRow extends StatelessWidget {
  const AiInsightSuggestionRow({
    super.key,
    required this.suggestion,
    required this.accentColor,
  });

  final TweakSuggestion suggestion;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${suggestion.title}: ${suggestion.hint}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(suggestion.hint, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card listing curve anomaly hints from the latest shot.
class AiInsightsAnomaliesCard extends StatelessWidget {
  const AiInsightsAnomaliesCard({
    super.key,
    required this.hints,
    required this.emptyMessage,
    this.shotLabel,
  });

  final List<CurveAnomalyHint> hints;
  final String emptyMessage;
  final String? shotLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Curve anomalies', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              shotLabel == null
                  ? 'Analyze pressure and flow from your latest shot'
                  : 'From latest shot ($shotLabel)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (hints.isEmpty)
              Text(
                emptyMessage,
                key: const Key('ai_insights_anomalies_empty'),
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < hints.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    AiInsightAnomalyRow(
                      key: Key('ai_insights_anomaly_${hints[i].kind.name}'),
                      hint: hints[i],
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Single anomaly hint row.
class AiInsightAnomalyRow extends StatelessWidget {
  const AiInsightAnomalyRow({
    super.key,
    required this.hint,
  });

  final CurveAnomalyHint hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '${hint.title}: ${hint.description}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _iconForAnomaly(hint.kind),
            color: FlowlogColors.espresso,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hint.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(hint.description, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForAnomaly(CurveAnomalyKind kind) {
  return switch (kind) {
    CurveAnomalyKind.suddenPressureDrop => Icons.trending_down,
    CurveAnomalyKind.flatFlow => Icons.horizontal_rule,
    CurveAnomalyKind.earlyHighFlow => Icons.water_drop_outlined,
  };
}