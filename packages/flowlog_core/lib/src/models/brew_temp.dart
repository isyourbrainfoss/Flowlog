import 'package:meta/meta.dart';

import 'shot_sample.dart';

/// Minimum pressure (bar) for a sample to count toward end brew temperature.
///
/// After the shot, an empty water chamber can produce misleading low readings;
/// the last in-shot reading is used instead.
const double kBrewEndTempMinPressureBar = 1.0;

/// Start and end brew temperatures derived from sensor samples.
@immutable
class BrewTempRange {
  const BrewTempRange({
    this.startTempC,
    this.endTempC,
  });

  final double? startTempC;
  final double? endTempC;

  bool get hasAny => startTempC != null || endTempC != null;

  String format() {
    if (startTempC != null && endTempC != null) {
      return '${_formatOne(startTempC!)} → ${_formatOne(endTempC!)}';
    }
    if (startTempC != null) {
      return _formatOne(startTempC!);
    }
    if (endTempC != null) {
      return _formatOne(endTempC!);
    }
    return '—';
  }

  static String _formatOne(double tempC) {
    return '${tempC.toStringAsFixed(1)} °C';
  }
}

/// Derives brew start/end temperatures from [samples].
///
/// [startTempC] is the first sample with a temperature reading.
/// [endTempC] is the last temperature while pressure is at least
/// [endTempMinPressureBar] (still "in shot").
BrewTempRange brewTempRangeFromSamples(
  Iterable<ShotSample> samples, {
  double endTempMinPressureBar = kBrewEndTempMinPressureBar,
}) {
  double? startTempC;
  double? endTempC;

  for (final sample in samples) {
    final tempC = sample.tempC;
    if (tempC == null) {
      continue;
    }

    startTempC ??= tempC;

    final pressureBar = sample.pressureBar;
    if (pressureBar != null && pressureBar >= endTempMinPressureBar) {
      endTempC = tempC;
    }
  }

  return BrewTempRange(startTempC: startTempC, endTempC: endTempC);
}