@Tags(['ble'])
library;

import 'package:test/test.dart';

/// Optional hardware integration tests for a physical Decent Scale.
///
/// Run locally with hardware present:
/// `dart test --tags=ble test/decent_scale_ble_test.dart`
void main() {
  test(
    'connects to Decent Scale over BLE',
    () {
      // Requires flutter_blue_plus wiring and paired hardware.
    },
    skip: 'Requires Decent Scale hardware and flutter_blue_plus',
  );
}