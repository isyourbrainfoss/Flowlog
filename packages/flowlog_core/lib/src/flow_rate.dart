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
  });

  /// Gaps longer than this reset the window (missing scale ticks).
  final int maxGapMs;

  /// Time span used for dw/dt instead of consecutive merged samples.
  final int windowMs;

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
      final grams = sample.weightG!;

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

      var rate = (grams - previous.weightG!) / (elapsedDeltaMs / 1000);
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
}

/// Convenience wrapper around [FlowRateCalculator.compute].
List<ShotSample> computeFlowRates(
  List<ShotSample> samples, {
  int maxGapMs = 3000,
  int windowMs = kDefaultFlowWindowMs,
}) {
  return FlowRateCalculator(
    maxGapMs: maxGapMs,
    windowMs: windowMs,
  ).compute(samples);
}
