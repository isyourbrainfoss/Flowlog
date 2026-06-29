@Tags(['ble'])
library;

import 'package:flutter_test/flutter_test.dart';

/// Optional hardware integration tests for physical BLE sensors.
///
/// Run locally with hardware present:
/// `flutter test --tags=ble test/ble_hardware_test.dart`
void main() {
  test(
    'scans for nearby Pressensor hardware',
    () {},
    skip: 'Requires PRS hardware and flutter_blue_plus runtime',
  );

  test(
    'connects to Decent Scale over BLE',
    () {},
    skip: 'Requires Decent Scale hardware and flutter_blue_plus runtime',
  );
}