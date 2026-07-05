import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Default elapsed times for editable pressure keyframes (ms).
const List<int> defaultSimulatorKeyframeTimes = [
  0,
  6000,
  12000,
  18000,
  28000,
];

/// One editable pressure point on the what-if profile.
@immutable
class PressureKeyframe {
  const PressureKeyframe({
    required this.elapsedMs,
    required this.pressureBar,
  });

  final int elapsedMs;
  final double pressureBar;

  PressureKeyframe copyWith({
    int? elapsedMs,
    double? pressureBar,
  }) {
    return PressureKeyframe(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      pressureBar: pressureBar ?? this.pressureBar,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PressureKeyframe &&
            elapsedMs == other.elapsedMs &&
            pressureBar == other.pressureBar;
  }

  @override
  int get hashCode => Object.hash(elapsedMs, pressureBar);
}

/// Stub heuristic: higher pressure yields higher predicted flow (g/s).
double predictFlowGs(double pressureBar) {
  if (pressureBar <= 0.2) {
    return 0;
  }
  return (pressureBar * 0.18 + 0.05).clamp(0, 4.0);
}

/// Builds predicted flow samples from a pressure profile.
List<ShotSample> buildPredictedFlowSamples(List<ShotSample> pressureProfile) {
  return [
    for (final sample in pressureProfile)
      ShotSample(
        elapsedMs: sample.elapsedMs,
        pressureBar: sample.pressureBar,
        flowGs: predictFlowGs(sample.pressureBar ?? 0),
      ),
  ];
}

/// Summary metrics for the predicted flow curve.
@immutable
class PredictedFlowSummary {
  const PredictedFlowSummary({
    required this.peakFlowGs,
    required this.averageFlowGs,
    required this.peakPressureBar,
  });

  final double peakFlowGs;
  final double averageFlowGs;
  final double peakPressureBar;
}

PredictedFlowSummary summarizePredictedFlow(List<ShotSample> samples) {
  var peakFlow = 0.0;
  var peakPressure = 0.0;
  var flowSum = 0.0;
  var flowCount = 0;

  for (final sample in samples) {
    final pressure = sample.pressureBar ?? 0;
    final flow = sample.flowGs ?? predictFlowGs(pressure);
    peakFlow = math.max(peakFlow, flow);
    peakPressure = math.max(peakPressure, pressure);
    flowSum += flow;
    flowCount++;
  }

  return PredictedFlowSummary(
    peakFlowGs: peakFlow,
    averageFlowGs: flowCount == 0 ? 0 : flowSum / flowCount,
    peakPressureBar: peakPressure,
  );
}

/// Interpolates pressure (bar) at [elapsedMs] from [samples].
double? pressureAtElapsedMs(int elapsedMs, List<ShotSample> samples) {
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

/// Builds editable keyframes from a saved profile or shot samples.
List<PressureKeyframe> keyframesFromPressureSamples(
  List<ShotSample> samples, {
  List<int> keyframeTimes = defaultSimulatorKeyframeTimes,
}) {
  return [
    for (final elapsedMs in keyframeTimes)
      PressureKeyframe(
        elapsedMs: elapsedMs,
        pressureBar: (pressureAtElapsedMs(elapsedMs, samples) ?? 0)
            .clamp(0, 12)
            .toDouble(),
      ),
  ];
}

/// Expands keyframes into a dense pressure profile for charting.
List<ShotSample> expandKeyframesToProfile(
  List<PressureKeyframe> keyframes, {
  int stepMs = 500,
}) {
  if (keyframes.isEmpty) {
    return const [];
  }

  final sorted = List<PressureKeyframe>.from(keyframes)
    ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
  final endMs = sorted.last.elapsedMs;
  final profile = <ShotSample>[];

  for (var elapsedMs = 0; elapsedMs <= endMs; elapsedMs += stepMs) {
    profile.add(
      ShotSample(
        elapsedMs: elapsedMs,
        pressureBar: _pressureAtKeyframeTime(elapsedMs, sorted),
      ),
    );
  }

  if (profile.isEmpty || profile.last.elapsedMs != endMs) {
    profile.add(
      ShotSample(
        elapsedMs: endMs,
        pressureBar: _pressureAtKeyframeTime(endMs, sorted),
      ),
    );
  }

  return profile;
}

double _pressureAtKeyframeTime(int elapsedMs, List<PressureKeyframe> keyframes) {
  if (keyframes.isEmpty) {
    return 0;
  }

  PressureKeyframe? before;
  PressureKeyframe? after;
  for (final keyframe in keyframes) {
    if (keyframe.elapsedMs == elapsedMs) {
      return keyframe.pressureBar;
    }
    if (keyframe.elapsedMs < elapsedMs) {
      before = keyframe;
    } else if (keyframe.elapsedMs > elapsedMs) {
      after = keyframe;
      break;
    }
  }

  if (before == null || after == null) {
    return before?.pressureBar ?? after?.pressureBar ?? 0;
  }

  final span = after.elapsedMs - before.elapsedMs;
  if (span <= 0) {
    return before.pressureBar;
  }

  final t = (elapsedMs - before.elapsedMs) / span;
  return before.pressureBar + (after.pressureBar - before.pressureBar) * t;
}

/// Draggable canvas for editing a target pressure profile.
class PressureProfileEditor extends StatefulWidget {
  const PressureProfileEditor({
    required this.keyframes,
    required this.onKeyframesChanged,
    super.key,
    this.durationMs = 30000,
    this.height = 200,
    this.pressureMax = 12,
    this.onGestureActiveChanged,
  });

  final List<PressureKeyframe> keyframes;
  final ValueChanged<List<PressureKeyframe>> onKeyframesChanged;
  final int durationMs;
  final double height;
  final double pressureMax;

  /// Called when the user begins or ends dragging a control point.
  final ValueChanged<bool>? onGestureActiveChanged;

  @override
  State<PressureProfileEditor> createState() => _PressureProfileEditorState();
}

class _PressureProfileEditorState extends State<PressureProfileEditor> {
  static const _handleHitRadius = 36.0;
  static const _minKeyframeSpacingMs = 1500;
  static const _longPressDuration = Duration(milliseconds: 450);
  static const _axisLockThreshold = 8.0;
  static const _dragStartThreshold = 10.0;

  int? _activeIndex;
  int? _selectedIndex;
  Offset? _pointerDown;
  bool _dragged = false;
  bool? _dragVertical;
  Timer? _longPressTimer;
  bool _longPressHandled = false;

  void _setGestureActive(bool active) {
    widget.onGestureActiveChanged?.call(active);
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  void _updateKeyframePressure(int index, double pressureBar) {
    final updated = List<PressureKeyframe>.from(widget.keyframes);
    updated[index] = updated[index].copyWith(
      pressureBar: pressureBar.clamp(0, widget.pressureMax).toDouble(),
    );
    widget.onKeyframesChanged(updated);
  }

  void _updateKeyframeTime(int index, int elapsedMs, Size size) {
    final keyframes = widget.keyframes;
    if (index <= 0 || index >= keyframes.length - 1) {
      return;
    }

    final minMs = keyframes[index - 1].elapsedMs + _minKeyframeSpacingMs;
    final maxMs = keyframes[index + 1].elapsedMs - _minKeyframeSpacingMs;
    final clamped = elapsedMs.clamp(minMs, maxMs);

    final updated = List<PressureKeyframe>.from(keyframes);
    updated[index] = updated[index].copyWith(elapsedMs: clamped);
    updated.sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
    widget.onKeyframesChanged(updated);
  }

  bool _canDeleteKeyframe(int index) {
    return widget.keyframes.length > 2 &&
        index > 0 &&
        index < widget.keyframes.length - 1;
  }

  void _deleteKeyframe(int index) {
    if (!_canDeleteKeyframe(index)) {
      return;
    }

    final updated = List<PressureKeyframe>.from(widget.keyframes)
      ..removeAt(index);
    widget.onKeyframesChanged(updated);
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else if (_selectedIndex != null && _selectedIndex! > index) {
        _selectedIndex = _selectedIndex! - 1;
      }
    });
    HapticFeedback.mediumImpact();
  }

  int _elapsedMsAt(Offset localPosition, Size size) {
    final plotRect = _PressureProfileEditorPainter.plotRect(size);
    return ((localPosition.dx - plotRect.left) /
            plotRect.width *
            widget.durationMs)
        .round()
        .clamp(0, widget.durationMs);
  }

  int? _hitTestKeyframe(Offset localPosition, Size size) {
    for (var i = 0; i < widget.keyframes.length; i++) {
      final point = _PressureProfileEditorPainter.pointFor(
        keyframe: widget.keyframes[i],
        size: size,
        durationMs: widget.durationMs,
        pressureMax: widget.pressureMax,
      );
      if ((localPosition - point).distance <= _handleHitRadius) {
        return i;
      }
    }
    return null;
  }

  void _tryAddKeyframeAt(Offset localPosition, Size size) {
    final plotRect = _PressureProfileEditorPainter.plotRect(size);
    if (!plotRect.contains(localPosition)) {
      return;
    }

    final elapsedMs = ((localPosition.dx - plotRect.left) /
            plotRect.width *
            widget.durationMs)
        .round()
        .clamp(0, widget.durationMs);

    for (final keyframe in widget.keyframes) {
      if ((keyframe.elapsedMs - elapsedMs).abs() < _minKeyframeSpacingMs) {
        return;
      }
    }

    final profile = expandKeyframesToProfile(widget.keyframes);
    final pressure = pressureAtElapsedMs(elapsedMs, profile) ?? 0;

    final updated = List<PressureKeyframe>.from(widget.keyframes)
      ..add(
        PressureKeyframe(
          elapsedMs: elapsedMs,
          pressureBar: pressure.clamp(0, widget.pressureMax).toDouble(),
        ),
      )
      ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
    widget.onKeyframesChanged(updated);
  }

  void _onPointerDown(PointerDownEvent event, Size size) {
    _pointerDown = event.localPosition;
    _dragged = false;
    _dragVertical = null;
    _longPressHandled = false;
    _cancelLongPress();

    final index = _hitTestKeyframe(event.localPosition, size);
    setState(() => _activeIndex = index);
    if (index != null) {
      _setGestureActive(true);
      _longPressTimer = Timer(_longPressDuration, () {
        if (!mounted || _activeIndex != index) {
          return;
        }
        _longPressHandled = true;
        _dragged = true;
        _deleteKeyframe(index);
        setState(() => _activeIndex = null);
        _setGestureActive(false);
      });
    } else {
      final plotRect = _PressureProfileEditorPainter.plotRect(size);
      if (plotRect.contains(event.localPosition)) {
        _setGestureActive(true);
      }
    }
  }

  void _onPointerMove(PointerMoveEvent event, Size size) {
    final index = _activeIndex;
    if (index == null || _longPressHandled) {
      return;
    }

    if (_pointerDown != null) {
      final delta = event.localPosition - _pointerDown!;
      if (delta.distance < _dragStartThreshold) {
        return;
      }

      if (_dragVertical == null &&
          (delta.dx.abs() > _axisLockThreshold ||
              delta.dy.abs() > _axisLockThreshold)) {
        _dragVertical = delta.dy.abs() >= delta.dx.abs();
        _cancelLongPress();
      }
    }

    _dragged = true;
    _cancelLongPress();

    if (_dragVertical == false &&
        index > 0 &&
        index < widget.keyframes.length - 1) {
      _updateKeyframeTime(index, _elapsedMsAt(event.localPosition, size), size);
      return;
    }

    final plotRect = _PressureProfileEditorPainter.plotRect(size);
    final normalizedY = 1 -
        ((event.localPosition.dy - plotRect.top) / plotRect.height)
            .clamp(0.0, 1.0);
    _updateKeyframePressure(index, normalizedY * widget.pressureMax);
  }

  void _onPointerEnd(Offset localPosition, Size size) {
    _cancelLongPress();

    final activeIndex = _activeIndex;
    if (activeIndex != null) {
      if (!_dragged && !_longPressHandled) {
        setState(() => _selectedIndex = activeIndex);
      }
      setState(() => _activeIndex = null);
      _setGestureActive(false);
    } else if (_pointerDown != null && !_dragged && !_longPressHandled) {
      setState(() => _selectedIndex = null);
      _tryAddKeyframeAt(localPosition, size);
      _setGestureActive(false);
    } else {
      _setGestureActive(false);
    }

    _pointerDown = null;
    _dragged = false;
    _dragVertical = null;
    _longPressHandled = false;
  }

  @override
  void dispose() {
    _cancelLongPress();
    super.dispose();
  }

  String _formatSelectedKeyframeLabel() {
    final index = _selectedIndex;
    if (index == null || index >= widget.keyframes.length) {
      return '';
    }

    final keyframe = widget.keyframes[index];
    final seconds = (keyframe.elapsedMs / 1000).round();
    return '${seconds}s · ${keyframe.pressureBar.toStringAsFixed(1)} bar';
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;
    final canRemoveSelected =
        selectedIndex != null && _canDeleteKeyframe(selectedIndex);

    return Semantics(
      label: 'Target pressure profile editor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const Key('simulator_profile_editor'),
            height: widget.height,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, widget.height);
                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) => _onPointerDown(event, size),
                  onPointerMove: (event) => _onPointerMove(event, size),
                  onPointerUp: (event) =>
                      _onPointerEnd(event.localPosition, size),
                  onPointerCancel: (event) =>
                      _onPointerEnd(event.localPosition, size),
                  child: CustomPaint(
                    painter: _PressureProfileEditorPainter(
                      keyframes: widget.keyframes,
                      durationMs: widget.durationMs,
                      pressureMax: widget.pressureMax,
                      activeIndex: _activeIndex,
                      selectedIndex: _selectedIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          if (selectedIndex != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected: ${_formatSelectedKeyframeLabel()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (canRemoveSelected)
                  TextButton.icon(
                    key: const Key('simulator_remove_point'),
                    onPressed: () => _deleteKeyframe(selectedIndex),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove point'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PressureProfileEditorPainter extends CustomPainter {
  _PressureProfileEditorPainter({
    required this.keyframes,
    required this.durationMs,
    required this.pressureMax,
    this.activeIndex,
    this.selectedIndex,
  });

  final List<PressureKeyframe> keyframes;
  final int durationMs;
  final double pressureMax;
  final int? activeIndex;
  final int? selectedIndex;

  static const leftPad = 40.0;
  static const rightPad = 16.0;
  static const topPad = 12.0;
  static const bottomPad = 24.0;

  static Rect plotRect(Size size) {
    return Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(1, size.width - leftPad - rightPad),
      math.max(1, size.height - topPad - bottomPad),
    );
  }

  static Offset pointFor({
    required PressureKeyframe keyframe,
    required Size size,
    required int durationMs,
    required double pressureMax,
  }) {
    final plot = plotRect(size);
    final x = plot.left +
        (keyframe.elapsedMs / math.max(durationMs, 1)).clamp(0.0, 1.0) *
            plot.width;
    final y = plot.bottom -
        (keyframe.pressureBar / pressureMax).clamp(0.0, 1.0) * plot.height;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = plotRect(size);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = FlowlogChartColors.background,
    );

    _drawGrid(canvas, plot);
    _drawAxes(canvas, plot);
    _drawProfile(canvas, plot, size);
    _drawHandles(canvas, size);
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final gridPaint = Paint()
      ..color = FlowlogChartColors.grid.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = plot.top + (plot.height / 4) * i;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    for (var i = 0; i <= 5; i++) {
      final x = plot.left + (plot.width / 5) * i;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
    }
  }

  void _drawAxes(Canvas canvas, Rect plot) {
    const textStyle = TextStyle(
      color: FlowlogChartColors.axisLabel,
      fontSize: 10,
    );
    _paintText(canvas, 'bar', const Offset(4, topPad), textStyle);
    _paintText(
      canvas,
      _formatDuration(durationMs),
      Offset(plot.right - 28, plot.bottom + 6),
      textStyle,
    );
  }

  void _drawProfile(Canvas canvas, Rect plot, Size size) {
    if (keyframes.length < 2) {
      return;
    }

    final sorted = List<PressureKeyframe>.from(keyframes)
      ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
    final points = <Offset>[];
    for (var elapsedMs = 0; elapsedMs <= durationMs; elapsedMs += 250) {
      final pressure = _pressureAtKeyframeTime(elapsedMs, sorted);
      final x = plot.left +
          (elapsedMs / math.max(durationMs, 1)).clamp(0.0, 1.0) * plot.width;
      final y = plot.bottom -
          (pressure / pressureMax).clamp(0.0, 1.0) * plot.height;
      points.add(Offset(x, y));
    }

    if (points.length < 2) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final linePaint = Paint()
      ..color = FlowlogChartColors.targetPressureLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  void _drawHandles(Canvas canvas, Size size) {
    for (var i = 0; i < keyframes.length; i++) {
      final point = pointFor(
        keyframe: keyframes[i],
        size: size,
        durationMs: durationMs,
        pressureMax: pressureMax,
      );
      final isActive = activeIndex == i;
      final isSelected = selectedIndex == i;
      final radius = isActive || isSelected ? 13.0 : 10.0;
      final fillPaint = Paint()
        ..color = isActive
            ? FlowlogChartColors.pressureHigh
            : isSelected
                ? FlowlogChartColors.targetPressureLine
                : FlowlogChartColors.pressureLine;
      final strokePaint = Paint()
        ..color = FlowlogChartColors.axisLabel
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 2;

      canvas.drawCircle(point, radius, fillPaint);
      canvas.drawCircle(point, radius, strokePaint);
      if (isSelected && !isActive) {
        canvas.drawCircle(
          point,
          radius + 4,
          Paint()
            ..color = FlowlogChartColors.targetPressureLine.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
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
  bool shouldRepaint(covariant _PressureProfileEditorPainter oldDelegate) {
    return oldDelegate.keyframes != keyframes ||
        oldDelegate.durationMs != durationMs ||
        oldDelegate.pressureMax != pressureMax ||
        oldDelegate.activeIndex != activeIndex ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

/// Builds a [SavedProfile] from editable simulator keyframes.
SavedProfile profileFromKeyframes(
  List<PressureKeyframe> keyframes, {
  String? name,
  String? sourceShotId,
}) {
  final pressureSamples = expandKeyframesToProfile(keyframes);
  return SavedProfile(
    id: generateProfileId(),
    name: name ?? 'Simulator profile',
    createdAt: DateTime.now().toUtc(),
    sourceShotId: sourceShotId,
    pressureSamples: pressureSamples,
  );
}

/// What-if curve simulator: edit pressure and preview predicted flow.
class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({
    super.key,
    this.profileRepository,
    this.shotRepository,
  });

  /// Optional repository override for tests or dependency injection.
  final ProfileRepository? profileRepository;

  /// Optional shot repository for importing saved shots.
  final ShotRepository? shotRepository;

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> {
  ProfileRepository? _profileRepository;
  ShotRepository? _shotRepository;
  FlowlogDatabase? _database;
  bool _ownsRepositories = false;
  late Future<_SimulatorState> _stateFuture;

  List<PressureKeyframe> _keyframes = const [];
  SavedProfile? _profile;
  bool _initialized = false;
  bool _profileEditorActive = false;

  @override
  void initState() {
    super.initState();
    _stateFuture = _loadState();
  }

  Future<ProfileRepository> _ensureProfileRepository() async {
    if (widget.profileRepository != null) {
      return widget.profileRepository!;
    }
    if (_profileRepository != null) {
      return _profileRepository!;
    }

    final database = await _ensureDatabase();
    _profileRepository = ProfileRepository(database);
    return _profileRepository!;
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

  Future<FlowlogDatabase> _ensureDatabase() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = '${Directory.systemTemp.path}/flowlog.db';
    _database = FlowlogDatabase.openFile(dbPath);
    _ownsRepositories = true;
    return _database!;
  }

  Future<_SimulatorState> _loadState() async {
    final repository = await _ensureProfileRepository();
    final profiles = await repository.listProfiles(includeSamples: true);
    final profile = profiles.isNotEmpty
        ? profiles.first
        : await _demoProfileFromFixture();
    final keyframes = keyframesFromPressureSamples(profile.pressureSamples);
    return _SimulatorState(profile: profile, keyframes: keyframes);
  }

  Future<void> _refresh() async {
    setState(() {
      _initialized = false;
      _stateFuture = _loadState();
    });
    await _stateFuture;
  }

  void _applyLoadedState(_SimulatorState state) {
    if (_initialized) {
      return;
    }
    _profile = state.profile;
    _keyframes = state.keyframes;
    _initialized = true;
  }

  void _onKeyframesChanged(List<PressureKeyframe> keyframes) {
    setState(() => _keyframes = keyframes);
  }

  Future<void> _onImportShotPressed() async {
    final repository = await _ensureShotRepository();
    if (!mounted) {
      return;
    }

    final shot = await pickShotForSimulator(context, repository: repository);
    if (shot == null || !mounted) {
      return;
    }

    setState(() {
      _profile = SavedProfile.fromShot(
        shot,
        id: _profile?.id ?? 'simulator-draft',
        name: shot.id,
      );
      _keyframes = keyframesFromPressureSamples(shot.samples);
    });
  }

  Future<void> _onExportProfilePressed() async {
    if (_keyframes.isEmpty || !mounted) {
      return;
    }

    final name = await promptSimulatorProfileName(
      context,
      initialName: _profile?.name ?? 'Simulator profile',
    );
    if (name == null || !mounted) {
      return;
    }

    final profile = profileFromKeyframes(
      _keyframes,
      name: name,
      sourceShotId: _profile?.sourceShotId,
    );
    final repository = await _ensureProfileRepository();
    await repository.insertProfile(profile);

    if (!mounted) {
      return;
    }

    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('simulator_export_snackbar'),
        content: Text('Exported $name'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onUseOnLivePressed() async {
    if (_keyframes.isEmpty || !mounted) {
      return;
    }

    final name = await promptSimulatorProfileName(
      context,
      initialName: _profile?.name ?? 'Simulator profile',
    );
    if (name == null || !mounted) {
      return;
    }

    final profile = profileFromKeyframes(
      _keyframes,
      name: name,
      sourceShotId: _profile?.sourceShotId,
    );
    final repository = await _ensureProfileRepository();
    await repository.insertProfile(profile);

    final repeatController = RepeatShotScope.maybeOf(context);
    repeatController?.setPrefill(RepeatShotPrefill.fromProfile(profile));

    FlowlogShellScope.maybeOf(context)?.switchTab(AppTab.live);

    if (!mounted) {
      return;
    }

    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('simulator_use_on_live_snackbar'),
        content: Text('Target curve ready on Live — $name'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    return FutureBuilder<_SimulatorState>(
      future: _stateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Failed to load simulator: ${snapshot.error}'),
          );
        }

        final state = snapshot.data!;
        _applyLoadedState(state);

        final pressureProfile = expandKeyframesToProfile(_keyframes);
        final predictedSamples = buildPredictedFlowSamples(pressureProfile);
        final summary = summarizePredictedFlow(predictedSamples);
        final durationMs = _keyframes.isEmpty
            ? 30000
            : _keyframes.map((k) => k.elapsedMs).reduce(math.max);

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              key: const Key('simulator_screen'),
              physics: _profileEditorActive
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
              Text(
                'What-if simulator',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _profile?.name ?? 'Demo profile',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Drag vertically for pressure, horizontally to move a point in '
                'time. Tap the curve to add a point. Tap a point to select it, '
                'then use Remove point — or long-press to delete. Predicted '
                'flow is a simple stub (higher pressure → higher g/s).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('simulator_import_shot'),
                    onPressed: _onImportShotPressed,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Import shot'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('simulator_export_profile'),
                    onPressed: _onExportProfilePressed,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Export profile'),
                  ),
                  FilledButton.icon(
                    key: const Key('simulator_use_on_live'),
                    onPressed: _onUseOnLivePressed,
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: const Text('Use on Live'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Target pressure',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              PressureProfileEditor(
                keyframes: _keyframes,
                durationMs: durationMs,
                onKeyframesChanged: _onKeyframesChanged,
                onGestureActiveChanged: (active) {
                  setState(() => _profileEditorActive = active);
                },
              ),
              const SizedBox(height: 16),
              _PredictedFlowMetrics(
                key: const Key('simulator_predicted_flow'),
                summary: summary,
              ),
              const SizedBox(height: 12),
              DualCurveChart(
                key: const Key('simulator_flow_chart'),
                samples: predictedSamples,
                maxDurationMs: durationMs,
                showPressure: true,
                showWeight: false,
                showFlow: true,
                enableInteraction: false,
                targetPressureSamples: pressureProfile,
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PredictedFlowMetrics extends StatelessWidget {
  const _PredictedFlowMetrics({
    required this.summary,
    super.key,
  });

  final PredictedFlowSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Predicted flow (stub)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Peak flow',
                  value: '${summary.peakFlowGs.toStringAsFixed(2)} g/s',
                  valueKey: const Key('simulator_peak_flow_value'),
                ),
                _MetricChip(
                  label: 'Avg flow',
                  value: '${summary.averageFlowGs.toStringAsFixed(2)} g/s',
                  valueKey: const Key('simulator_avg_flow_value'),
                ),
                _MetricChip(
                  label: 'Peak pressure',
                  value: '${summary.peakPressureBar.toStringAsFixed(1)} bar',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value,
          key: valueKey,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

@immutable
class _SimulatorState {
  const _SimulatorState({
    required this.profile,
    required this.keyframes,
  });

  final SavedProfile profile;
  final List<PressureKeyframe> keyframes;
}

Future<SavedProfile> _demoProfileFromFixture() async {
  final shot = await _loadDemoShotFromFixture();
  return SavedProfile.fromShot(
    shot,
    id: 'demo-profile',
    name: 'Starter profile',
    createdAt: DateTime.utc(2026, 6, 29),
  );
}

Future<Shot> _loadDemoShotFromFixture() async {
  try {
    final bundled = await rootBundle.loadString('assets/minimal_shot.json');
    return Shot.fromJson(jsonDecode(bundled) as Map<String, dynamic>);
  } on Object {
    try {
      final json = jsonDecode(
        File(_fixturePath('shots/minimal_shot.json')).readAsStringSync(),
      ) as Map<String, dynamic>;
      return Shot.fromJson(json);
    } on Object {
      return _builtinDemoShot();
    }
  }
}

Shot _builtinDemoShot() {
  return Shot(
    id: 'shot-builtin-demo',
    startedAt: DateTime.utc(2026, 6, 29, 10),
    endedAt: DateTime.utc(2026, 6, 29, 10, 0, 28, 500),
    samples: const [
      ShotSample(elapsedMs: 0, pressureBar: 0, weightG: 0, flowGs: 0),
      ShotSample(elapsedMs: 6000, pressureBar: 4, weightG: 8, flowGs: 0.8),
      ShotSample(elapsedMs: 12000, pressureBar: 6, weightG: 16, flowGs: 1.1),
      ShotSample(elapsedMs: 18000, pressureBar: 8, weightG: 24, flowGs: 1.0),
      ShotSample(elapsedMs: 28000, pressureBar: 5, weightG: 36, flowGs: 0.6),
    ],
  );
}

/// Prompts for a profile name before export or Live handoff.
Future<String?> promptSimulatorProfileName(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _SimulatorProfileNameDialog(
      initialName: initialName,
    ),
  );
}

class _SimulatorProfileNameDialog extends StatefulWidget {
  const _SimulatorProfileNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_SimulatorProfileNameDialog> createState() =>
      _SimulatorProfileNameDialogState();
}

class _SimulatorProfileNameDialogState extends State<_SimulatorProfileNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('simulator_profile_name_dialog'),
      title: const Text('Profile name'),
      content: TextField(
        key: const Key('simulator_profile_name_field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Name',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('simulator_profile_name_save'),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Shows a picker dialog for importing a saved shot into the simulator.
Future<Shot?> pickShotForSimulator(
  BuildContext context, {
  required ShotRepository repository,
}) async {
  final shots = await repository.listShots(includeSamples: true);
  if (!context.mounted) {
    return null;
  }

  if (shots.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('simulator_import_empty_dialog'),
        title: const Text('No shots yet'),
        content: const Text(
          'Record a shot on the Live tab first, then import it here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return null;
  }

  return showDialog<Shot>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        key: const Key('simulator_import_shot_dialog'),
        title: const Text('Import shot'),
        children: [
          for (final shot in shots)
            SimpleDialogOption(
              key: Key('simulator_import_shot_${shot.id}'),
              onPressed: () => Navigator.of(context).pop(shot),
              child: Text(_shotPickerLabel(shot)),
            ),
        ],
      );
    },
  );
}

String _shotPickerLabel(Shot shot) {
  final started = shot.startedAt.toLocal();
  final label =
      '${started.year}-${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')} '
      '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
  if (shot.yieldG != null) {
    return '$label · ${shot.yieldG!.toStringAsFixed(0)} g';
  }
  return '$label · ${shot.samples.length} samples';
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
    '../../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}