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
}