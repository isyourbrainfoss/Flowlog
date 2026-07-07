import 'dart:io';

import 'package:flowlog/sensors/sensor_kind.dart';
import 'package:flowlog/settings/paired_sensors_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PairedSensorsStore', () {
    late Directory tempDir;
    late PairedSensorsStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('paired_sensors_test');
      store = PairedSensorsStore(
        settingsPath: '${tempDir.path}/paired_sensors.json',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns empty list when file is missing', () async {
      expect(await store.load(), isEmpty);
    });

    test('persists paired pressensor with BLE id', () async {
      const records = [
        PairedSensorRecord(
          id: 'sensor-1',
          name: 'PRS-1234',
          kind: SensorKind.pressensor,
          bleRemoteId: 'AA:BB:CC:DD:EE:FF',
        ),
      ];
      await store.save(records);

      final loaded = await store.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, records.single.id);
      expect(loaded.single.name, records.single.name);
      expect(loaded.single.kind, records.single.kind);
      expect(loaded.single.bleRemoteId, records.single.bleRemoteId);
    });
  });
}