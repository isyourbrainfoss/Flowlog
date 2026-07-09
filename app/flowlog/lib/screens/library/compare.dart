import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/history/history_shot_card.dart';
import 'package:flowlog/screens/live/save_shot.dart';
import 'package:flowlog/settings/brew_defaults_store.dart';
import 'package:flowlog/widgets/fullscreen_plot.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Distinct colors for overlaid shot pressure curves.
List<Color> get compareShotPalette => [
      FlowlogChartColors.pressureLine,
      FlowlogChartColors.weightLine,
      FlowlogChartColors.flowLine,
      const Color(0xFFE8786A),
      const Color(0xFF9B7EDE),
      const Color(0xFFF2C94C),
    ];

/// Picks [index] from [compareShotPalette].
Color compareShotColor(int index) {
  final palette = compareShotPalette;
  return palette[index % palette.length];
}

/// Compare saved shots by overlaying pressure curves on a shared time axis.
class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    this.shotRepository,
  });

  /// Optional repository override for tests or dependency injection.
  final ShotRepository? shotRepository;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  ShotRepository? _shotRepository;
  FlowlogDatabase? _database;

  late Future<List<Shot>> _shotsFuture;
  final List<String> _selectedShotIds = [];
  bool _showDeltaHighlight = false;

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

    _database = await openFlowlogDatabase();
    _shotRepository = ShotRepository(_database!);
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

  void _toggleShotSelection(Shot shot, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedShotIds.contains(shot.id)) {
          _selectedShotIds.add(shot.id);
        }
      } else {
        _selectedShotIds.remove(shot.id);
      }
    });
  }

  List<Shot> _selectedShots(List<Shot> allShots) {
    final byId = {for (final shot in allShots) shot.id: shot};
    return [
      for (final id in _selectedShotIds)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  @override
  void dispose() {
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
        final selectedShots = _selectedShots(shots);

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedShots.length >= 2)
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FullscreenPlotButton(
                          buttonKey: const Key('compare_fullscreen_open'),
                          onPressed: () => unawaited(
                            openCompareFullscreenChart(
                              context,
                              shots: selectedShots,
                              showDeltaHighlight: _showDeltaHighlight,
                            ),
                          ),
                        ),
                        CompareOverlayChart(
                          key: const Key('compare_overlay_chart'),
                          shots: selectedShots,
                          showDeltaHighlight: _showDeltaHighlight,
                        ),
                        SwitchListTile(
                          key: const Key('compare_delta_toggle'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Delta highlight'),
                          subtitle: const Text(
                            'Shade pressure difference between first two selections',
                          ),
                          value: _showDeltaHighlight,
                          onChanged: (value) {
                            setState(() => _showDeltaHighlight = value);
                          },
                        ),
                        _CompareLegend(shots: selectedShots),
                        const SizedBox(height: 12),
                        _CompareMetadataTable(shots: selectedShots),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    shots.length < 2
                        ? 'Save at least two shots to compare'
                        : 'Select 2 or more shots to compare',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (_selectedShotIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedShotIds.length} selected',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const Spacer(),
                      TextButton(
                        key: const Key('compare_clear_all'),
                        onPressed: () {
                          setState(() {
                            _selectedShotIds.clear();
                            _showDeltaHighlight = false;
                          });
                        },
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                flex: selectedShots.length >= 2 ? 4 : 1,
                child: shots.isEmpty
                    ? const Center(child: Text('No saved shots yet'))
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: shots.length,
                          itemBuilder: (context, index) {
                            final shot = shots[index];
                            final isSelected =
                                _selectedShotIds.contains(shot.id);
                            return CheckboxListTile(
                              key: Key('compare_select_${shot.id}'),
                              value: isSelected,
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                _toggleShotSelection(shot, value);
                              },
                              title: Text(_formatStartedAt(shot.startedAt)),
                              subtitle: Text(
                                [
                                  _formatPeakPressure(shot.samples),
                                  _formatYield(shot.yieldG),
                                  _formatTasteScore(shot.tasteScore),
                                ].join(' · '),
                              ),
                              secondary: const Icon(Icons.show_chart),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
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

  static String _formatPeakPressure(List<ShotSample> samples) {
    final peak = HistoryShotCard.peakPressureBar(samples);
    if (peak == null) {
      return 'Peak —';
    }
    return 'Peak ${peak.toStringAsFixed(1)} bar';
  }

  static String _formatYield(double? yieldG) {
    if (yieldG == null) {
      return 'Yield —';
    }
    return 'Yield ${yieldG.toStringAsFixed(1)} g';
  }

  static String _formatTasteScore(int? tasteScore) {
    if (tasteScore == null) {
      return 'Taste —';
    }
    return 'Taste $tasteScore/10';
  }
}

/// Opens a fullscreen compare overlay chart.
Future<void> openCompareFullscreenChart(
  BuildContext context, {
  required List<Shot> shots,
  required bool showDeltaHighlight,
}) {
  return openFullscreenPlot(
    context,
    scaffoldKey: const Key('compare_fullscreen_chart'),
    closeButtonKey: const Key('compare_fullscreen_close'),
    builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        const footerReserve = 36.0;
        return SizedBox(
          height: constraints.maxHeight,
          child: CompareOverlayChart(
            key: const Key('compare_fullscreen_overlay_chart'),
            shots: shots,
            showDeltaHighlight: showDeltaHighlight,
            height: math.max(1, constraints.maxHeight - footerReserve),
          ),
        );
      },
    ),
  );
}

class _CompareMetadataTable extends StatelessWidget {
  const _CompareMetadataTable({required this.shots});

  final List<Shot> shots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('compare_metadata_table'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Metadata', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 72,
                columns: [
                  const DataColumn(label: Text('')),
                  for (var i = 0; i < shots.length; i++)
                    DataColumn(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: compareShotColor(i),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Shot ${i + 1}'),
                        ],
                      ),
                    ),
                ],
                rows: [
                  _metadataRow('Dose', shots.map(_formatDose)),
                  _metadataRow('Yield', shots.map(_formatYieldCell)),
                  _metadataRow('Ratio', shots.map(_formatRatio)),
                  _metadataRow('Grind', shots.map(_formatGrind)),
                  _metadataRow('Water temp', shots.map(_formatWaterTemp)),
                  _metadataRow('Taste', shots.map(_formatTasteCell)),
                  _metadataRow('Flavour tags', shots.map(_formatFlavourTags)),
                  _metadataRow('Notes', shots.map(_formatNotes)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _metadataRow(String label, Iterable<String> values) {
    return DataRow(
      cells: [
        DataCell(Text(label)),
        for (final value in values) DataCell(Text(value)),
      ],
    );
  }

  static String _formatDose(Shot shot) {
    final dose = shot.doseG;
    if (dose == null) {
      return '—';
    }
    return '${dose.toStringAsFixed(1)} g';
  }

  static String _formatYieldCell(Shot shot) {
    final yield = inferredYieldG(shot);
    if (yield == null) {
      return '—';
    }
    return '${yield.toStringAsFixed(1)} g';
  }

  static String _formatRatio(Shot shot) {
    final dose = shot.doseG;
    final yield = inferredYieldG(shot);
    if (dose == null || yield == null || dose <= 0) {
      return '—';
    }
    return '1:${(yield / dose).toStringAsFixed(1)}';
  }

  static String _formatGrind(Shot shot) {
    return formatGrindSetting(shot.grindSetting);
  }

  static String _formatWaterTemp(Shot shot) {
    final temp = shot.waterTempC ??
        (shot.samples.isNotEmpty ? shot.samples.last.tempC : null);
    if (temp == null) {
      return '—';
    }
    return '${temp.toStringAsFixed(1)} °C';
  }

  static String _formatTasteCell(Shot shot) {
    final taste = shot.tasteScore;
    if (taste == null) {
      return '—';
    }
    return '$taste/10';
  }

  static String _formatFlavourTags(Shot shot) {
    return formatFlavourProfileSummary(
      tags: shot.flavourTags,
      intensities: shot.flavourIntensities,
    );
  }

  static String _formatNotes(Shot shot) {
    final notes = shot.notes;
    if (notes == null || notes.trim().isEmpty) {
      return '—';
    }
    return notes;
  }
}

class _CompareLegend extends StatelessWidget {
  const _CompareLegend({required this.shots});

  final List<Shot> shots;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (var i = 0; i < shots.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: compareShotColor(i),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _legendLabel(shots[i], i),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }

  static String _legendLabel(Shot shot, int index) {
    final date = shot.startedAt.toLocal();
    final stamp =
        '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return 'Shot ${index + 1} ($stamp)';
  }
}

/// Overlays pressure curves for multiple shots using overlay chart styling.
class CompareOverlayChart extends StatefulWidget {
  const CompareOverlayChart({
    super.key,
    required this.shots,
    this.showDeltaHighlight = false,
    this.height = 220,
    this.enableInteraction = true,
  });

  final List<Shot> shots;
  final bool showDeltaHighlight;
  final double height;
  final bool enableInteraction;

  @override
  State<CompareOverlayChart> createState() => _CompareOverlayChartState();
}

class _CompareOverlayChartState extends State<CompareOverlayChart> {
  late ChartInteractionController _interactionController;

  @override
  void initState() {
    super.initState();
    _interactionController = ChartInteractionController(
      viewMode: ChartViewMode.overlay,
    );
    _interactionController.addListener(_onInteractionChanged);
  }

  @override
  void didUpdateWidget(covariant CompareOverlayChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDuration();
  }

  @override
  void dispose() {
    _interactionController.removeListener(_onInteractionChanged);
    _interactionController.dispose();
    super.dispose();
  }

  void _onInteractionChanged() {
    setState(() {});
  }

  void _syncDuration() {
    if (!widget.enableInteraction) {
      return;
    }
    _interactionController.syncTotalDuration(
      _totalDurationMs(widget.shots),
      followEndWhenZoomedOut: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncDuration();

    final preparedShots = [
      for (final shot in widget.shots)
        _PreparedCompareShot(
          shot: shot,
          samples: _prepareSamples(shot.samples),
        ),
    ];

    final viewport = widget.enableInteraction
        ? _interactionController.viewport
        : ChartViewport(totalDurationMs: _totalDurationMs(widget.shots));

    final chart = SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = _plotWidth(constraints.maxWidth);
          final body = CustomPaint(
            painter: CompareOverlayPainter(
              shots: preparedShots,
              viewport: viewport,
              showDeltaHighlight: widget.showDeltaHighlight,
            ),
          );

          if (!widget.enableInteraction) {
            return body;
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _interactionController.onScaleStart,
            onScaleUpdate: (details) =>
                _interactionController.onScaleUpdate(details, plotWidth),
            onScaleEnd: _interactionController.onScaleEnd,
            child: body,
          );
        },
      ),
    );

    return Semantics(
      label: 'Shot compare chart, overlay view',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          chart,
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Pressure',
                style: TextStyle(
                  color: FlowlogChartColors.axisLabel,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              const Text(
                'Overlay',
                style: TextStyle(
                  color: FlowlogChartColors.axisLabel,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<ShotSample> _prepareSamples(List<ShotSample> raw) {
    if (raw.isEmpty) {
      return raw;
    }
    final hasFlow = raw.any((sample) => sample.flowGs != null);
    if (hasFlow) {
      return List<ShotSample>.from(raw);
    }
    return computeFlowRates(raw);
  }

  static int _totalDurationMs(List<Shot> shots) {
    var total = 1;
    for (final shot in shots) {
      if (shot.endedAt != null) {
        total = math.max(
          total,
          shot.endedAt!.difference(shot.startedAt).inMilliseconds,
        );
      }
      for (final sample in shot.samples) {
        total = math.max(total, sample.elapsedMs);
      }
    }
    return math.max(total, 1);
  }

  static double _plotWidth(double width) {
    return math.max(
      1,
      width - CompareOverlayPainter.leftPad - CompareOverlayPainter.rightPad,
    );
  }
}

class _PreparedCompareShot {
  const _PreparedCompareShot({
    required this.shot,
    required this.samples,
  });

  final Shot shot;
  final List<ShotSample> samples;
}

/// Paints multiple shot pressure curves and an optional delta band.
class CompareOverlayPainter extends CustomPainter {
  CompareOverlayPainter({
    required this.shots,
    required this.viewport,
    this.showDeltaHighlight = false,
    this.backgroundColor = FlowlogChartColors.background,
  });

  final List<_PreparedCompareShot> shots;
  final ChartViewport viewport;
  final bool showDeltaHighlight;
  final Color backgroundColor;

  static const leftPad = 40.0;
  static const rightPad = 40.0;
  static const topPad = 12.0;
  static const bottomPad = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotRect = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(1, size.width - leftPad - rightPad),
      math.max(1, size.height - topPad - bottomPad),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = backgroundColor,
    );

    _drawGrid(canvas, plotRect);

    if (shots.isEmpty) {
      _drawEmptyLabel(canvas, plotRect);
      return;
    }

    final scales = _CompareScales.fromShots(shots, viewport: viewport);
    _drawAxes(canvas, plotRect, scales);

    if (showDeltaHighlight && shots.length >= 2) {
      _drawDeltaBand(canvas, plotRect, scales, shots[0], shots[1]);
    }

    for (var i = 0; i < shots.length; i++) {
      _drawPressureSeries(
        canvas,
        plotRect,
        scales,
        shots[i].samples,
        compareShotColor(i),
      );
    }
  }

  void _drawGrid(Canvas canvas, Rect plotRect) {
    final gridPaint = Paint()
      ..color = FlowlogChartColors.grid.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    const horizontalLines = 4;
    for (var i = 0; i <= horizontalLines; i++) {
      final y = plotRect.top + (plotRect.height / horizontalLines) * i;
      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        gridPaint,
      );
    }

    const verticalLines = 5;
    for (var i = 0; i <= verticalLines; i++) {
      final x = plotRect.left + (plotRect.width / verticalLines) * i;
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
    }
  }

  void _drawAxes(Canvas canvas, Rect plotRect, _CompareScales scales) {
    const textStyle = TextStyle(
      color: FlowlogChartColors.axisLabel,
      fontSize: 10,
    );

    _paintText(canvas, 'bar', const Offset(4, topPad), textStyle);

    final durationLabel = _formatDuration(scales.visibleEndMs);
    _paintText(
      canvas,
      durationLabel,
      Offset(plotRect.right - 28, plotRect.bottom + 6),
      textStyle,
    );
  }

  void _drawEmptyLabel(Canvas canvas, Rect plotRect) {
    _paintText(
      canvas,
      'No samples to compare',
      Offset(plotRect.left, plotRect.center.dy - 6),
      const TextStyle(
        color: FlowlogChartColors.axisLabel,
        fontSize: 12,
      ),
      maxWidth: plotRect.width,
      align: TextAlign.center,
    );
  }

  void _drawPressureSeries(
    Canvas canvas,
    Rect plotRect,
    _CompareScales scales,
    List<ShotSample> samples,
    Color color,
  ) {
    final points = <Offset>[];
    for (final sample in samples) {
      final pressure = sample.pressureBar;
      if (pressure == null) {
        continue;
      }
      if (sample.elapsedMs < scales.timeOffsetMs ||
          sample.elapsedMs > scales.visibleEndMs) {
        continue;
      }
      points.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: sample.elapsedMs,
        value: pressure,
      ));
    }

    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  void _drawDeltaBand(
    Canvas canvas,
    Rect plotRect,
    _CompareScales scales,
    _PreparedCompareShot baseline,
    _PreparedCompareShot comparison,
  ) {
    final times = <int>{
      for (final sample in baseline.samples) sample.elapsedMs,
      for (final sample in comparison.samples) sample.elapsedMs,
    }.where(
      (elapsedMs) =>
          elapsedMs >= scales.timeOffsetMs &&
          elapsedMs <= scales.visibleEndMs,
    ).toList()
      ..sort();

    if (times.length < 2) {
      return;
    }

    final upper = <Offset>[];
    final lower = <Offset>[];

    for (final elapsedMs in times) {
      final basePressure = _pressureAt(elapsedMs, baseline.samples);
      final comparePressure = _pressureAt(elapsedMs, comparison.samples);
      if (basePressure == null || comparePressure == null) {
        continue;
      }

      final high = math.max(basePressure, comparePressure);
      final low = math.min(basePressure, comparePressure);
      upper.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: elapsedMs,
        value: high,
      ));
      lower.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: elapsedMs,
        value: low,
      ));
    }

    if (upper.length < 2 || lower.length < 2) {
      return;
    }

    final fillPath = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (var i = 1; i < upper.length; i++) {
      fillPath.lineTo(upper[i].dx, upper[i].dy);
    }
    for (var i = lower.length - 1; i >= 0; i--) {
      fillPath.lineTo(lower[i].dx, lower[i].dy);
    }
    fillPath.close();

    final fillPaint = Paint()
      ..color = FlowlogChartColors.pressureHigh.withValues(alpha: 0.28);
    canvas.drawPath(fillPath, fillPaint);
  }

  static double? _pressureAt(int elapsedMs, List<ShotSample> samples) {
    if (samples.isEmpty) {
      return null;
    }

    ShotSample? before;
    ShotSample? after;
    for (final sample in samples) {
      if (sample.elapsedMs == elapsedMs) {
        return sample.pressureBar;
      }
      if (sample.elapsedMs < elapsedMs) {
        before = sample;
      } else if (sample.elapsedMs > elapsedMs) {
        after = sample;
        break;
      }
    }

    if (before == null || after == null) {
      return before?.pressureBar ?? after?.pressureBar;
    }

    final beforePressure = before.pressureBar;
    final afterPressure = after.pressureBar;
    if (beforePressure == null || afterPressure == null) {
      return beforePressure ?? afterPressure;
    }

    final span = after.elapsedMs - before.elapsedMs;
    if (span <= 0) {
      return beforePressure;
    }

    final t = (elapsedMs - before.elapsedMs) / span;
    return beforePressure + (afterPressure - beforePressure) * t;
  }

  Offset _pointFor(
    Rect plotRect,
    _CompareScales scales, {
    required int elapsedMs,
    required double value,
  }) {
    final normalizedTime =
        (elapsedMs - scales.timeOffsetMs) / scales.timeSpanMs;
    final x = plotRect.left + normalizedTime.clamp(0.0, 1.0) * plotRect.width;
    final y = plotRect.bottom -
        (value / scales.pressureMax).clamp(0.0, 1.0) * plotRect.height;
    return Offset(x, y);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double? maxWidth,
    TextAlign align = TextAlign.start,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    if (maxWidth != null) {
      painter.layout(maxWidth: maxWidth);
    } else {
      painter.layout();
    }
    painter.paint(canvas, offset);
  }

  String _formatDuration(int elapsedMs) {
    final seconds = (elapsedMs / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes == 0) {
      return '${remainingSeconds}s';
    }
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(covariant CompareOverlayPainter oldDelegate) {
    return oldDelegate.shots != shots ||
        oldDelegate.viewport != viewport ||
        oldDelegate.showDeltaHighlight != showDeltaHighlight ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

class _CompareScales {
  const _CompareScales({
    required this.timeOffsetMs,
    required this.timeSpanMs,
    required this.visibleEndMs,
    required this.pressureMax,
  });

  final int timeOffsetMs;
  final int timeSpanMs;
  final int visibleEndMs;
  final double pressureMax;

  factory _CompareScales.fromShots(
    List<_PreparedCompareShot> shots, {
    required ChartViewport viewport,
  }) {
    var pressureMax = 12.0;
    final windowStart = viewport.visibleStartMs;
    final windowEnd = viewport.visibleEndMs;

    for (final shot in shots) {
      for (final sample in shot.samples) {
        if (sample.elapsedMs < windowStart || sample.elapsedMs > windowEnd) {
          continue;
        }
        final pressure = sample.pressureBar;
        if (pressure != null) {
          pressureMax = math.max(pressureMax, pressure * 1.1);
        }
      }
    }

    return _CompareScales(
      timeOffsetMs: viewport.visibleStartMs,
      timeSpanMs: math.max(viewport.visibleDurationMs, 1),
      visibleEndMs: viewport.visibleEndMs,
      pressureMax: pressureMax,
    );
  }
}