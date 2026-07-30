import 'constants.dart';

/// Outbound Decent Scale BLE commands (7-byte packets with XOR checksum).
abstract final class DecentScaleCommands {
  /// XOR of the first six bytes (`model ^ type ^ data[0..3]`).
  static int xorChecksum(List<int> firstSixBytes) {
    if (firstSixBytes.length != 6) {
      throw ArgumentError.value(
        firstSixBytes,
        'firstSixBytes',
        'expected exactly 6 bytes',
      );
    }
    return firstSixBytes.reduce((a, b) => a ^ b) & 0xFF;
  }

  static List<int> _build(int type, List<int> data) {
    if (data.length != 4) {
      throw ArgumentError.value(data, 'data', 'expected exactly 4 data bytes');
    }
    final head = [DecentScaleConstants.modelByte, type, ...data];
    return [...head, xorChecksum(head)];
  }

  /// Tare with heartbeat-aware byte 5 (`030F000000010D`).
  static List<int> tare({bool heartbeatAware = true}) => _build(
        0x0F,
        [0x00, 0x00, 0x00, heartbeatAware ? 0x01 : 0x00],
      );

  /// LED on, grams display (`030A0101000108`). Starts the weight stream.
  static List<int> ledOnGrams({bool heartbeatAware = true}) => _build(
        0x0A,
        [0x01, 0x01, 0x00, heartbeatAware ? 0x01 : 0x00],
      );

  /// LED off (`030A0000000009`).
  static List<int> ledOff() => _build(0x0A, [0x00, 0x00, 0x00, 0x00]);

  /// Timer start (`030B030000000B`).
  static List<int> timerStart() => _build(0x0B, [0x03, 0x00, 0x00, 0x00]);

  /// Timer stop (`030B0000000008`).
  static List<int> timerStop() => _build(0x0B, [0x00, 0x00, 0x00, 0x00]);

  /// Timer reset (`030B020000000A`).
  static List<int> timerReset() => _build(0x0B, [0x02, 0x00, 0x00, 0x00]);

  /// Half Decent Scale heartbeat (`03 0a 03 ff ff 00 0a`).
  static List<int> heartbeat() => _build(0x0A, [0x03, 0xFF, 0xFF, 0x00]);

  // --- Flowlog DIY scale extensions (type 0xF0+) ---
  // Phone keeps the Pressensor BLE link; these mirror live pressure onto the
  // scale OLED during an app brew. Phone-free brews use PRS on the scale.

  /// Live pressure mirror: mbar as big-endian int16 in data bytes 0–1.
  ///
  /// Example: 9.0 bar → 9000 mbar → `03 F0 23 28 00 00 XX`.
  static List<int> phonePressure(double pressureBar) {
    var mbar = (pressureBar * 1000).round();
    if (mbar > 32767) mbar = 32767;
    if (mbar < -32768) mbar = -32768;
    final hi = (mbar >> 8) & 0xFF;
    final lo = mbar & 0xFF;
    return _build(0xF0, [hi, lo, 0x00, 0x00]);
  }

  /// App brew started — scale frees PRS, tares, shows phone pressure.
  static List<int> phoneBrewStart() => _build(0xF1, [0x00, 0x00, 0x00, 0x00]);

  /// App brew ended.
  static List<int> phoneBrewEnd() => _build(0xF2, [0x00, 0x00, 0x00, 0x00]);

  /// OLED / brew cues on Flowlog DIY scale.
  ///
  /// Bytes: target yield (g), warn at (g), pressure bar min (bar), max (bar).
  /// Each is a uint8 (0–255). Example: 36 g target, 34 g warn, 5–10 bar →
  /// `03 F3 24 22 05 0A XX`.
  static List<int> scaleDisplayConfig({
    required int targetYieldG,
    required int warnAtG,
    required int pressureMinBar,
    required int pressureMaxBar,
  }) {
    int clampU8(int v) => v.clamp(0, 255);
    return _build(0xF3, [
      clampU8(targetYieldG),
      clampU8(warnAtG),
      clampU8(pressureMinBar),
      clampU8(pressureMaxBar),
    ]);
  }

  // --- Shot export over BLE (DIY scale firmware ≥1.6) ---
  // Write 0xF4; scale replies on FFF4 with 0xF4 list, 0xF5 chunks, or 0xF6 status.

  /// Request sizes of stored shots (up to 3). Reply type `0xF4`.
  static List<int> shotExportList() => _build(0xF4, [0x00, 0x00, 0x00, 0x00]);

  /// Request full JSON transfer for shot [age] (0 = newest). Chunks type `0xF5`.
  static List<int> shotExportGet({int age = 0}) =>
      _build(0xF4, [0x01, age.clamp(0, 2), 0x00, 0x00]);

  /// Request Wi‑Fi IP / status string. Reply type `0xF6`.
  static List<int> shotExportStatus() => _build(0xF4, [0x02, 0x00, 0x00, 0x00]);
}