import 'dart:io';

import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/sensors/sensor_kind.dart';
import 'package:flowlog/settings/paired_sensors_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensorHub persistence', () {
    late Directory tempDir;
    late PairedSensorsStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('sensor_hub_persist_test');
      store = PairedSensorsStore(
        settingsPath: '${tempDir.path}/paired_sensors.json',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('addDevice writes paired sensors file', () async {
      final hub = SensorHub(pairedSensorsStore: store);
      addTearDown(hub.dispose);

      expect(hub.addDevice(SensorKind.pressensor, name: 'My PRS'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'My PRS');
      expect(loaded.single.kind, SensorKind.pressensor);
    });

    test('assignBleRemoteId updates persisted BLE id', () async {
      final hub = SensorHub(pairedSensorsStore: store);
      addTearDown(hub.dispose);

      hub.addDevice(SensorKind.pressensor, name: 'My PRS');
      hub.assignBleRemoteId(
        SensorKind.pressensor,
        bleRemoteId: 'AA:BB:CC:DD:EE:FF',
        name: 'PRS-1234',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loaded = await store.load();
      expect(loaded.single.bleRemoteId, 'AA:BB:CC:DD:EE:FF');
      expect(loaded.single.name, 'PRS-1234');
    });
  });
}