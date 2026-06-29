/// BLE sensor device category.
enum DeviceType {
  pressensor,
  scale;

  static DeviceType fromJson(String value) {
    return switch (value) {
      'pressensor' => DeviceType.pressensor,
      'scale' => DeviceType.scale,
      _ => throw ArgumentError.value(value, 'value', 'Unknown device type'),
    };
  }

  String toJson() => name;
}