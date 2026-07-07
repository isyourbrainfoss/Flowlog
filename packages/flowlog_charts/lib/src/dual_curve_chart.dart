import 'dart:math' as math;
import 'dart:ui' as ui;

import 'chart_annotations.dart';
import 'chart_interaction.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';

/// Gap between the plot and the legend row.
const double kDualCurveChartLegendGap = 8;

/// Conservative estimate for legend + view-mode picker height.
double dualCurveChartLegendReserve({
  required bool interactive,
  double textScale = 1.0,
}) {
  final base = interactive ? 108.0 : 36.0;
  return (base * textScale).clamp(base, base * 1.6);
}

/// Back-compat alias used by fullscreen layouts.
double get kDualCurveChartLegendReserve =>
    dualCurveChartLegendReserve(interactive: true);

/// Chart color palettes for espresso curves.
enum FlowlogChartPalette {
  /// Warm coffee tones aligned with [FlowlogColors] in the app theme.
  coffee,

  /// Wong-inspired palette distinguishable with common colour-vision deficiencies.
  colorblindSafe,
}

/// Chart colors for pressure, weight, and flow curves.
///
/// Set [palette] to switch between the coffee theme and a colour-blind safe set.
/// Line colors are exposed as getters so they follow the active palette.
abstract final class FlowlogChartColors {
  static FlowlogChartPalette palette = FlowlogChartPalette.coffee;

  static const coffeePressureLow = Color(0xFF6B9E5A);
  static const coffeePressureHigh = Color(0xFFE8A54B);
  static const coffeePressureLine = Color(0xFFD4923A);
  static const coffeeWeightLine = Color(0xFF5B8DB8);
  static const coffeeFlowLine = Color(0xFF4ECDC4);
  static const coffeeTargetPressureLine = Color(0xFFE8E0D8);

  static const colorblindPressureLow = Color(0xFF56B4E9);
  static const colorblindPressureHigh = Color(0xFFE69F00);
  static const colorblindPressureLine = Color(0xFFD55E00);
  static const colorblindWeightLine = Color(0xFF0072B2);
  static const colorblindFlowLine = Color(0xFF009E73);
  static const colorblindTargetPressureLine = Color(0xFFCC79A7);

  static Color get pressureLow => _lineColor(
        coffee: coffeePressureLow,
        colorblindSafe: colorblindPressureLow,
      );

  static Color get pressureHigh => _lineColor(
        coffee: coffeePressureHigh,
        colorblindSafe: colorblindPressureHigh,
      );

  static Color get pressureLine => _lineColor(
        coffee: coffeePressureLine,
        colorblindSafe: colorblindPressureLine,
      );

  static Color get weightLine => _lineColor(
        coffee: coffeeWeightLine,
        colorblindSafe: colorblindWeightLine,
      );

  static Color get flowLine => _lineColor(
        coffee: coffeeFlowLine,
        colorblindSafe: colorblindFlowLine,
      );

  static Color get targetPressureLine => _lineColor(
        coffee: coffeeTargetPressureLine,
        colorblindSafe: colorblindTargetPressureLine,
      );

  static const grid = Color(0xFF9A8B7E);
  static const axisLabel = Color(0xFFD4C9BC);
  static const background = Color(0xFF241C16);

  static Color _lineColor({
    required Color coffee,
    required Color colorblindSafe,
  }) {
    return palette == FlowlogChartPalette.colorblindSafe
        ? colorblindSafe
        : coffee;
  }
}

/// Plot surface colors resolved from the active [ColorScheme].
@immutable
class ChartSurfaceStyle {
  const ChartSurfaceStyle({
    required this.background,
    required this.grid,
    required this.axisLabel,
  });

  final Color background;
  final Color grid;
  final Color axisLabel;

  /// Uses coffee-dark constants in dark mode; theme tokens in light mode.
  static ChartSurfaceStyle fromColorScheme(ColorScheme scheme) {
    if (scheme.brightness == Brightness.dark) {
      return const ChartSurfaceStyle(
        background: FlowlogChartColors.background,
        grid: FlowlogChartColors.grid,
        axisLabel: FlowlogChartColors.axisLabel,
      );
    }

    return ChartSurfaceStyle(
      background: scheme.surface,
      grid: scheme.outline,
      axisLabel: scheme.onSurfaceVariant,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChartSurfaceStyle &&
            background == other.background &&
            grid == other.grid &&
            axisLabel == other.axisLabel;
  }

  @override
  int get hashCode => Object.hash(background, grid, axisLabel);
}

/// Live dual-axis chart for espresso pressure, weight, and flow.
///
/// Provide either a static [samples] list or a live [samplesNotifier] stream.
/// When [enableInteraction] is true (default), supports pinch/zoom, pan, and
/// swipe (or [ChartInteractionController.setViewMode]) for overlay/split/flow-only.
class DualCurveChart extends StatefulWidget {
  const DualCurveChart({
    super.key,
    this.samples,
    this.samplesNotifier,
    this.height = 220,
    this.maxDurationMs,
    this.showPressure = true,
    this.showWeight = true,
    this.showFlow = true,
    this.backgroundColor,
    this.enableInteraction = true,
    this.interactionController,
    this.initialViewMode = ChartViewMode.overlay,
    this.annotations,
    this.annotationsNotifier,
    this.onAnnotateAtElapsedMs,
    this.targetPressureSamples = const [],
    this.denseTimeAxis = false,
    this.enableCrosshair = false,
  }) : assert(
          samples != null || samplesNotifier != null,
          'Provide samples or samplesNotifier',
        );

  /// Static sample list (e.g. replayed or saved shot).
  final List<ShotSample>? samples;

  /// Live sample stream; rebuilds when the notifier changes.
  final ValueNotifier<List<ShotSample>>? samplesNotifier;

  /// Chart height in logical pixels.
  final double height;

  /// Optional fixed X-axis duration; defaults to latest sample time.
  final int? maxDurationMs;

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;

  /// When null, follows [Theme.of] via [ChartSurfaceStyle].
  final Color? backgroundColor;

  /// Pinch/zoom, pan, and swipe view-mode gestures.
  final bool enableInteraction;

  /// Optional external controller for view mode and viewport.
  final ChartInteractionController? interactionController;

  /// Initial layout when no external controller is supplied.
  final ChartViewMode initialViewMode;

  /// Static annotation markers (e.g. saved shot detail).
  final List<ShotAnnotation>? annotations;

  /// Live annotation stream for in-progress sessions.
  final ValueNotifier<List<ShotAnnotation>>? annotationsNotifier;

  /// Called when the user long-presses the chart to add a note.
  final void Function(int elapsedMs)? onAnnotateAtElapsedMs;

  /// Reference pressure curve drawn as a dashed overlay (repeat-shot target).
  final List<ShotSample> targetPressureSamples;

  /// When true, draws more frequent time ticks on the X axis (live brew).
  final bool denseTimeAxis;

  /// Tap to place a crosshair that snaps to the nearest sample.
  final bool enableCrosshair;

  @override
  State<DualCurveChart> createState() => _DualCurveChartState();
}

class _DualCurveChartState extends State<DualCurveChart> {
  late ChartInteractionController _interactionController;
  bool _ownsInteractionController = false;

  @override
  void initState() {
    super.initState();
    _ownsInteractionController = widget.interactionController == null;
    _interactionController = widget.interactionController ??
        ChartInteractionController(viewMode: widget.initialViewMode);
    _interactionController.addListener(_onInteractionChanged);
  }

  @override
  void didUpdateWidget(covariant DualCurveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.interactionController != widget.interactionController) {
      _interactionController.removeListener(_onInteractionChanged);
      if (_ownsInteractionController) {
        _interactionController.dispose();
      }
      _ownsInteractionController = widget.interactionController == null;
      _interactionController = widget.interactionController ??
          ChartInteractionController(viewMode: widget.initialViewMode);
      _interactionController.addListener(_onInteractionChanged);
    }
  }

  @override
  void dispose() {
    _interactionController.removeListener(_onInteractionChanged);
    if (_ownsInteractionController) {
      _interactionController.dispose();
    }
    super.dispose();
  }

  void _onInteractionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.samplesNotifier != null) {
      return ValueListenableBuilder<List<ShotSample>>(
        valueListenable: widget.samplesNotifier!,
        builder: (context, samples, _) =>
            _buildWithAnnotations(context, samples),
      );
    }
    return _buildWithAnnotations(context, widget.samples!);
  }

  Widget _buildWithAnnotations(BuildContext context, List<ShotSample> samples) {
    if (widget.annotationsNotifier != null) {
      return ValueListenableBuilder<List<ShotAnnotation>>(
        valueListenable: widget.annotationsNotifier!,
        builder: (context, annotations, _) =>
            _buildChart(context, samples, annotations),
      );
    }
    return _buildChart(
      context,
      samples,
      widget.annotations ?? const [],
    );
  }

  Widget _buildChart(
    BuildContext context,
    List<ShotSample> rawSamples,
    List<ShotAnnotation> annotations,
  ) {
    final themeStyle = ChartSurfaceStyle.fromColorScheme(
      Theme.of(context).colorScheme,
    );
    final surfaceStyle = ChartSurfaceStyle(
      background: widget.backgroundColor ?? themeStyle.background,
      grid: themeStyle.grid,
      axisLabel: themeStyle.axisLabel,
    );
    final prepared = _prepareSamples(rawSamples);
    final totalDurationMs = _resolveTotalDurationMs(prepared);

    if (widget.enableInteraction) {
      _interactionController.syncTotalDuration(
        totalDurationMs,
        followEndWhenZoomedOut: widget.samplesNotifier != null,
      );
    }

    final viewMode = widget.enableInteraction
        ? _interactionController.viewMode
        : ChartViewMode.overlay;
    final viewport = widget.enableInteraction
        ? _interactionController.viewport
        : ChartViewport(totalDurationMs: totalDurationMs);

    final visibility = _visibilityForMode(
      viewMode: viewMode,
      showPressure: widget.showPressure,
      showWeight: widget.showWeight,
      showFlow: widget.showFlow,
    );

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return RepaintBoundary(
      child: Semantics(
        label: widget.enableInteraction
            ? '${_semanticsLabel(viewMode)}. Swipe left or right to change view.'
            : _semanticsLabel(viewMode),
        child: LayoutBuilder(
          builder: (context, outerConstraints) {
            final boundedHeight = outerConstraints.maxHeight.isFinite;
            final plotHeight = boundedHeight
                ? null
                : widget.height;

            Widget plotArea({required double height}) {
              return SizedBox(
                height: height,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final plotWidth = _plotWidth(constraints.maxWidth);
                    final chartBody = viewMode == ChartViewMode.split
                      ? _SplitCharts(
                          samples: prepared,
                          maxDurationMs: widget.maxDurationMs,
                          viewport: viewport,
                          visibility: visibility,
                          surfaceStyle: surfaceStyle,
                          annotations: annotations,
                          targetPressureSamples: widget.targetPressureSamples,
                          devicePixelRatio: devicePixelRatio,
                        )
                      : _OverlayChart(
                          samples: prepared,
                          maxDurationMs: widget.maxDurationMs,
                          viewport: viewport,
                          visibility: visibility,
                          surfaceStyle: surfaceStyle,
                          annotations: annotations,
                          targetPressureSamples: widget.targetPressureSamples,
                          denseTimeAxis: widget.denseTimeAxis,
                          devicePixelRatio: devicePixelRatio,
                        );

                  final interactiveBody = widget.enableInteraction
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _interactionController.onScaleStart,
                          onScaleUpdate: (details) => _interactionController
                              .onScaleUpdate(details, plotWidth),
                          onScaleEnd: _interactionController.onScaleEnd,
                          onTapUp: widget.enableCrosshair
                              ? (details) {
                                  final elapsedMs = chartElapsedMsFromLocalX(
                                    localX: details.localPosition.dx,
                                    chartWidth: constraints.maxWidth,
                                    viewport: viewport,
                                  );
                                  _interactionController.setProbeFromElapsedMs(
                                    elapsedMs,
                                    prepared,
                                  );
                                }
                              : null,
                          onLongPressStart: widget.onAnnotateAtElapsedMs == null
                              ? null
                              : (details) {
                                  final elapsedMs = chartElapsedMsFromLocalX(
                                    localX: details.localPosition.dx,
                                    chartWidth: constraints.maxWidth,
                                    viewport: viewport,
                                  );
                                  widget.onAnnotateAtElapsedMs!(elapsedMs);
                                },
                          child: chartBody,
                        )
                      : chartBody;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      interactiveBody,
                      if (widget.enableCrosshair)
                        _ChartCrosshairOverlay(
                          samples: prepared,
                          viewport: viewport,
                          interactionController: _interactionController,
                          surfaceStyle: surfaceStyle,
                          chartWidth: constraints.maxWidth,
                          chartHeight: height,
                          devicePixelRatio: devicePixelRatio,
                        ),
                    ],
                  );
                  },
                ),
              );
            }

            final legend = _Legend(
              showPressure: visibility.showPressure,
              showWeight: visibility.showWeight,
              showFlow: visibility.showFlow,
              showTarget: widget.targetPressureSamples.isNotEmpty,
              viewMode: viewMode,
              interactionController: widget.enableInteraction
                  ? _interactionController
                  : null,
            );

            if (boundedHeight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, plotConstraints) {
                        final height = plotConstraints.maxHeight
                            .clamp(80.0, widget.height);
                        return plotArea(height: height);
                      },
                    ),
                  ),
                  SizedBox(height: kDualCurveChartLegendGap),
                  legend,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                plotArea(height: plotHeight ?? widget.height),
                SizedBox(height: kDualCurveChartLegendGap),
                legend,
              ],
            );
          },
        ),
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

  int _resolveTotalDurationMs(List<ShotSample> samples) {
    var total = widget.maxDurationMs ?? 30000;
    for (final sample in samples) {
      total = math.max(total, sample.elapsedMs);
    }
    for (final sample in widget.targetPressureSamples) {
      total = math.max(total, sample.elapsedMs);
    }
    if (widget.maxDurationMs != null) {
      total = math.max(total, widget.maxDurationMs!);
    }
    return math.max(total, 1);
  }

  static double _plotWidth(double width) {
    return math.max(
      1,
      width - DualCurveChartPainter.leftPad - DualCurveChartPainter.rightPad,
    );
  }

  static String _semanticsLabel(ChartViewMode mode) {
    return switch (mode) {
      ChartViewMode.overlay => 'Espresso shot chart, overlay view',
      ChartViewMode.split => 'Espresso shot chart, split view',
      ChartViewMode.flowOnly => 'Espresso shot chart, flow only',
    };
  }
}

class _SeriesVisibility {
  const _SeriesVisibility({
    required this.showPressure,
    required this.showWeight,
    required this.showFlow,
  });

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
}

_SeriesVisibility _visibilityForMode({
  required ChartViewMode viewMode,
  required bool showPressure,
  required bool showWeight,
  required bool showFlow,
}) {
  return switch (viewMode) {
    ChartViewMode.overlay => _SeriesVisibility(
        showPressure: showPressure,
        showWeight: showWeight,
        showFlow: showFlow,
      ),
    ChartViewMode.split => _SeriesVisibility(
        showPressure: showPressure,
        showWeight: showWeight,
        showFlow: showFlow,
      ),
    ChartViewMode.flowOnly => _SeriesVisibility(
        showPressure: false,
        showWeight: false,
        showFlow: showFlow,
      ),
  };
}

class _OverlayChart extends StatelessWidget {
  const _OverlayChart({
    required this.samples,
    required this.maxDurationMs,
    required this.viewport,
    required this.visibility,
    required this.surfaceStyle,
    required this.annotations,
    required this.targetPressureSamples,
    this.denseTimeAxis = false,
    this.devicePixelRatio = 1.0,
  });

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final _SeriesVisibility visibility;
  final ChartSurfaceStyle surfaceStyle;
  final List<ShotAnnotation> annotations;
  final List<ShotSample> targetPressureSamples;
  final bool denseTimeAxis;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DualCurveChartPainter(
        samples: samples,
        maxDurationMs: maxDurationMs,
        viewport: viewport,
        showPressure: visibility.showPressure,
        showWeight: visibility.showWeight,
        showFlow: visibility.showFlow,
        surfaceStyle: surfaceStyle,
        annotations: annotations,
        targetPressureSamples: targetPressureSamples,
        denseTimeAxis: denseTimeAxis,
        devicePixelRatio: devicePixelRatio,
      ),
    );
  }
}

class _SplitCharts extends StatelessWidget {
  const _SplitCharts({
    required this.samples,
    required this.maxDurationMs,
    required this.viewport,
    required this.visibility,
    required this.surfaceStyle,
    required this.annotations,
    required this.targetPressureSamples,
    this.devicePixelRatio = 1.0,
  });

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final _SeriesVisibility visibility;
  final ChartSurfaceStyle surfaceStyle;
  final List<ShotAnnotation> annotations;
  final List<ShotSample> targetPressureSamples;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    final panels = <Widget>[];
    if (visibility.showPressure) {
      panels.add(
        _SplitPanel(
          label: 'Pressure',
          surfaceStyle: surfaceStyle,
          painter: DualCurveChartPainter(
            samples: samples,
            maxDurationMs: maxDurationMs,
            viewport: viewport,
            showPressure: true,
            showWeight: false,
            showFlow: false,
            surfaceStyle: surfaceStyle,
            compact: true,
            axisUnitLabel: 'bar',
            annotations: annotations,
            targetPressureSamples: targetPressureSamples,
            devicePixelRatio: devicePixelRatio,
          ),
        ),
      );
    }
    if (visibility.showWeight) {
      panels.add(
        _SplitPanel(
          label: 'Weight',
          surfaceStyle: surfaceStyle,
          painter: DualCurveChartPainter(
            samples: samples,
            maxDurationMs: maxDurationMs,
            viewport: viewport,
            showPressure: false,
            showWeight: true,
            showFlow: false,
            surfaceStyle: surfaceStyle,
            compact: true,
            axisUnitLabel: 'g',
            annotations: annotations,
            devicePixelRatio: devicePixelRatio,
          ),
        ),
      );
    }
    if (visibility.showFlow) {
      panels.add(
        _SplitPanel(
          label: 'Flow',
          surfaceStyle: surfaceStyle,
          painter: DualCurveChartPainter(
            samples: samples,
            maxDurationMs: maxDurationMs,
            viewport: viewport,
            showPressure: false,
            showWeight: false,
            showFlow: true,
            surfaceStyle: surfaceStyle,
            compact: true,
            axisUnitLabel: 'g/s',
            annotations: annotations,
            devicePixelRatio: devicePixelRatio,
          ),
        ),
      );
    }

    if (panels.isEmpty) {
      return CustomPaint(
        painter: DualCurveChartPainter(
          samples: samples,
          maxDurationMs: maxDurationMs,
          viewport: viewport,
          surfaceStyle: surfaceStyle,
          annotations: annotations,
          devicePixelRatio: devicePixelRatio,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < panels.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Expanded(child: panels[i]),
        ],
      ],
    );
  }
}

class _SplitPanel extends StatelessWidget {
  const _SplitPanel({
    required this.label,
    required this.surfaceStyle,
    required this.painter,
  });

  final String label;
  final ChartSurfaceStyle surfaceStyle;
  final DualCurveChartPainter painter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: surfaceStyle.axisLabel,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: CustomPaint(painter: painter),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.showPressure,
    required this.showWeight,
    required this.showFlow,
    required this.showTarget,
    required this.viewMode,
    this.interactionController,
  });

  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
  final bool showTarget;
  final ChartViewMode viewMode;
  final ChartInteractionController? interactionController;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (showPressure) {
      items.add(
        _LegendItem(
          color: FlowlogChartColors.pressureLine,
          label: 'Pressure',
        ),
      );
    }
    if (showWeight) {
      items.add(
        _LegendItem(color: FlowlogChartColors.weightLine, label: 'Weight'),
      );
    }
    if (showFlow) {
      items.add(_LegendItem(color: FlowlogChartColors.flowLine, label: 'Flow'));
    }
    if (showTarget) {
      items.add(
        _LegendItem(
          color: FlowlogChartColors.targetPressureLine,
          label: 'Target',
          dashed: true,
        ),
      );
    }

    if (interactionController == null) {
      return Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: items,
            ),
          ),
          Text(
            _viewModeLabel(viewMode),
            style: const TextStyle(
              color: FlowlogChartColors.axisLabel,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: items,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: _ViewModePicker(
            viewMode: viewMode,
            onModeSelected: interactionController!.setViewMode,
          ),
        ),
      ],
    );
  }

  static String _viewModeLabel(ChartViewMode mode) {
    return switch (mode) {
      ChartViewMode.overlay => 'Overlay',
      ChartViewMode.split => 'Split',
      ChartViewMode.flowOnly => 'Flow only',
    };
  }
}

class _ViewModePicker extends StatelessWidget {
  const _ViewModePicker({
    required this.viewMode,
    required this.onModeSelected,
  });

  final ChartViewMode viewMode;
  final ValueChanged<ChartViewMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final mode in ChartViewMode.values)
          ChoiceChip(
            key: Key('chart_view_mode_${mode.name}'),
            label: Text(
              _Legend._viewModeLabel(mode),
              style: const TextStyle(fontSize: 11),
            ),
            selected: viewMode == mode,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            onSelected: (selected) {
              if (selected) {
                onModeSelected(mode);
              }
            },
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? SizedBox(
                width: 14,
                height: 10,
                child: CustomPaint(
                  painter: _DashedLegendSwatchPainter(color: color),
                ),
              )
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: FlowlogChartColors.axisLabel,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DashedLegendSwatchPainter extends CustomPainter {
  const _DashedLegendSwatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    const dashLength = 4.0;
    const gapLength = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      final end = math.min(x + dashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLegendSwatchPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Paints pressure, weight, and flow curves over elapsed shot time.
class DualCurveChartPainter extends CustomPainter {
  DualCurveChartPainter({
    required this.samples,
    this.maxDurationMs,
    ChartViewport? viewport,
    this.showPressure = true,
    this.showWeight = true,
    this.showFlow = true,
    ChartSurfaceStyle? surfaceStyle,
    this.compact = false,
    this.axisUnitLabel,
    this.annotations = const [],
    this.targetPressureSamples = const [],
    this.denseTimeAxis = false,
    this.devicePixelRatio = 1.0,
  })  : surfaceStyle = surfaceStyle ??
            const ChartSurfaceStyle(
              background: FlowlogChartColors.background,
              grid: FlowlogChartColors.grid,
              axisLabel: FlowlogChartColors.axisLabel,
            ),
        viewport = viewport ??
            ChartViewport(
              totalDurationMs: math.max(
                1,
                maxDurationMs ??
                    _fallbackDuration(samples, targetPressureSamples),
              ),
            );

  final List<ShotSample> samples;
  final int? maxDurationMs;
  final ChartViewport viewport;
  final bool showPressure;
  final bool showWeight;
  final bool showFlow;
  final ChartSurfaceStyle surfaceStyle;
  final bool compact;
  final String? axisUnitLabel;
  final List<ShotAnnotation> annotations;
  final List<ShotSample> targetPressureSamples;
  final bool denseTimeAxis;
  final double devicePixelRatio;

  static const leftPad = 40.0;
  static const rightPad = 40.0;
  static const topPad = 16.0;
  static const bottomPad = 24.0;
  static const axisUnitTop = 2.0;

  static double _snap(double value, double pixelRatio) {
    return (value * pixelRatio).roundToDouble() / pixelRatio;
  }

  static double _snapStrokeCoord(double value, double strokeWidth, double pixelRatio) {
    final scaled = value * pixelRatio;
    final stroke = strokeWidth * pixelRatio;
    final aligned = stroke % 2 == 0 ? scaled.roundToDouble() : scaled.floor() + 0.5;
    return aligned / pixelRatio;
  }

  static int _fallbackDuration(
    List<ShotSample> samples,
    List<ShotSample> targetPressureSamples,
  ) {
    var duration = 30000;
    if (samples.isNotEmpty) {
      duration = samples.last.elapsedMs;
    }
    if (targetPressureSamples.isNotEmpty) {
      duration = math.max(duration, targetPressureSamples.last.elapsedMs);
    }
    return duration;
  }

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
      Paint()..color = surfaceStyle.background,
    );

    final scales = _ChartScales.fromSamples(
      samples,
      maxDurationMs: maxDurationMs,
      viewport: viewport,
      targetPressureSamples: targetPressureSamples,
    );

    _drawGrid(canvas, plotRect, scales);
    _drawAxes(canvas, plotRect, scales);

    canvas.save();
    canvas.clipRect(plotRect);

    if (samples.isEmpty && targetPressureSamples.isEmpty) {
      _drawEmptyLabel(canvas, plotRect, 'Waiting for samples…');
      canvas.restore();
      return;
    }

    if (showPressure && targetPressureSamples.isNotEmpty) {
      _drawTargetPressure(canvas, plotRect, scales);
    }

    if (samples.isEmpty && targetPressureSamples.isNotEmpty) {
      _drawEmptyLabel(canvas, plotRect, 'Follow the target curve');
    }

    if (showPressure) {
      _drawPressure(canvas, plotRect, scales);
    }
    if (showWeight) {
      _drawSeries(
        canvas,
        plotRect,
        scales,
        valueSelector: (sample) => sample.weightG,
        maxValue: scales.weightMax,
        color: FlowlogChartColors.weightLine,
        strokeWidth: 2,
      );
    }
    if (showFlow) {
      _drawSeries(
        canvas,
        plotRect,
        scales,
        valueSelector: (sample) => sample.flowGs,
        maxValue: scales.flowMax,
        color: FlowlogChartColors.flowLine,
        strokeWidth: 1.5,
        dashed: true,
      );
    }

    paintShotAnnotations(
      canvas,
      plotRect,
      viewport,
      annotations: annotations,
    );
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Rect plotRect, _ChartScales scales) {
    if (showPressure) {
      _drawValueGrid(
        canvas,
        plotRect,
        maxValue: scales.pressureMax,
        step: 2,
        labelStep: compact ? 4 : 2,
        emphasizeValues: {8},
      );
    } else if (showWeight) {
      _drawValueGrid(
        canvas,
        plotRect,
        maxValue: scales.weightMax,
        step: _gridStepForMax(scales.weightMax, targetLines: compact ? 3 : 5),
        labelStep: null,
      );
    } else if (showFlow) {
      _drawValueGrid(
        canvas,
        plotRect,
        maxValue: scales.flowMax,
        step: 1,
        labelStep: compact ? 2 : 1,
      );
    }

    _drawTimeGrid(canvas, plotRect, scales);
  }

  double _gridStepForMax(double maxValue, {required int targetLines}) {
    final rawStep = maxValue / targetLines;
    if (rawStep <= 5) {
      return 5;
    }
    if (rawStep <= 10) {
      return 10;
    }
    return (rawStep / 10).ceil() * 10.0;
  }

  void _drawValueGrid(
    Canvas canvas,
    Rect plotRect, {
    required double maxValue,
    required double step,
    double? labelStep,
    Set<double> emphasizeValues = const {},
  }) {
    if (maxValue <= 0 || step <= 0) {
      return;
    }

    final tickStyle = TextStyle(
      color: surfaceStyle.axisLabel.withValues(alpha: 0.9),
      fontSize: compact ? 9 : 10,
    );
    final effectiveLabelStep = labelStep ?? step;

    for (var value = 0.0; value <= maxValue + 0.001; value += step) {
      final rawY = plotRect.bottom - (value / maxValue) * plotRect.height;
      final emphasized =
          emphasizeValues.contains(value) || (value > 0 && value % 4 == 0);
      final strokeWidth = emphasized ? 1.25 : 1.0;
      final y = _snapStrokeCoord(rawY, strokeWidth, devicePixelRatio);
      final linePaint = Paint()
        ..color = surfaceStyle.grid.withValues(
          alpha: emphasized ? 0.58 : 0.38,
        )
        ..strokeWidth = strokeWidth
        ..isAntiAlias = false;

      canvas.drawLine(
        Offset(plotRect.left, y),
        Offset(plotRect.right, y),
        linePaint,
      );

      if (value > 0 &&
          effectiveLabelStep > 0 &&
          (value % effectiveLabelStep).abs() < 0.001 &&
          value < maxValue - 0.001) {
        final labelY = y <= plotRect.top + 1 ? y + 3 : y - 7;
        _paintText(
          canvas,
          _formatGridValue(value),
          Offset(0, labelY),
          tickStyle,
          maxWidth: leftPad - 6,
          align: TextAlign.right,
        );
      }
    }
  }

  int _timeGridStepMs(int timeSpanMs) {
    if (denseTimeAxis) {
      if (timeSpanMs <= 15000) {
        return 2500;
      }
      if (timeSpanMs <= 30000) {
        return 5000;
      }
      if (timeSpanMs <= 60000) {
        return 10000;
      }
      return 15000;
    }

    if (timeSpanMs <= 20000) {
      return 5000;
    }
    if (timeSpanMs <= 50000) {
      return 10000;
    }
    return 15000;
  }

  void _drawTimeGrid(Canvas canvas, Rect plotRect, _ChartScales scales) {
    final stepMs = _timeGridStepMs(scales.timeSpanMs);

    final startTick =
        ((scales.timeOffsetMs + stepMs - 1) ~/ stepMs) * stepMs;
    final gridPaint = Paint()
      ..color = surfaceStyle.grid.withValues(alpha: 0.32)
      ..strokeWidth = 1
      ..isAntiAlias = false;

    for (var elapsedMs = startTick;
        elapsedMs <= scales.visibleEndMs;
        elapsedMs += stepMs) {
      final normalizedTime =
          (elapsedMs - scales.timeOffsetMs) / scales.timeSpanMs;
      if (normalizedTime < 0 || normalizedTime > 1) {
        continue;
      }
      final rawX = plotRect.left + normalizedTime * plotRect.width;
      final x = _snapStrokeCoord(rawX, 1, devicePixelRatio);
      canvas.drawLine(
        Offset(x, plotRect.top),
        Offset(x, plotRect.bottom),
        gridPaint,
      );
    }
  }

  String _formatGridValue(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  void _drawAxes(Canvas canvas, Rect plotRect, _ChartScales scales) {
    final textStyle = TextStyle(
      color: surfaceStyle.axisLabel,
      fontSize: compact ? 9 : 10,
    );

    if (compact) {
      final unit = axisUnitLabel ?? 'bar';
      _drawAxisLabel(
        canvas,
        unit,
        Offset(4, axisUnitTop),
        textStyle,
      );
    } else {
      _drawAxisLabel(
        canvas,
        'bar',
        Offset(4, axisUnitTop),
        textStyle,
      );
      _drawAxisLabel(
        canvas,
        'g',
        Offset(plotRect.right + 6, axisUnitTop),
        textStyle,
      );
      _drawAxisLabel(
        canvas,
        'g/s',
        Offset(plotRect.right + 6, plotRect.center.dy),
        textStyle,
      );
    }

    final stepMs = _timeGridStepMs(scales.timeSpanMs);
    final startTick = ((scales.timeOffsetMs + stepMs - 1) ~/ stepMs) * stepMs;
    for (var elapsedMs = startTick;
        elapsedMs <= scales.visibleEndMs;
        elapsedMs += stepMs) {
      final normalizedTime =
          (elapsedMs - scales.timeOffsetMs) / scales.timeSpanMs;
      if (normalizedTime < 0 || normalizedTime > 1) {
        continue;
      }

      final x = plotRect.left + normalizedTime * plotRect.width;
      final label = _formatDuration(elapsedMs);
      final labelWidth = label.length * 6.0 + 8;
      final labelX = (x - labelWidth / 2)
          .clamp(plotRect.left, plotRect.right - labelWidth);
      _paintText(
        canvas,
        label,
        Offset(labelX, plotRect.bottom + 4),
        textStyle,
        maxWidth: labelWidth,
        align: TextAlign.center,
      );
    }
  }

  void _drawEmptyLabel(Canvas canvas, Rect plotRect, String message) {
    _paintText(
      canvas,
      message,
      Offset(plotRect.left, plotRect.center.dy - 6),
      TextStyle(
        color: surfaceStyle.axisLabel,
        fontSize: 12,
      ),
      maxWidth: plotRect.width,
      align: TextAlign.center,
    );
  }

  void _drawTargetPressure(Canvas canvas, Rect plotRect, _ChartScales scales) {
    _drawSeries(
      canvas,
      plotRect,
      scales,
      samples: targetPressureSamples,
      valueSelector: (sample) => sample.pressureBar,
      maxValue: scales.pressureMax,
      color: FlowlogChartColors.targetPressureLine.withValues(alpha: 0.85),
      strokeWidth: 1.75,
      dashed: true,
    );
  }

  void _drawPressure(Canvas canvas, Rect plotRect, _ChartScales scales) {
    final points = <Offset>[];
    for (final sample in samples) {
      final pressure = sample.pressureBar;
      if (pressure == null) {
        continue;
      }
      points.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: sample.elapsedMs,
        value: pressure,
        maxValue: scales.pressureMax,
      ));
    }

    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, plotRect.bottom)
      ..lineTo(points.first.dx, plotRect.bottom)
      ..close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(plotRect.left, plotRect.bottom),
        Offset(plotRect.left, plotRect.top),
        [
          FlowlogChartColors.pressureLow.withValues(alpha: 0.35),
          FlowlogChartColors.pressureHigh.withValues(alpha: 0.45),
        ],
      );
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = FlowlogChartColors.pressureLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawSeries(
    Canvas canvas,
    Rect plotRect,
    _ChartScales scales, {
    List<ShotSample>? samples,
    required double? Function(ShotSample sample) valueSelector,
    required double maxValue,
    required Color color,
    required double strokeWidth,
    bool dashed = false,
  }) {
    final series = samples ?? this.samples;
    final points = <Offset>[];
    for (final sample in series) {
      final value = valueSelector(sample);
      if (value == null) {
        continue;
      }
      points.add(_pointFor(
        plotRect,
        scales,
        elapsedMs: sample.elapsedMs,
        value: value,
        maxValue: maxValue,
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
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (dashed) {
      _drawDashedPath(canvas, path, paint);
      return;
    }

    canvas.drawPath(path, paint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 4.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  Offset _pointFor(
    Rect plotRect,
    _ChartScales scales, {
    required int elapsedMs,
    required double value,
    required double maxValue,
  }) {
    final normalizedTime =
        (elapsedMs - scales.timeOffsetMs) / scales.timeSpanMs;
    final x = plotRect.left + normalizedTime.clamp(0.0, 1.0) * plotRect.width;
    final y = plotRect.bottom -
        (value / maxValue).clamp(0.0, 1.0) * plotRect.height;
    return Offset(x, y);
  }

  void _drawAxisLabel(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    _paintText(canvas, text, offset, style);
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
  bool shouldRepaint(covariant DualCurveChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.maxDurationMs != maxDurationMs ||
        oldDelegate.viewport != viewport ||
        oldDelegate.showPressure != showPressure ||
        oldDelegate.showWeight != showWeight ||
        oldDelegate.showFlow != showFlow ||
        oldDelegate.surfaceStyle != surfaceStyle ||
        oldDelegate.compact != compact ||
        oldDelegate.axisUnitLabel != axisUnitLabel ||
        oldDelegate.annotations != annotations ||
        oldDelegate.targetPressureSamples != targetPressureSamples ||
        oldDelegate.denseTimeAxis != denseTimeAxis ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

class _ChartCrosshairOverlay extends StatelessWidget {
  const _ChartCrosshairOverlay({
    required this.samples,
    required this.viewport,
    required this.interactionController,
    required this.surfaceStyle,
    required this.chartWidth,
    required this.chartHeight,
    this.devicePixelRatio = 1.0,
  });

  final List<ShotSample> samples;
  final ChartViewport viewport;
  final ChartInteractionController interactionController;
  final ChartSurfaceStyle surfaceStyle;
  final double chartWidth;
  final double chartHeight;
  final double devicePixelRatio;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: interactionController,
      builder: (context, _) {
        final probe = interactionController.probeSample;
        if (probe == null) {
          return const SizedBox.shrink();
        }

        final plotRect = Rect.fromLTWH(
          DualCurveChartPainter.leftPad,
          DualCurveChartPainter.topPad,
          math.max(
            1,
            chartWidth -
                DualCurveChartPainter.leftPad -
                DualCurveChartPainter.rightPad,
          ),
          math.max(
            1,
            chartHeight -
                DualCurveChartPainter.topPad -
                DualCurveChartPainter.bottomPad,
          ),
        );

        final scales = _ChartScales.fromSamples(
          samples,
          viewport: viewport,
        );
        final normalizedTime =
            (probe.elapsedMs - scales.timeOffsetMs) / scales.timeSpanMs;
        final x = plotRect.left + normalizedTime.clamp(0.0, 1.0) * plotRect.width;

        final pressure = probe.pressureBar;
        final weight = probe.weightG;
        final flow = probe.flowGs;
        final parts = <String>[
          _formatDuration(probe.elapsedMs),
          if (pressure != null) '${pressure.toStringAsFixed(1)} bar',
          if (weight != null) '${weight.toStringAsFixed(1)} g',
          if (flow != null) '${flow.toStringAsFixed(1)} g/s',
        ];

        return IgnorePointer(
          child: CustomPaint(
            painter: _ChartCrosshairPainter(
              x: x,
              plotRect: plotRect,
              surfaceStyle: surfaceStyle,
              devicePixelRatio: devicePixelRatio,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: (x + 8).clamp(plotRect.left, plotRect.right - 120),
                  top: plotRect.top + 4,
                ),
                child: Material(
                  color: surfaceStyle.background.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      parts.join(' · '),
                      key: const Key('chart_crosshair_readout'),
                      style: TextStyle(
                        color: surfaceStyle.axisLabel,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
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
}

class _ChartCrosshairPainter extends CustomPainter {
  const _ChartCrosshairPainter({
    required this.x,
    required this.plotRect,
    required this.surfaceStyle,
    this.devicePixelRatio = 1.0,
  });

  final double x;
  final Rect plotRect;
  final ChartSurfaceStyle surfaceStyle;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final alignedX = DualCurveChartPainter._snapStrokeCoord(
      x,
      1,
      devicePixelRatio,
    );
    final paint = Paint()
      ..color = surfaceStyle.axisLabel.withValues(alpha: 0.75)
      ..strokeWidth = 1
      ..isAntiAlias = false;

    canvas.drawLine(
      Offset(alignedX, plotRect.top),
      Offset(alignedX, plotRect.bottom),
      paint,
    );

    final dotPaint = Paint()..color = surfaceStyle.axisLabel;
    canvas.drawCircle(Offset(x, plotRect.center.dy), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ChartCrosshairPainter oldDelegate) {
    return oldDelegate.x != x ||
        oldDelegate.plotRect != plotRect ||
        oldDelegate.surfaceStyle != surfaceStyle ||
        oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}

class _ChartScales {
  const _ChartScales({
    required this.timeOffsetMs,
    required this.timeSpanMs,
    required this.visibleEndMs,
    required this.pressureMax,
    required this.weightMax,
    required this.flowMax,
  });

  final int timeOffsetMs;
  final int timeSpanMs;
  final int visibleEndMs;
  final double pressureMax;
  final double weightMax;
  final double flowMax;

  factory _ChartScales.fromSamples(
    List<ShotSample> samples, {
    int? maxDurationMs,
    required ChartViewport viewport,
    List<ShotSample> targetPressureSamples = const [],
  }) {
    var pressureMax = 12.0;
    var weightMax = 50.0;
    var flowMax = 5.0;

    final windowStart = viewport.visibleStartMs;
    final windowEnd = viewport.visibleEndMs;

    void considerSample(ShotSample sample) {
      if (sample.elapsedMs < windowStart || sample.elapsedMs > windowEnd) {
        return;
      }
      if (sample.pressureBar != null) {
        pressureMax = math.max(pressureMax, sample.pressureBar! * 1.1);
      }
      if (sample.weightG != null) {
        weightMax = math.max(weightMax, sample.weightG! * 1.1);
      }
      if (sample.flowGs != null) {
        flowMax = math.max(flowMax, sample.flowGs! * 1.1);
      }
    }

    for (final sample in samples) {
      considerSample(sample);
    }

    for (final sample in targetPressureSamples) {
      if (sample.pressureBar != null) {
        pressureMax = math.max(pressureMax, sample.pressureBar! * 1.1);
      }
    }

    return _ChartScales(
      timeOffsetMs: viewport.visibleStartMs,
      timeSpanMs: math.max(viewport.visibleDurationMs, 1),
      visibleEndMs: viewport.visibleEndMs,
      pressureMax: _snapAxisMax(pressureMax, step: 4, minimum: 12),
      weightMax: _snapAxisMax(weightMax, step: 10, minimum: 50),
      flowMax: _snapAxisMax(flowMax, step: 1, minimum: 5),
    );
  }
}

double _snapAxisMax(double value, {required double step, required double minimum}) {
  final snapped = math.max(minimum, (value / step).ceil() * step);
  return snapped;
}