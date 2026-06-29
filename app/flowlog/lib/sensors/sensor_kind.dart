import 'package:flutter/material.dart';

/// Known sensor types Flowlog supports pairing with.
enum SensorKind {
  pressensor,
  scale,
}

extension SensorKindLabels on SensorKind {
  String get defaultName => switch (this) {
        SensorKind.pressensor => 'Pressensor PRS',
        SensorKind.scale => 'Decent Scale',
      };

  String get subtitle => switch (this) {
        SensorKind.pressensor => 'Pressure sensor (BLE)',
        SensorKind.scale => 'BLE scale',
      };

  IconData get icon => switch (this) {
        SensorKind.pressensor => Icons.speed,
        SensorKind.scale => Icons.scale,
      };
}