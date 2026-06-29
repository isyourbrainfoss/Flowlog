import 'flow_rate.dart';
import 'models/shot_sample.dart';

/// Settings stub for auto shot detection (persisted in the app layer later).
class ShotDetectSettings {
  const ShotDetectSettings({
    this.flowThresholdGs = 0.2,
  });

  /// Flow rate (g/s) above which the espresso shot is considered started.
  final double flowThresholdGs;
}

/// Outcome of [ShotDetector.detect].
class ShotDetectionResult {
  const ShotDetectionResult({
    required this.detected,
    this.shotStartElapsedMs,
    required this.samples,
  });

  /// Whether flow exceeded [ShotDetectSettings.flowThresholdGs].
  final bool detected;

  /// Original elapsed time of the first sample included in [samples].
  final int? shotStartElapsedMs;

  /// Samples from shot start onward with [ShotSample.elapsedMs] rebased to zero.
  final List<ShotSample> samples;
}

/// Detects shot start from the first flow sample above a threshold and rebases
/// time to t=0 at that point.
class ShotDetector {
  const ShotDetector({
    this.settings = const ShotDetectSettings(),
    FlowRateCalculator? flowRateCalculator,
  }) : flowRateCalculator = flowRateCalculator ?? const FlowRateCalculator();

  final ShotDetectSettings settings;
  final FlowRateCalculator flowRateCalculator;

  /// Finds the first sample whose smoothed flow exceeds [settings.flowThresholdGs].
  ///
  /// Returns samples from that point with elapsed times shifted so shot start is
  /// 0 ms. When nothing crosses the threshold, [ShotDetectionResult.detected] is
  /// false and [ShotDetectionResult.samples] contains flow-enriched input.
  ShotDetectionResult detect(List<ShotSample> samples) {
    if (samples.isEmpty) {
      return const ShotDetectionResult(detected: false, samples: []);
    }

    final withFlow = flowRateCalculator.compute(samples);
    final threshold = settings.flowThresholdGs;

    for (var i = 0; i < withFlow.length; i++) {
      final flow = withFlow[i].flowGs;
      if (flow != null && flow > threshold) {
        final originMs = withFlow[i].elapsedMs;
        final rebased = [
          for (final sample in withFlow.sublist(i))
            sample.copyWith(elapsedMs: sample.elapsedMs - originMs),
        ];
        return ShotDetectionResult(
          detected: true,
          shotStartElapsedMs: originMs,
          samples: rebased,
        );
      }
    }

    return ShotDetectionResult(
      detected: false,
      samples: List<ShotSample>.unmodifiable(withFlow),
    );
  }
}

/// Convenience wrapper around [ShotDetector.detect].
ShotDetectionResult detectShotStart(
  List<ShotSample> samples, {
  double flowThresholdGs = 0.2,
  FlowRateCalculator? flowRateCalculator,
}) {
  return ShotDetector(
    settings: ShotDetectSettings(flowThresholdGs: flowThresholdGs),
    flowRateCalculator: flowRateCalculator,
  ).detect(samples);
}