import 'pressensor_protocol.dart';

/// Abstract BLE transport for Pressensor PRS devices.
///
/// Platform-specific implementations (e.g. flutter_blue_plus) plug in here;
/// unit tests use in-memory mocks.
abstract class PressensorBleTransport {
  /// Scans for BLE devices and returns IDs whose names start with [pressensorNamePrefix].
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  });

  /// Connects to [deviceId], or the sole discovered device when omitted.
  Future<void> connect({String? deviceId});

  /// Closes the BLE connection.
  Future<void> disconnect();

  /// Subscribes to the pressure notify characteristic.
  Stream<List<int>> subscribePressure();

  /// Writes a zero-pressure (tare) command.
  Future<void> writeZeroPressure([
    List<int> payload = pressensorZeroPressureCommand,
  ]);
}