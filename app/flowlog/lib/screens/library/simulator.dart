import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flowlog/persistence/flowlog_storage.dart';
import 'package:flowlog/screens/live/repeat_shot.dart';
import 'package:flowlog/screens/live/target_brew.dart';
import 'package:flowlog/shell/app_destinations.dart';
import 'package:flowlog/shell/shell_scope.dart';
import 'package:flowlog/widgets/fullscreen_plot.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Default simulator timeline length.
const int kSimulatorDefaultDurationMs = 30000;

/// Preset timeline lengths for the pressure profile editor.
const List<int> kSimulatorDurationPresetsMs = [
  30000,
  45000,
  60000,
  90000,
  120000,
];

/// Minimum spacing between editable keyframes (ms).
const int kSimulatorMinKeyframeSpacingMs = 1500;

/// Suggests a timeline duration that fits [contentMs] (last keyframe or shot end).
int suggestSimulatorTimelineDuration(int contentMs) {
  if (contentMs <= 0) {
    return kSimulatorDefaultDurationMs;
  }

  for (final preset in kSimulatorDurationPresetsMs) {
    if (contentMs <= preset) {
      return preset;
    }
  }

  final rounded = ((contentMs + 14999) ~/ 15000) * 15000;
  return rounded.clamp(
    kSimulatorDurationPresetsMs.last,
    180000,
  );
}

/// Default keyframe times spread across [durationMs].
List<int> simulatorKeyframeTimesForDuration(int durationMs) {
  final end = durationMs.clamp(1000, 600000);
  return [
    0,
    (end * 0.2).round(),
    (end * 0.4).round(),
    (end * 0.6).round(),
    (end * 0.93).round().clamp(0, end),
  ];
}

/// Keeps keyframes inside [durationMs] while preserving minimum spacing.
List<PressureKeyframe> clampKeyframesToTimeline(
  List<PressureKeyframe> keyframes,
  int durationMs,
) {
  if (keyframes.isEmpty) {
    return keyframes;
  }

  final sorted = List<PressureKeyframe>.from(keyframes)
    ..sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
  final result = <PressureKeyframe>[];

  for (var i = 0; i < sorted.length; i++) {
    var elapsedMs = sorted[i].elapsedMs.clamp(0, durationMs);
    if (i == 0) {
      elapsedMs = 0;
    } else if (elapsedMs < result.last.elapsedMs + kSimulatorMinKeyframeSpacingMs) {
      elapsedMs = (result.last.elapsedMs + kSimulatorMinKeyframeSpacingMs)
          .clamp(0, durationMs);
    }
    result.add(sorted[i].copyWith(elapsedMs: elapsedMs));
  }

  return result;
}

String formatSimulatorDurationLabel(int durationMs) {
  final totalSeconds = (durationMs / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes == 0) {
    return '${seconds}s';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

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
  int durationMs = kSimulatorDefaultDurationMs,
  List<int>? keyframeTimes,
}) {
  final times = keyframeTimes ?? simulatorKeyframeTimesForDuration(durationMs);
  return [
    for (final elapsedMs in times)
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
  static const _minKeyframeSpacingMs = kSimulatorMinKeyframeSpacingMs;
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

  void _updateKeyframeExact(int index, {int? elapsedMs, double? pressureBar}) {
    final keyframes = widget.keyframes;
    if (index < 0 || index >= keyframes.length) {
      return;
    }

    var next = keyframes[index];
    if (pressureBar != null) {
      next = next.copyWith(
        pressureBar: pressureBar.clamp(0, widget.pressureMax).toDouble(),
      );
    }

    if (elapsedMs != null) {
      if (index == 0) {
        next = next.copyWith(elapsedMs: 0);
      } else if (index == keyframes.length - 1) {
        next = next.copyWith(
          elapsedMs: elapsedMs.clamp(0, widget.durationMs),
        );
      } else {
        final minMs = keyframes[index - 1].elapsedMs + _minKeyframeSpacingMs;
        final maxMs = keyframes[index + 1].elapsedMs - _minKeyframeSpacingMs;
        next = next.copyWith(elapsedMs: elapsedMs.clamp(minMs, maxMs));
      }
    }

    final updated = List<PressureKeyframe>.from(keyframes);
    updated[index] = next;
    updated.sort((a, b) => a.elapsedMs.compareTo(b.elapsedMs));
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

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;
    final canRemoveSelected =
        selectedIndex != null && _canDeleteKeyframe(selectedIndex);
    final surfaceStyle = ChartSurfaceStyle.fromColorScheme(
      Theme.of(context).colorScheme,
    );

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
                      surfaceStyle: surfaceStyle,
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
            _SelectedKeyframeEditor(
              key: ValueKey('simulator_keyframe_editor_$selectedIndex'),
              keyframe: widget.keyframes[selectedIndex],
              index: selectedIndex,
              durationMs: widget.durationMs,
              pressureMax: widget.pressureMax,
              isFirst: selectedIndex == 0,
              isLast: selectedIndex == widget.keyframes.length - 1,
              canRemove: canRemoveSelected,
              onChanged: (elapsedMs, pressureBar) => _updateKeyframeExact(
                selectedIndex,
                elapsedMs: elapsedMs,
                pressureBar: pressureBar,
              ),
              onRemove: () => _deleteKeyframe(selectedIndex),
            ),
          ],
        ],
      ),
    );
  }
}

/// Exact time/pressure fields for the selected profile keyframe.
class _SelectedKeyframeEditor extends StatefulWidget {
  const _SelectedKeyframeEditor({
    required this.keyframe,
    required this.index,
    required this.durationMs,
    required this.pressureMax,
    required this.isFirst,
    required this.isLast,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final PressureKeyframe keyframe;
  final int index;
  final int durationMs;
  final double pressureMax;
  final bool isFirst;
  final bool isLast;
  final bool canRemove;
  final void Function(int? elapsedMs, double? pressureBar) onChanged;
  final VoidCallback onRemove;

  @override
  State<_SelectedKeyframeEditor> createState() => _SelectedKeyframeEditorState();
}

class _SelectedKeyframeEditorState extends State<_SelectedKeyframeEditor> {
  late final TextEditingController _timeController;
  late final TextEditingController _pressureController;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: _formatTime(widget.keyframe));
    _pressureController =
        TextEditingController(text: _formatPressure(widget.keyframe));
  }

  @override
  void didUpdateWidget(covariant _SelectedKeyframeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyframe != widget.keyframe) {
      _timeController.text = _formatTime(widget.keyframe);
      _pressureController.text = _formatPressure(widget.keyframe);
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _pressureController.dispose();
    super.dispose();
  }

  String _formatTime(PressureKeyframe keyframe) {
    return (keyframe.elapsedMs / 1000).toStringAsFixed(1);
  }

  String _formatPressure(PressureKeyframe keyframe) {
    return keyframe.pressureBar.toStringAsFixed(1);
  }

  void _applyTime() {
    if (widget.isFirst) {
      return;
    }
    final seconds = double.tryParse(_timeController.text.trim());
    if (seconds == null) {
      return;
    }
    widget.onChanged((seconds * 1000).round(), null);
  }

  void _applyPressure() {
    final pressure = double.tryParse(_pressureController.text.trim());
    if (pressure == null) {
      return;
    }
    widget.onChanged(null, pressure);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('simulator_keyframe_time'),
                controller: _timeController,
                readOnly: widget.isFirst,
                decoration: const InputDecoration(
                  labelText: 'Time (s)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _applyTime(),
                onEditingComplete: _applyTime,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('simulator_keyframe_pressure'),
                controller: _pressureController,
                decoration: InputDecoration(
                  labelText: 'Pressure (bar)',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  helperText: '0–${widget.pressureMax.toStringAsFixed(0)}',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) => _applyPressure(),
                onEditingComplete: _applyPressure,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                widget.isFirst
                    ? 'Start point is fixed at 0 s'
                    : widget.isLast
                        ? 'End point can move up to '
                            '${formatSimulatorDurationLabel(widget.durationMs)}'
                        : 'Drag horizontally to move in time, vertically for pressure',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (widget.canRemove)
              TextButton.icon(
                key: const Key('simulator_remove_point'),
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove point'),
              ),
          ],
        ),
      ],
    );
  }
}

class _PressureProfileEditorPainter extends CustomPainter {
  _PressureProfileEditorPainter({
    required this.keyframes,
    required this.durationMs,
    required this.pressureMax,
    required this.surfaceStyle,
    this.activeIndex,
    this.selectedIndex,
  });

  final List<PressureKeyframe> keyframes;
  final int durationMs;
  final double pressureMax;
  final ChartSurfaceStyle surfaceStyle;
  final int? activeIndex;
  final int? selectedIndex;

  static const leftPad = 48.0;
  static const rightPad = 16.0;
  static const topPad = 12.0;
  static const bottomPad = 28.0;

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
      Paint()..color = surfaceStyle.background,
    );

    _drawGrid(canvas, plot);
    _drawAxes(canvas, plot);
    _drawProfile(canvas, plot, size);
    _drawHandles(canvas, size);
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final gridPaint = Paint()
      ..color = surfaceStyle.grid.withValues(alpha: 0.25)
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
    final textStyle = TextStyle(
      color: surfaceStyle.axisLabel,
      fontSize: 10,
    );

    for (var i = 0; i <= 4; i++) {
      final pressure = pressureMax * (4 - i) / 4;
      final y = plot.top + (plot.height / 4) * i;
      _paintText(
        canvas,
        pressure == pressure.roundToDouble()
            ? '${pressure.toInt()}'
            : pressure.toStringAsFixed(1),
        Offset(4, y - 6),
        textStyle,
      );
    }

    for (var i = 0; i <= 5; i++) {
      final elapsedMs = (durationMs * i / 5).round();
      final x = plot.left + (plot.width / 5) * i;
      _paintText(
        canvas,
        _formatAxisTime(elapsedMs),
        Offset(x - 8, plot.bottom + 4),
        textStyle,
      );
    }

    _paintText(canvas, 'bar', Offset(4, topPad - 2), textStyle);
  }

  String _formatAxisTime(int elapsedMs) {
    final seconds = elapsedMs / 1000;
    if (seconds == seconds.roundToDouble()) {
      return '${seconds.toInt()}s';
    }
    return '${seconds.toStringAsFixed(1)}s';
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
      ..color = surfaceStyle.targetPressureLine
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
                ? surfaceStyle.targetPressureLine
                : FlowlogChartColors.pressureLine;
      final strokePaint = Paint()
        ..color = surfaceStyle.axisLabel
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 2;

      canvas.drawCircle(point, radius, fillPaint);
      canvas.drawCircle(point, radius, strokePaint);
      if (isSelected && !isActive) {
        canvas.drawCircle(
          point,
          radius + 4,
          Paint()
            ..color = surfaceStyle.targetPressureLine.withValues(alpha: 0.35)
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

  @override
  bool shouldRepaint(covariant _PressureProfileEditorPainter oldDelegate) {
    return oldDelegate.keyframes != keyframes ||
        oldDelegate.durationMs != durationMs ||
        oldDelegate.pressureMax != pressureMax ||
        oldDelegate.surfaceStyle != surfaceStyle ||
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
  late Future<_SimulatorState> _stateFuture;

  List<PressureKeyframe> _keyframes = const [];
  int _timelineDurationMs = kSimulatorDefaultDurationMs;
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

    _database = await openFlowlogDatabase();
    return _database!;
  }

  Future<_SimulatorState> _loadState() async {
    final repository = await _ensureProfileRepository();
    final profiles = await repository.listProfiles(includeSamples: true);
    final profile = profiles.isNotEmpty
        ? profiles.first
        : await _demoProfileFromFixture();

    final contentMs = profile.pressureSamples.isEmpty
        ? kSimulatorDefaultDurationMs
        : profile.pressureSamples.last.elapsedMs;
    final timelineDurationMs = suggestSimulatorTimelineDuration(contentMs);
    final keyframes = keyframesFromPressureSamples(
      profile.pressureSamples,
      durationMs: timelineDurationMs,
    );
    return _SimulatorState(
      profile: profile,
      keyframes: keyframes,
      timelineDurationMs: timelineDurationMs,
    );
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
    _timelineDurationMs = state.timelineDurationMs;
    _initialized = true;
  }

  void _onKeyframesChanged(List<PressureKeyframe> keyframes) {
    setState(() => _keyframes = keyframes);
  }

  void _setTimelineDuration(int durationMs) {
    setState(() {
      _timelineDurationMs = durationMs;
      _keyframes = clampKeyframesToTimeline(_keyframes, durationMs);
    });
  }

  Future<void> _onTimelineDurationSelected(int? durationMs) async {
    if (durationMs == null) {
      return;
    }

    if (durationMs < 0) {
      final custom = await promptSimulatorDurationMs(
        context,
        initialMs: _timelineDurationMs,
      );
      if (custom != null && mounted) {
        _setTimelineDuration(custom);
      }
      return;
    }

    _setTimelineDuration(durationMs);
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

    final contentMs = math.max(
      BrewSummary.fromShot(shot).durationMs,
      shot.samples.isEmpty ? 0 : shot.samples.last.elapsedMs,
    );
    final timelineDurationMs = suggestSimulatorTimelineDuration(contentMs);

    setState(() {
      _profile = SavedProfile.fromShot(
        shot,
        id: _profile?.id ?? 'simulator-draft',
        name: shot.id,
      );
      _timelineDurationMs = timelineDurationMs;
      _keyframes = keyframesFromPressureSamples(
        shot.samples,
        durationMs: timelineDurationMs,
      );
    });
  }

  Future<void> _onLoadSavedSimulation() async {
    final repository = await _ensureProfileRepository();
    if (!mounted) {
      return;
    }

    final profiles = await repository.listProfiles(includeSamples: true);
    if (!mounted || profiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved profiles to load')),
        );
      }
      return;
    }

    final selected = await showDialog<SavedProfile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Load simulation'),
        children: [
          for (final p in profiles)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p),
              child: Text(p.name),
            ),
        ],
      ),
    );

    if (selected != null && mounted) {
      final samples = selected.pressureSamples;
      final contentMs = samples.isEmpty ? _timelineDurationMs : samples.last.elapsedMs;
      final dur = suggestSimulatorTimelineDuration(contentMs);
      final kfs = keyframesFromPressureSamples(samples, durationMs: dur);
      setState(() {
        _profile = selected;
        _keyframes = kfs;
        _timelineDurationMs = dur;
      });
    }
  }

  Future<void> _onLoadCurrentTarget() async {
    final target = TargetBrewScope.maybeOf(context);
    if (target == null || !target.hasTarget || target.pressureSamples.isEmpty || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No current target brew set')),
        );
      }
      return;
    }
    final samples = target.pressureSamples;
    final contentMs = samples.last.elapsedMs;
    final dur = suggestSimulatorTimelineDuration(contentMs);
    final kfs = keyframesFromPressureSamples(samples, durationMs: dur);
    setState(() {
      _profile = null;
      _keyframes = kfs;
      _timelineDurationMs = dur;
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

  Future<void> _onSetDefaultTargetPressed() async {
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

    await setDefaultTargetBrew(
      context: context,
      profile: profile,
      profileRepository: repository,
    );

    if (!mounted) {
      return;
    }

    setState(() => _profile = profile);
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
    if (!mounted) {
      return;
    }

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

        final displayName = (_profile ?? state.profile).name;

        final pressureProfile = expandKeyframesToProfile(_keyframes);
        final predictedSamples = buildPredictedFlowSamples(pressureProfile);
        final summary = summarizePredictedFlow(predictedSamples);
        final durationMs = _timelineDurationMs;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header outside the scroll view so the loaded profile name is
              // always present in the widget tree (helps tests) and always
              // visible to the user.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What-if simulator',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    key: const Key('simulator_screen'),
                    physics: _profileEditorActive
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
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
                          key: const Key('simulator_load_simulation'),
                          onPressed: _onLoadSavedSimulation,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('Load simulation'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('simulator_load_target'),
                          onPressed: _onLoadCurrentTarget,
                          icon: const Icon(Icons.outlined_flag),
                          label: const Text('Load current target'),
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
                        FilledButton.tonalIcon(
                          key: const Key('simulator_set_default_target'),
                          onPressed: _onSetDefaultTargetPressed,
                          icon: const Icon(Icons.timeline),
                          label: const Text('Set as target brew'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Target pressure',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  DropdownButton<int>(
                    key: const Key('simulator_timeline_duration'),
                    value: kSimulatorDurationPresetsMs.contains(durationMs)
                        ? durationMs
                        : -1,
                    items: [
                      for (final preset in kSimulatorDurationPresetsMs)
                        DropdownMenuItem(
                          value: preset,
                          child: Text(
                            formatSimulatorDurationLabel(preset),
                          ),
                        ),
                      DropdownMenuItem(
                        value: -1,
                        child: Text(
                          'Custom (${formatSimulatorDurationLabel(durationMs)})',
                        ),
                      ),
                    ],
                    onChanged: _onTimelineDurationSelected,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FullscreenPlotButton(
                buttonKey: const Key('simulator_profile_fullscreen_open'),
                onPressed: () => unawaited(
                  openFullscreenPlot(
                    context,
                    scaffoldKey: const Key('simulator_profile_fullscreen_chart'),
                    closeButtonKey: const Key('simulator_profile_fullscreen_close'),
                    builder: (context) => LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          height: constraints.maxHeight,
                          child: PressureProfileEditor(
                            keyframes: _keyframes,
                            durationMs: durationMs,
                            height: constraints.maxHeight,
                            onKeyframesChanged: _onKeyframesChanged,
                            onGestureActiveChanged: (active) {
                              setState(() => _profileEditorActive = active);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              PressureProfileEditor(
                keyframes: _keyframes,
                durationMs: durationMs,
                height: 220,
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
              FullscreenPlotButton(
                buttonKey: const Key('simulator_flow_fullscreen_open'),
                onPressed: () => unawaited(
                  openFullscreenPlot(
                    context,
                    scaffoldKey: const Key('simulator_flow_fullscreen_chart'),
                    closeButtonKey: const Key('simulator_flow_fullscreen_close'),
                    builder: (context) => LayoutBuilder(
                      builder: (context, constraints) {
                        return SizedBox(
                          height: constraints.maxHeight,
                          child: DualCurveChart(
                            key: const Key('simulator_flow_fullscreen_dual_chart'),
                            height: constraints.maxHeight,
                            samples: predictedSamples,
                            maxDurationMs: durationMs,
                            showPressure: true,
                            showWeight: false,
                            showFlow: true,
                            enableInteraction: true,
                            targetPressureSamples: pressureProfile,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
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
          ), // ListView
        ), // RefreshIndicator
      ), // Expanded
    ], // Column children
  ), // Column
); // Scaffold
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
    required this.timelineDurationMs,
  });

  final SavedProfile profile;
  final List<PressureKeyframe> keyframes;
  final int timelineDurationMs;
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

/// Prompts for a custom timeline length in seconds.
Future<int?> promptSimulatorDurationMs(
  BuildContext context, {
  required int initialMs,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => _SimulatorDurationDialog(initialMs: initialMs),
  );
}

class _SimulatorDurationDialog extends StatefulWidget {
  const _SimulatorDurationDialog({required this.initialMs});

  final int initialMs;

  @override
  State<_SimulatorDurationDialog> createState() => _SimulatorDurationDialogState();
}

class _SimulatorDurationDialogState extends State<_SimulatorDurationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.initialMs / 1000).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final seconds = int.tryParse(_controller.text.trim());
    if (seconds == null) {
      return;
    }
    final ms = (seconds * 1000).clamp(5000, 180000);
    Navigator.of(context).pop(ms);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('simulator_duration_dialog'),
      title: const Text('Timeline length'),
      content: TextField(
        key: const Key('simulator_duration_field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Duration (seconds)',
          helperText: 'Between 5 s and 180 s',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('simulator_duration_save'),
          onPressed: _submit,
          child: const Text('Apply'),
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