import 'dart:async';

import 'package:flowlog/screens/live/auto_start.dart';
import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog/sensors/live_sensor_source.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog_core/flowlog_core.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart';
import 'package:flowlog_sensors/src/decent_scale/decent_scale.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

class _MockPressensorBleTransport implements PressensorBleTransport {
  _MockPressensorBleTransport();

  final _pressureController = StreamController<List<int>>.broadcast();

  void emitPressure(List<int> data) {
    _pressureController.add(data);
  }

  @override
  Future<List<String>> scanForDevices({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return const ['prs-1'];
  }

  @override
  Future<void> connect({String? deviceId}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Stream<List<int>> subscribePressure() => _pressureController.stream;

  @override
  Future<void> writeZeroPressure([
    List<int> payload = pressensorZeroPressureCommand,
  ]) async {}

  Future<void> close() => _pressureController.close();
}

void main() {
  group('AutoStartArming', () {
    const settings = AutoStartSettings(startThresholdBar: 1.0);

    test('triggers when armed and pressure crosses threshold', () {
      const arming = AutoStartArming();

      expect(
        arming.shouldTriggerStart(pressureBar: 1.2, settings: settings),
        isTrue,
      );
    });

    test('re-arms after pressure falls below release threshold', () {
      var arming = const AutoStartArming(armed: false);
      arming = arming.update(pressureBar: 0.4, settings: settings);

      expect(arming.armed, isTrue);
      expect(
        arming.shouldTriggerStart(pressureBar: 1.1, settings: settings),
        isTrue,
      );
    });

    test('does not retrigger until re-armed', () {
      const arming = AutoStartArming(armed: false);

      expect(
        arming.shouldTriggerStart(pressureBar: 2.0, settings: settings),
        isFalse,
      );
    });
  });

  group('LiveAutoStartListener', () {
    late SensorHub hub;
    late _MockPressensorBleTransport pressureTransport;
    late LiveSensorSource source;
    late LiveShotController controller;

    setUp(() {
      hub = SensorHub();
      pressureTransport = _MockPressensorBleTransport();
      source = LiveSensorSource(
        hub: hub,
        pressureAdapterFactory: (device) => PressensorBleAdapter(
          transport: pressureTransport,
          deviceId: device.id,
        ),
        weightAdapterFactory: (device) => DecentScaleBleAdapter(
          transport: MockDecentScaleTransport(),
          heartbeatInterval: const Duration(days: 1),
          minCommandSpacing: Duration.zero,
        ),
      );
      controller = LiveShotController(
        sampleAdapter: IdleSensorAdapter(),
        onTare: () async {},
      );
    });

    tearDown(() {
      hub.dispose();
      controller.dispose();
      unawaited(pressureTransport.close());
    });

    Future<void> pumpHarness(WidgetTester tester) async {
      await tester.pumpWidget(
        SensorHubScope(
          hub: hub,
          child: MaterialApp(
            home: LiveScreen(
              controller: controller,
              sensorSource: source,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows armed banner when pressensor is connected', (
      tester,
    ) async {
      hub.addDevice(SensorKind.pressensor);
      hub.devices.first.state = ConnectionState.connected;

      await pumpHarness(tester);

      expect(find.textContaining('Auto-start armed'), findsOneWidget);
    });

    testWidgets('starts brew when pressure crosses threshold', (
      tester,
    ) async {
      hub.addDevice(SensorKind.pressensor);
      hub.devices.first.state = ConnectionState.connected;

      await pumpHarness(tester);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      pressureTransport.emitPressure(const [0x03, 0xE8]);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(controller.sessionState, ShotSessionState.recording);
    });
  });
}