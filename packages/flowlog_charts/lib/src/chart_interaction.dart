import 'dart:math' as math;

import 'package:flowlog_core/flowlog_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// How pressure, weight, and flow curves are laid out.
enum ChartViewMode {
  /// All series on one shared time axis (default).
  overlay,

  /// Stacked mini-charts, one channel each.
  split,

  /// Flow rate only.
  flowOnly,
}

/// Visible time window for chart zoom and pan.
class ChartViewport {
  ChartViewport({
    required int totalDurationMs,
    int visibleStartMs = 0,
    int? visibleDurationMs,
    this.minVisibleDurationMs = 1000,
  })  : _totalDurationMs = math.max(1, totalDurationMs),
        visibleStartMs = visibleStartMs.clamp(
          0,
          math.max(0, totalDurationMs - (visibleDurationMs ?? totalDurationMs)),
        ),
        visibleDurationMs = math.max(
          minVisibleDurationMs,
          math.min(
            visibleDurationMs ?? totalDurationMs,
            totalDurationMs,
          ),
        );

  int _totalDurationMs;
  int visibleStartMs;
  int visibleDurationMs;
  final int minVisibleDurationMs;

  int get totalDurationMs => _totalDurationMs;

  int get visibleEndMs => visibleStartMs + visibleDurationMs;

  bool get isFullyZoomedOut =>
      visibleStartMs <= 0 && visibleDurationMs >= _totalDurationMs;

  void setTotalDuration(int totalDurationMs) {
    _totalDurationMs = math.max(1, totalDurationMs);
    visibleDurationMs = math.min(
      visibleDurationMs,
      math.max(minVisibleDurationMs, _totalDurationMs),
    );
    visibleStartMs = visibleStartMs.clamp(
      0,
      math.max(0, _totalDurationMs - visibleDurationMs),
    );
  }

  void reset() {
    visibleStartMs = 0;
    visibleDurationMs = _totalDurationMs;
  }

  void panByMs(int deltaMs) {
    if (deltaMs == 0) {
      return;
    }
    visibleStartMs = (visibleStartMs + deltaMs).clamp(
      0,
      math.max(0, _totalDurationMs - visibleDurationMs),
    );
  }

  void panByPixels(double deltaPixels, double plotWidth) {
    if (plotWidth <= 0 || deltaPixels == 0) {
      return;
    }
    final deltaMs = (-deltaPixels / plotWidth * visibleDurationMs).round();
    panByMs(deltaMs);
  }

  void zoomAt({
    required double focalFraction,
    required double scaleFactor,
  }) {
    if (scaleFactor <= 0 || !scaleFactor.isFinite) {
      return;
    }

    final clampedFocal = focalFraction.clamp(0.0, 1.0);
    final focalMs =
        visibleStartMs + (visibleDurationMs * clampedFocal).round();
    final newDuration = (visibleDurationMs / scaleFactor)
        .round()
        .clamp(minVisibleDurationMs, _totalDurationMs);
    final newStart = (focalMs - (newDuration * clampedFocal).round()).clamp(
      0,
      math.max(0, _totalDurationMs - newDuration),
    ).toInt();

    visibleDurationMs = newDuration;
    visibleStartMs = newStart;
  }

  void followEnd() {
    // When following the live end, leave a small time margin on the right
    // so the current reading isn't right at the edge of the visible window.
    // This keeps the trace "writing" with some headroom.
    const rightMarginMs = 2500;
    visibleStartMs = math.max(0, _totalDurationMs + rightMarginMs - visibleDurationMs);
  }

  ChartViewport copyWith({
    int? totalDurationMs,
    int? visibleStartMs,
    int? visibleDurationMs,
  }) {
    return ChartViewport(
      totalDurationMs: totalDurationMs ?? _totalDurationMs,
      visibleStartMs: visibleStartMs ?? this.visibleStartMs,
      visibleDurationMs: visibleDurationMs ?? this.visibleDurationMs,
      minVisibleDurationMs: minVisibleDurationMs,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChartViewport &&
        other._totalDurationMs == _totalDurationMs &&
        other.visibleStartMs == visibleStartMs &&
        other.visibleDurationMs == visibleDurationMs &&
        other.minVisibleDurationMs == minVisibleDurationMs;
  }

  @override
  int get hashCode => Object.hash(
        _totalDurationMs,
        visibleStartMs,
        visibleDurationMs,
        minVisibleDurationMs,
      );
}

/// Holds zoom/pan viewport and view-mode state for [DualCurveChart].
class ChartInteractionController extends ChangeNotifier {
  ChartInteractionController({
    this._viewMode = ChartViewMode.overlay,
    this._viewport,
  });

  ChartViewMode _viewMode;
  ChartViewport? _viewport;

  double _baselineScale = 1;
  double _cumulativePanPixels = 0;
  bool _didZoom = false;
  ShotSample? _probeSample;

  ChartViewMode get viewMode => _viewMode;

  ShotSample? get probeSample => _probeSample;

  ChartViewport get viewport {
    return _viewport ??
        ChartViewport(totalDurationMs: 1, visibleDurationMs: 1);
  }

  bool get hasViewport => _viewport != null;

  void setViewMode(ChartViewMode mode) {
    if (_viewMode == mode) {
      return;
    }
    _viewMode = mode;
    notifyListeners();
  }

  void cycleViewMode({bool forward = true}) {
    const modes = ChartViewMode.values;
    final index = modes.indexOf(_viewMode);
    final nextIndex = forward
        ? (index + 1) % modes.length
        : (index - 1 + modes.length) % modes.length;
    setViewMode(modes[nextIndex]);
  }

  /// Updates the viewport duration during chart layout without notifying.
  ///
  /// Callers that rebuild from sample changes (e.g. [ValueListenableBuilder])
  /// should use this during [State.build] to avoid notifying mid-build.
  ///
  /// [totalDurationMs] is the full span needed for all data (live samples + any
  /// target curve). When [liveProgressMs] is provided for live following, the
  /// auto-follow window (grow/scroll) is positioned relative to live progress
  /// so the current pressure trace stays visible near the right even when a
  /// long target curve makes the axis total much larger than current brew time.
  void syncTotalDuration(
    int totalDurationMs, {
    bool followEndWhenZoomedOut = false,
    int? liveProgressMs,
  }) {
    final wasFollowingEnd = _viewport != null &&
        _viewport!.visibleEndMs >= _viewport!.totalDurationMs - 1;
    final wasFullyZoomedOut = _viewport?.isFullyZoomedOut ?? true;

    _viewport ??= ChartViewport(totalDurationMs: totalDurationMs);
    _viewport!.setTotalDuration(totalDurationMs);

    if (followEndWhenZoomedOut) {
      if (wasFullyZoomedOut) {
        // For live following while zoomed all the way out, we want the trace
        // to feel like it's still "moving right" as new data arrives.
        //
        // Strategy:
        // - While the shot is short, grow the visible window from t=0 with a
        //   right margin so the current point isn't at the absolute edge.
        // - Once the shot is longer than a threshold, switch to a scrolling
        //   fixed-size window. The whole chart scrolls left at constant speed,
        //   new data enters from the right, and the current point stays at a
        //   comfortable position near (but not at) the right edge.
        //
        // IMPORTANT: base grow/scroll on [liveProgressMs] (or total as fallback)
        // so a long target curve does not push the viewport start far ahead of
        // actual live data, which would hide the live pressure trace.
        const rightMarginMs = 2500;
        const scrollAfterMs = 30000; // after ~30s switch to scrolling window

        final progress = liveProgressMs ?? totalDurationMs;
        if (progress < scrollAfterMs) {
          _viewport!.visibleDurationMs = progress + rightMarginMs;
          _viewport!.visibleStartMs = 0;
        } else {
          final windowDuration = scrollAfterMs + rightMarginMs;
          _viewport!.visibleDurationMs = windowDuration;
          _viewport!.visibleStartMs = progress + rightMarginMs - windowDuration;
        }
      } else if (wasFollowingEnd) {
        _viewport!.followEnd();
      }
    }
  }

  void resetViewport() {
    _viewport?.reset();
    notifyListeners();
  }

  void setProbeFromElapsedMs(int elapsedMs, List<ShotSample> samples) {
    final nearest = nearestShotSample(samples, elapsedMs);
    if (_probeSample == nearest) {
      return;
    }
    _probeSample = nearest;
    notifyListeners();
  }

  void clearProbe() {
    if (_probeSample == null) {
      return;
    }
    _probeSample = null;
    notifyListeners();
  }

  void onScaleStart(ScaleStartDetails details) {
    _baselineScale = 1;
    _cumulativePanPixels = 0;
    _didZoom = false;
  }

  void onScaleUpdate(ScaleUpdateDetails details, double plotWidth) {
    if (plotWidth <= 0 || _viewport == null) {
      return;
    }

    if (details.scale != 1) {
      final scaleDelta = details.scale / _baselineScale;
      if ((scaleDelta - 1).abs() > 0.001) {
        _viewport!.zoomAt(
          focalFraction: details.localFocalPoint.dx / plotWidth,
          scaleFactor: scaleDelta,
        );
        _baselineScale = details.scale;
        _didZoom = true;
        notifyListeners();
      }
    }

    if (details.focalPointDelta.dx != 0) {
      _viewport!.panByPixels(details.focalPointDelta.dx, plotWidth);
      _cumulativePanPixels += details.focalPointDelta.dx;
      notifyListeners();
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    if (_viewport == null) {
      return;
    }

    const swipeThreshold = 72.0;
    final horizontalVelocity = details.velocity.pixelsPerSecond.dx;

    if (!_didZoom &&
        _viewport!.isFullyZoomedOut &&
        (_cumulativePanPixels.abs() >= swipeThreshold ||
            horizontalVelocity.abs() >= 650)) {
      if (_cumulativePanPixels < 0 || horizontalVelocity < 0) {
        cycleViewMode(forward: true);
      } else if (_cumulativePanPixels > 0 || horizontalVelocity > 0) {
        cycleViewMode(forward: false);
      }
    }

    _baselineScale = 1;
    _cumulativePanPixels = 0;
    _didZoom = false;
  }
}

/// Returns the sample whose [ShotSample.elapsedMs] is closest to [elapsedMs].
ShotSample? nearestShotSample(List<ShotSample> samples, int elapsedMs) {
  if (samples.isEmpty) {
    return null;
  }

  ShotSample? nearest;
  var bestDistance = 1 << 62;
  for (final sample in samples) {
    final distance = (sample.elapsedMs - elapsedMs).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      nearest = sample;
    }
  }
  return nearest;
}