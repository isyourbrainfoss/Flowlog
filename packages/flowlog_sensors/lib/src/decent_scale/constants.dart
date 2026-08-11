/// BLE identifiers and timing for the Decent Scale.
abstract final class DecentScaleConstants {
  /// Advertised BLE device name.
  static const deviceName = 'Decent Scale';

  /// FFF0 primary service.
  static const serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';

  /// FFF4 — weight, button, and command acknowledgements (notify).
  static const notifyUuid = '0000fff4-0000-1000-8000-00805f9b34fb';

  /// 36F5 — outbound commands (write).
  static const writeUuid = '000036f5-0000-1000-8000-00805f9b34fb';

  /// Model byte present in every command and notification.
  static const modelByte = 0x03;

  /// Minimum spacing between outbound commands (firmware may drop bursts).
  static const minCommandSpacing = Duration(milliseconds: 200);

  /// Heartbeat period while connected. Must be comfortably under the scale's
  /// disconnect timeout (Flowlog DIY uses 15 s; real HDS is ~5 s).
  ///
  /// Keep well above [minCommandSpacing] and leave headroom for pressure
  /// forward writes so FFF4 weight traffic is not starved.
  static const heartbeatInterval = Duration(seconds: 3);

  /// FFF4 type bytes for weight notifications.
  static const weightStableType = 0xCE;
  static const weightChangingType = 0xCA;

  /// Expected outbound command length (model + type + 4 data + XOR).
  static const commandLength = 7;
}