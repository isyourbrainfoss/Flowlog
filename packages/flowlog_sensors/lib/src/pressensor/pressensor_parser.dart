/// Pure Dart parsing for Pressensor PRS pressure notifications.
library;

/// A decoded pressure notification from a PRS device.
class PressensorReading {
  const PressensorReading({
    required this.pressureBar,
    this.tempC,
  });

  /// Pressure in bar (converted from millibar).
  final double pressureBar;

  /// Temperature in °C when present (every 16th notification).
  final double? tempC;
}

/// Reads a signed 16-bit big-endian integer from [data] at [offset].
int readInt16BigEndian(List<int> data, int offset) {
  if (offset + 1 >= data.length) {
    throw FormatException(
      'Need at least 2 bytes at offset $offset, got ${data.length}',
    );
  }
  final unsigned = (data[offset] << 8) | data[offset + 1];
  return unsigned.toSigned(16);
}

/// Parses a PRS pressure notify payload.
///
/// - 2 bytes: pressure only (millibar, big-endian signed int16).
/// - 4 bytes: pressure + temperature (temp is tenths of °C, big-endian signed).
///
/// Pressure is returned in bar (`mbar / 1000`).
PressensorReading parsePressureNotify(List<int> data) {
  if (data.length < 2) {
    throw FormatException(
      'Pressensor notify must be at least 2 bytes, got ${data.length}',
    );
  }

  final mbar = readInt16BigEndian(data, 0);
  final pressureBar = mbar / 1000.0;

  double? tempC;
  if (data.length >= 4) {
    final tempTenthsC = readInt16BigEndian(data, 2);
    tempC = tempTenthsC / 10.0;
  }

  return PressensorReading(pressureBar: pressureBar, tempC: tempC);
}