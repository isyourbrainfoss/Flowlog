import 'package:meta/meta.dart';

/// A single time-series point captured during an espresso shot.
@immutable
class ShotSample {
  const ShotSample({
    required this.elapsedMs,
    this.pressureBar,
    this.weightG,
    this.flowGs,
    this.tempC,
  });

  final int elapsedMs;
  final double? pressureBar;
  final double? weightG;
  final double? flowGs;
  final double? tempC;

  factory ShotSample.fromJson(Map<String, dynamic> json) {
    return ShotSample(
      elapsedMs: json['elapsedMs'] as int,
      pressureBar: (json['pressureBar'] as num?)?.toDouble(),
      weightG: (json['weightG'] as num?)?.toDouble(),
      flowGs: (json['flowGs'] as num?)?.toDouble(),
      tempC: (json['tempC'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'elapsedMs': elapsedMs,
      if (pressureBar != null) 'pressureBar': pressureBar,
      if (weightG != null) 'weightG': weightG,
      if (flowGs != null) 'flowGs': flowGs,
      if (tempC != null) 'tempC': tempC,
    };
  }

  ShotSample copyWith({
    int? elapsedMs,
    double? pressureBar,
    double? weightG,
    double? flowGs,
    double? tempC,
  }) {
    return ShotSample(
      elapsedMs: elapsedMs ?? this.elapsedMs,
      pressureBar: pressureBar ?? this.pressureBar,
      weightG: weightG ?? this.weightG,
      flowGs: flowGs ?? this.flowGs,
      tempC: tempC ?? this.tempC,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShotSample &&
            elapsedMs == other.elapsedMs &&
            pressureBar == other.pressureBar &&
            weightG == other.weightG &&
            flowGs == other.flowGs &&
            tempC == other.tempC;
  }

  @override
  int get hashCode => Object.hash(
        elapsedMs,
        pressureBar,
        weightG,
        flowGs,
        tempC,
      );

  @override
  String toString() =>
      'ShotSample(elapsedMs: $elapsedMs, pressureBar: $pressureBar, '
      'weightG: $weightG, flowGs: $flowGs, tempC: $tempC)';
}