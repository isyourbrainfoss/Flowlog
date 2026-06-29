/// Defaults for the Half Decent Scale WiFi WebSocket endpoint (openscale 3.x).
abstract final class WifiScaleConstants {
  /// mDNS hostname advertised on the LAN.
  static const defaultHost = 'hds.local';

  /// WebSocket path for weight snapshots and control commands.
  static const snapshotPath = '/snapshot';

  /// Default stream rate negotiated after connect (2 Hz firmware default).
  static const defaultRateCommand = 'rate 2k';

  /// Builds `ws://{host}/snapshot`.
  static Uri websocketUri({String host = defaultHost}) {
    return Uri.parse('ws://$host$snapshotPath');
  }
}