import 'package:flowlog_core/flowlog_core.dart';
import 'package:meta/meta.dart';

/// A single sensor reading emitted by a [SensorAdapter].
///
/// Maps cleanly to [ShotSample] when samples are merged for shot recording.
@immutable
class SensorSample {
  const SensorSample({
    required this.elapsedMs,
    this.pressureBar,
    this.weightG,
    this.tempC,
    this.flowGs,
  });

  /// Elapsed time since stream start, in milliseconds.
  final int elapsedMs;

  final double? pressureBar;
  final double? weightG;
  final double? tempC;
  final double? flowGs;

  /// Elapsed time as a [Duration] (alias for [elapsedMs]).
  Duration get t => Duration(milliseconds: elapsedMs);

  /// Converts this reading to a core [ShotSample] for persistence.
  ShotSample toShotSample() {
    return ShotSample(
      elapsedMs: elapsedMs,
      pressureBar: pressureBar,
      weightG: weightG,
      tempC: tempC,
      flowGs: flowGs,
    );
  }

  SensorSample copyWith({
    int? elapsedMs,
    double? pressureBar,
    double? weightG,
    double? tempC,
    double? flowGs,
  }) {
    return SensorSample(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      pressureBar: pressureBar ?? this.pressureBar,
      weightG: weightG ?? this.weightG,
      tempC: tempC ?? this.tempC,
      flowGs: flowGs ?? this.flowGs,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SensorSample &&
            elapsedMs == other.elapsedMs &&
            pressureBar == other.pressureBar &&
            weightG == other.weightG &&
            tempC == other.tempC &&
            flowGs == other.flowGs;
  }

  @override
  int get hashCode => Object.hash(
        elapsedMs,
        pressureBar,
        weightG,
        tempC,
        flowGs,
      );

  @override
  String toString() =>
      'SensorSample(elapsedMs: $elapsedMs, pressureBar: $pressureBar, '
      'weightG: $weightG, tempC: $tempC, flowGs: $flowGs)';
}