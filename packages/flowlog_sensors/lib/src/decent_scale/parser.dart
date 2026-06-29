import 'constants.dart';

/// Device-reported timer fields from a 10-byte FFF4 weight packet (v1.2+).
class DecentScaleTimer {
  const DecentScaleTimer({
    required this.minutes,
    required this.seconds,
    required this.deciseconds,
  });

  final int minutes;
  final int seconds;
  final int deciseconds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DecentScaleTimer &&
            minutes == other.minutes &&
            seconds == other.seconds &&
            deciseconds == other.deciseconds;
  }

  @override
  int get hashCode => Object.hash(minutes, seconds, deciseconds);

  @override
  String toString() =>
      'DecentScaleTimer($minutes:${seconds.toString().padLeft(2, '0')}.$deciseconds)';
}

/// Parsed FFF4 weight notification.
class DecentScaleWeightReading {
  const DecentScaleWeightReading({
    required this.grams,
    required this.isStable,
    this.timer,
  });

  final double grams;
  final bool isStable;
  final DecentScaleTimer? timer;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DecentScaleWeightReading &&
            grams == other.grams &&
            isStable == other.isStable &&
            timer == other.timer;
  }

  @override
  int get hashCode => Object.hash(grams, isStable, timer);

  @override
  String toString() =>
      'DecentScaleWeightReading(grams: $grams, isStable: $isStable, timer: $timer)';
}

/// Parses inbound FFF4 notify payloads from the Decent Scale.
abstract final class DecentScaleParser {
  static int _signedInt16(int high, int low) {
    final unsigned = (high << 8) | low;
    return (unsigned & 0x8000) != 0 ? unsigned - 0x10000 : unsigned;
  }

  static bool _isWeightType(int typeByte) {
    return typeByte == DecentScaleConstants.weightStableType ||
        typeByte == DecentScaleConstants.weightChangingType;
  }

  /// Returns a [DecentScaleWeightReading] when [data] is a 7- or 10-byte weight
  /// packet; otherwise `null`.
  ///
  /// Weight is always read from bytes 2–3 (grams × 10, signed big-endian).
  /// XOR checksums are not enforced — they are deprecated on Half Decent Scale
  /// and may be stale in captured fixtures.
  static DecentScaleWeightReading? parseWeight(List<int> data) {
    if (data.length < 7) return null;
    if (data.first != DecentScaleConstants.modelByte) return null;

    final typeByte = data[1];
    if (!_isWeightType(typeByte)) return null;

    final raw = _signedInt16(data[2], data[3]);
    final grams = raw / 10.0;
    final isStable = typeByte == DecentScaleConstants.weightStableType;

    DecentScaleTimer? timer;
    if (data.length >= 10) {
      timer = DecentScaleTimer(
        minutes: data[4],
        seconds: data[5],
        deciseconds: data[6],
      );
    }

    return DecentScaleWeightReading(
      grams: grams,
      isStable: isStable,
      timer: timer,
    );
  }
}