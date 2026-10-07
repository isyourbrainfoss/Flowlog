import 'dart:async';
import 'dart:io';

import 'package:flowlog/sensors/sensor_kind.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// A BLE device discovered during a sensor scan.
class BleDiscoveredDevice {
  const BleDiscoveredDevice({
    required this.remoteId,
    required this.name,
    required this.kind,
    required this.rssi,
  });

  final String remoteId;
  final String name;
  final SensorKind kind;
  final int rssi;
}
