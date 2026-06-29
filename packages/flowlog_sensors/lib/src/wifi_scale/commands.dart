import 'dart:convert';

/// Outbound WebSocket commands for openscale 3.x WiFi mode.
abstract final class WifiScaleCommands {
  /// Legacy text tare command (silent ack for backwards compatibility).
  static const tareText = 'tare';

  /// JSON tare command (returns a typed status ack).
  static String tareJson() => jsonEncode({'command': 'tare'});

  /// Negotiates the WiFi stream rate (supported: `2k`, `5k`, `10k`).
  static String rate(String value) => 'rate $value';
}