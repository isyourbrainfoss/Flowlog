/// BLE identifiers and timing for the Decent Scale.
abstract final class DecentScaleConstants {
  /// Advertised BLE device name.
  static const deviceName = 'Decent Scale';

  /// FFF4 — weight, button, and command acknowledgements (notify).
  static const notifyUuid = '0000fff4-0000-1000-8000-00805f9b34fb';

  /// 36F5 — outbound commands (write).
  static const writeUuid = '000036f5-0000-1000-8000-00805f9b34fb';

  /// Model byte present in every command and notification.
  static const modelByte = 0x03;

  /// Minimum spacing between outbound commands (firmware may drop bursts).
  static const minCommandSpacing = Duration(milliseconds: 200);

  /// Half Decent Scale requires a heartbeat at least every 5 seconds.
  static const heartbeatInterval = Duration(seconds: 5);

  /// FFF4 type bytes for weight notifications.
  static const weightStableType = 0xCE;
  static const weightChangingType = 0xCA;

  /// Expected outbound command length (model + type + 4 data + XOR).
  static const commandLength = 7;
}