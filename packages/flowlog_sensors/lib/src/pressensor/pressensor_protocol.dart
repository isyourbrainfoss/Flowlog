/// BLE protocol constants for Pressensor PRS devices.
///
/// See `docs/protocols/pressensor-prs.md`.
library;

/// Advertising / GAP name prefix for Pressensor PRS devices.
const String pressensorNamePrefix = 'PRS';

/// Pressure service UUID.
const String pressensorPressureServiceUuid =
    '873ae82a-4c5a-4342-b539-9d900bf7ebd0';

/// Live pressure characteristic (notify).
const String pressensorPressureCharacteristicUuid =
    '873ae82b-4c5a-4342-b539-9d900bf7ebd0';

/// Zero pressure / tare characteristic (write).
const String pressensorZeroPressureCharacteristicUuid =
    '873ae82c-4c5a-4342-b539-9d900bf7ebd0';

/// Battery service UUID (standard BLE).
const String pressensorBatteryServiceUuid =
    '0000180f-0000-1000-8000-00805f9b34fb';

/// Battery level characteristic (read).
const String pressensorBatteryLevelCharacteristicUuid =
    '00002a19-0000-1000-8000-00805f9b34fb';

/// Log service UUID.
const String pressensorLogServiceUuid =
    '873ae828-4c5a-4342-b539-9d900bf7ebd0';

/// Log characteristic (notify, null-terminated string).
const String pressensorLogCharacteristicUuid =
    '873ae829-4c5a-4342-b539-9d900bf7ebd0';

/// Payload written to [pressensorZeroPressureCharacteristicUuid] to tare.
///
/// The PRS protocol accepts any value; current pressure is treated as zero.
const List<int> pressensorZeroPressureCommand = [0x00];

/// Battery percent at or below which Flowlog shows a low-battery warning.
const int kPressensorLowBatteryPercent = 20;

/// Returns true when [percent] should trigger a low-battery warning.
bool isPressensorLowBattery(int? percent) {
  return percent != null && percent <= kPressensorLowBatteryPercent;
}

/// User-facing low-battery warning, or null when [percent] is acceptable.
String? pressensorLowBatteryWarning(int? percent) {
  if (!isPressensorLowBattery(percent)) {
    return null;
  }
  return 'Pressensor battery low ($percent%). Charge before your next session.';
}

/// Returns true when [deviceName] matches a Pressensor PRS advertisement.
bool isPressensorDeviceName(String deviceName) {
  return deviceName.startsWith(pressensorNamePrefix);
}