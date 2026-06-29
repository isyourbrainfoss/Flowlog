import 'models/shot_sample.dart';

/// Derives smoothed espresso flow rate (g/s) from a weight time series.
class FlowRateCalculator {
  const FlowRateCalculator({
    this.maxGapMs = 3000,
    this.windowSize = 3,
  });

  /// Gaps longer than this reset smoothing (missing scale ticks).
  final int maxGapMs;

  /// Simple moving-average window over instantaneous dw/dt samples.
  final int windowSize;

  /// Returns [samples] with [ShotSample.flowGs] populated from [ShotSample.weightG].
  List<ShotSample> compute(List<ShotSample> samples) {
    if (samples.isEmpty) {
      return const [];
    }

    final result = <ShotSample>[];
    final rateBuffer = <double>[];
    int? lastWeightIndex;

    for (var i = 0; i < samples.length; i++) {
      final sample = samples[i];

      if (sample.weightG == null) {
        result.add(sample);
        continue;
      }

      double smoothedFlow;

      if (lastWeightIndex == null) {
        smoothedFlow = 0.0;
        lastWeightIndex = i;
        rateBuffer.clear();
      } else {
        final previous = samples[lastWeightIndex];
        final elapsedDeltaMs = sample.elapsedMs - previous.elapsedMs;

        if (elapsedDeltaMs > maxGapMs) {
          smoothedFlow = 0.0;
          rateBuffer.clear();
          lastWeightIndex = i;
        } else if (elapsedDeltaMs <= 0) {
          final previousFlow = result.isNotEmpty ? result.last.flowGs : null;
          result.add(sample.copyWith(flowGs: previousFlow));
          continue;
        } else {
          var rawRate =
              (sample.weightG! - previous.weightG!) / (elapsedDeltaMs / 1000);
          if (rawRate < 0) {
            rawRate = 0;
          }

          rateBuffer.add(rawRate);
          if (rateBuffer.length > windowSize) {
            rateBuffer.removeAt(0);
          }

          smoothedFlow =
              rateBuffer.reduce((sum, rate) => sum + rate) / rateBuffer.length;
          lastWeightIndex = i;
        }
      }

      result.add(sample.copyWith(flowGs: smoothedFlow));
    }

    return result;
  }
}

/// Convenience wrapper around [FlowRateCalculator.compute].
List<ShotSample> computeFlowRates(
  List<ShotSample> samples, {
  int maxGapMs = 3000,
  int windowSize = 3,
}) {
  return FlowRateCalculator(
    maxGapMs: maxGapMs,
    windowSize: windowSize,
  ).compute(samples);
}