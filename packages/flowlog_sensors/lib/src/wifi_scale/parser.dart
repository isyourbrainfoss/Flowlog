import 'dart:convert';

import 'package:meta/meta.dart';

/// A weight snapshot from the openscale WiFi WebSocket stream.
@immutable
class WifiScaleWeightFrame {
  const WifiScaleWeightFrame({
    required this.grams,
    required this.deviceMs,
  });

  /// Weight in grams.
  final double grams;

  /// Device monotonic timestamp in milliseconds (scale clock).
  final int deviceMs;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WifiScaleWeightFrame &&
            grams == other.grams &&
            deviceMs == other.deviceMs;
  }

  @override
  int get hashCode => Object.hash(grams, deviceMs);

  @override
  String toString() => 'WifiScaleWeightFrame(grams: $grams, deviceMs: $deviceMs)';
}

/// Parses an untyped weight snapshot frame:
/// `{"grams": 25.66, "ms": 12345}`.
///
/// Typed frames (`type` field present) are ignored — callers handle those
/// separately (status, rate, error, button, power).
WifiScaleWeightFrame? parseWifiScaleWeightFrame(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    if (decoded.containsKey('type')) {
      return null;
    }

    final grams = decoded['grams'];
    final deviceMs = decoded['ms'];
    if (grams is! num || deviceMs is! num) {
      return null;
    }

    return WifiScaleWeightFrame(
      grams: grams.toDouble(),
      deviceMs: deviceMs.round(),
    );
  } on FormatException {
    return null;
  }
}