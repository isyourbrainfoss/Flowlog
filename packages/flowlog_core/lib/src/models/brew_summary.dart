import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'shot.dart';
import 'shot_sample.dart';

/// Pressure threshold used to distinguish pre-infusion from high-pressure phase.
const double kHighPressureThresholdBar = 6.0;

/// Derived stats for a completed brew.
@immutable
class BrewSummary {
  const BrewSummary({
    required this.durationMs,
    this.peakPressureBar,
    this.preInfusionMs,
    this.highPressureMs,
    this.autoStartPressureBar,
  });

  final int durationMs;
  final double? peakPressureBar;
  final int? preInfusionMs;
  final int? highPressureMs;
  final double? autoStartPressureBar;

  factory BrewSummary.fromShot(Shot shot) {
    final samples = shot.samples;
    return BrewSummary(
      durationMs: brewDurationMs(shot),
      peakPressureBar: peakPressureBarFromSamples(samples),
      preInfusionMs: preInfusionDurationMs(samples),
      highPressureMs: highPressureDurationMs(samples),
      autoStartPressureBar: shot.autoStartPressureBar,
    );
  }

  String formatDuration() {
    if (durationMs <= 0) {
      return '—';
    }

    final totalSeconds = durationMs / 1000;
    if (totalSeconds < 60) {
      return '${totalSeconds.toStringAsFixed(1)} s';
    }

    final minutes = durationMs ~/ 60000;
    final seconds = ((durationMs % 60000) / 1000).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String formatPeakPressure() {
    final peak = peakPressureBar;
    if (peak == null) {
      return '—';
    }
    return '${peak.toStringAsFixed(1)} bar';
  }

  String formatPreInfusion() {
    if (preInfusionMs == null || preInfusionMs! <= 0) {
      return '—';
    }
    return '${(preInfusionMs! / 1000).toStringAsFixed(1)} s';
  }

  String formatHighPressure() {
    if (highPressureMs == null || highPressureMs! <= 0) {
      return '—';
    }
    return '${(highPressureMs! / 1000).toStringAsFixed(1)} s';
  }

  String formatAutoStartPressure() {
    final p = autoStartPressureBar;
    if (p == null) {
      return '—';
    }
    return '${p.toStringAsFixed(1)} bar';
  }

  String savedMessage({String prefix = 'Shot saved'}) {
    return '$prefix · ${formatDuration()} · ${formatPeakPressure()} peak';
  }
}

/// Elapsed brew time in milliseconds.
int brewDurationMs(Shot shot) {
  if (shot.endedAt != null) {
    return shot.endedAt!.difference(shot.startedAt).inMilliseconds;
  }
  if (shot.samples.isEmpty) {
    return 0;
  }
  return shot.samples.last.elapsedMs;
}

/// Highest pressure reading across [samples], if any.
double? peakPressureBarFromSamples(Iterable<ShotSample> samples) {
  double? peak;
  for (final sample in samples) {
    final pressure = sample.pressureBar;
    if (pressure == null) {
      continue;
    }
    peak = peak == null ? pressure : math.max(peak, pressure);
  }
  return peak;
}

/// Time (ms) from start of samples until pressure first reaches [threshold].
/// Returns null if never reached.
int? preInfusionDurationMs(
  List<ShotSample> samples, {
  double threshold = kHighPressureThresholdBar,
}) {
  for (final s in samples) {
    if ((s.pressureBar ?? 0) >= threshold) {
      return s.elapsedMs;
    }
  }
  return null;
}

/// Duration (ms) spent with pressure >= [threshold].
int? highPressureDurationMs(
  List<ShotSample> samples, {
  double threshold = kHighPressureThresholdBar,
}) {
  int? first, last;
  for (final s in samples) {
    if ((s.pressureBar ?? 0) >= threshold) {
      first ??= s.elapsedMs;
      last = s.elapsedMs;
    }
  }
  if (first == null || last == null) return null;
  return last - first;
}