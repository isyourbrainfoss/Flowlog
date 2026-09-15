import 'dart:math' as math;

import 'models/shot_sample.dart';

/// Default lookback for weight slope (g/s).
///
/// The DIY / Decent scale is 0.1 g at ~10 Hz. Live recording merges that
/// onto every Pressensor tick (~10–40 ms) by carrying the last grams forward.
/// Adjacent-sample dw/dt then turns a 0.1 g step over 2 ms into 50 g/s, which
/// is what made History/Live flow charts look like a comb. 800 ms is long
/// enough that 0.1 g is 0.125 g/s of resolution, and short enough to still
/// show bloom.
const int kDefaultFlowWindowMs = 800;

/// Derives smoothed espresso flow rate (g/s) from a weight time series.
class FlowRateCalculator {
  const FlowRateCalculator({
    this.maxGapMs = 3000,
    this.windowMs = kDefaultFlowWindowMs,
    this.minWindowMs,
  });

  /// Gaps longer than this reset the window (missing scale ticks).
  final int maxGapMs;

  /// Time span used for dw/dt instead of consecutive merged samples.
  final int windowMs;

  /// Ignore spans shorter than this so the first 0.1 g BLE step cannot
  /// become 4–50 g/s before the window is populated.
  ///
  /// Null means half of [windowMs].
  final int? minWindowMs;

  /// Returns [samples] with [ShotSample.flowGs] populated from [ShotSample.weightG].
  List<ShotSample> compute(List<ShotSample> samples) {
    if (samples.isEmpty) {
      return const [];
    }

    final weightIndexes = <int>[];
    for (var i = 0; i < samples.length; i++) {
      if (samples[i].weightG != null) {
        weightIndexes.add(i);
      }
    }

    if (weightIndexes.isEmpty) {
      return List<ShotSample>.from(samples);
    }

    final flows = List<double?>.filled(samples.length, null);
    var windowStart = 0;
    double? lastFlow;

    for (var k = 0; k < weightIndexes.length; k++) {
      final i = weightIndexes[k];
      final sample = samples[i];
      final timeMs = sample.elapsedMs;

      if (k == 0) {
        flows[i] = 0.0;
        lastFlow = 0.0;
        continue;
      }

      final windowStartMs = timeMs - windowMs;
      while (windowStart < k - 1 &&
          samples[weightIndexes[windowStart + 1]].elapsedMs <= windowStartMs) {
        windowStart++;
      }

      final previous = samples[weightIndexes[windowStart]];
      final elapsedDeltaMs = timeMs - previous.elapsedMs;

      if (elapsedDeltaMs > maxGapMs) {
        flows[i] = 0.0;
        lastFlow = 0.0;
        windowStart = k;
        continue;
      }
      if (elapsedDeltaMs <= 0) {
        flows[i] = lastFlow ?? 0.0;
        continue;
      }
      final minSpanMs = minWindowMs ?? math.max(1, windowMs ~/ 2);
      if (elapsedDeltaMs < minSpanMs) {
        flows[i] = lastFlow ?? 0.0;
        continue;
      }

      var rate = _leastSquaresRateGs(samples, weightIndexes, windowStart, k);
      if (rate < 0) {
        rate = 0;
      }
      flows[i] = rate;
      lastFlow = rate;
    }

    return [
      for (var i = 0; i < samples.length; i++)
        flows[i] == null ? samples[i] : samples[i].copyWith(flowGs: flows[i]),
    ];
  }

  /// Linear-regression slope over the window. Two-point end-minus-start
  /// jumped whenever a 0.1 g stair entered or left; least-squares follows
  /// the staircase average and stays near the true pour rate.
  static double _leastSquaresRateGs(
    List<ShotSample> samples,
    List<int> weightIndexes,
    int from,
    int to,
  ) {
    var n = 0;
    var sumT = 0.0;
    var sumW = 0.0;
    var sumTW = 0.0;
    var sumT2 = 0.0;
    for (var j = from; j <= to; j++) {
      final sample = samples[weightIndexes[j]];
      final t = sample.elapsedMs / 1000.0;
      final w = sample.weightG!;
      n++;
      sumT += t;
      sumW += w;
      sumTW += t * w;
      sumT2 += t * t;
    }
    if (n < 2) {
      return 0;
    }
    final denom = n * sumT2 - sumT * sumT;
    if (denom.abs() < 1e-12) {
      return 0;
    }
    return (n * sumTW - sumT * sumW) / denom;
  }
}

/// Convenience wrapper around [FlowRateCalculator.compute].
List<ShotSample> computeFlowRates(
  List<ShotSample> samples, {
  int maxGapMs = 3000,
  int windowMs = kDefaultFlowWindowMs,
  int? minWindowMs,
}) {
  return FlowRateCalculator(
    maxGapMs: maxGapMs,
    windowMs: windowMs,
    minWindowMs: minWindowMs,
  ).compute(samples);
}

/// Most recent derived flow, using only the tail that covers [windowMs].
///
/// Live HUD calls this every frame; full-history [computeFlowRates] is for
/// charts and saved shots.
double? latestFlowGs(
  List<ShotSample> samples, {
  int windowMs = kDefaultFlowWindowMs,
}) {
  if (samples.isEmpty) {
    return null;
  }
  final lastT = samples.last.elapsedMs;
  final cutoff = lastT - windowMs - 250;
  var start = 0;
  for (var i = samples.length - 1; i >= 0; i--) {
    if (samples[i].elapsedMs <= cutoff) {
      start = i;
      break;
    }
  }
  final computed = computeFlowRates(
    start == 0 ? samples : samples.sublist(start),
    windowMs: windowMs,
  );
  for (var i = computed.length - 1; i >= 0; i--) {
    final flow = computed[i].flowGs;
    if (flow != null) {
      return flow;
    }
  }
  return null;
}
