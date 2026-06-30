import 'dart:async';
import 'dart:io';

import 'package:flowlog/screens/live/controls.dart';
import 'package:flowlog/screens/live_screen.dart';
import 'package:flowlog_charts/flowlog_charts.dart';
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
  group('LiveSensorSource', () {
    late SensorHub hub;
    late _MockPressensorBleTransport pressureTransport;
    late MockDecentScaleTransport scaleTransport;
    late LiveSensorSource source;

    setUp(() {
      hub = SensorHub();
      pressureTransport = _MockPressensorBleTransport();
      scaleTransport = MockDecentScaleTransport();
      source = LiveSensorSource(
        hub: hub,
        demoFixturePath: _fixturePath('sensor_streams/demo_shot.jsonl'),
        pressureAdapterFactory: (device) => PressensorBleAdapter(
          transport: pressureTransport,
          deviceId: device.id,
        ),
        weightAdapterFactory: (device) => DecentScaleBleAdapter(
          transport: scaleTransport,
          heartbeatInterval: const Duration(days: 1),
          minCommandSpacing: Duration.zero,
        ),
      );
    });

    tearDown(() {
      hub.dispose();
      unawaited(pressureTransport.close());
    });

    test('uses idle adapter when no sensors are connected', () {
      hub.addDevice(SensorKind.pressensor);
      hub.addDevice(SensorKind.scale);

      final adapter = source.resolveSampleAdapter();

      expect(adapter, isA<IdleSensorAdapter>());
      expect(source.hasConnectedSensors, isFalse);
    });

    test('uses merged stream when pressensor is connected', () {
      hub.addDevice(SensorKind.pressensor);
      final device = hub.devices.single;
      hub.disconnect(device.id);
      hub.devices.first.state = ConnectionState.connected;

      final adapter = source.resolveSampleAdapter();

      expect(adapter, isA<MergedSampleStreamAdapter>());
      expect(source.hasConnectedSensors, isTrue);
    });

    test('uses merged stream when only scale is connected', () {
      hub.addDevice(SensorKind.scale);
      hub.devices.single.state = ConnectionState.connected;

      final adapter = source.resolveSampleAdapter();

      expect(adapter, isA<MergedSampleStreamAdapter>());
    });

    test('demo mode uses real-time mock replay adapter', () {
      source.enterDemoMode();

      final adapter = source.resolveSampleAdapter();

      expect(adapter, isA<MockReplayAdapter>());
      expect((adapter as MockReplayAdapter).speed, 1.0);
      expect(source.isDemoMode, isTrue);
    });

    test('start without sensors does not inject demo samples', () async {
      final controller = LiveShotController(
        sampleAdapter: SessionSensorAdapter(
          resolve: source.resolveSampleAdapter,
        ),
        onTare: source.onTare,
      );
      addTearDown(controller.dispose);

      await controller.start();
      await Future<void>.delayed(Duration.zero);
      await controller.stop();

      expect(controller.sampleCount, 0);
      expect(controller.sessionState, ShotSessionState.stopped);
    });

    test('start with connected pressensor collects merged samples', () async {
      hub.addDevice(SensorKind.pressensor);
      hub.devices.single.state = ConnectionState.connected;

      final controller = LiveShotController(
        sampleAdapter: SessionSensorAdapter(
          resolve: source.resolveSampleAdapter,
        ),
        onTare: source.onTare,
      );
      addTearDown(controller.dispose);

      await controller.start();
      pressureTransport.emitPressure([0x23, 0x28]);
      await Future<void>.delayed(Duration.zero);
      await controller.stop();

      expect(controller.sampleCount, greaterThan(0));
      expect(controller.samples.first.pressureBar, isNotNull);
    });

    test('onTare writes to scale transport when scale is connected', () async {
      hub.addDevice(SensorKind.scale);
      hub.devices.single.state = ConnectionState.connected;

      await source.onTare();

      expect(scaleTransport.writtenCommands, isNotEmpty);
      expect(
        scaleTransport.writtenCommands.first,
        DecentScaleCommands.tare(),
      );
    });
  });

  group('LiveScreen sensor wiring', () {
    late SensorHub hub;

    setUp(() {
      hub = SensorHub();
    });

    tearDown(() {
      hub.dispose();
    });

    Future<void> pumpLiveScreen(
      WidgetTester tester, {
      LiveSensorSource? sensorSource,
      PressureAdapterFactory? pressureAdapterFactory,
      WeightAdapterFactory? weightAdapterFactory,
    }) async {
      await tester.pumpWidget(
        SensorHubScope(
          hub: hub,
          child: MaterialApp(
            home: LiveScreen(
              sensorSource: sensorSource,
              pressureAdapterFactory: pressureAdapterFactory,
              weightAdapterFactory: weightAdapterFactory,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows empty chart when no sensors are connected', (
      tester,
    ) async {
      await pumpLiveScreen(tester);

      expect(find.text('0 samples'), findsOneWidget);
      expect(find.byType(DualCurveChart), findsOneWidget);

      final chart = tester.widget<DualCurveChart>(find.byType(DualCurveChart));
      expect(chart.samplesNotifier?.value, isEmpty);
    });

    testWidgets('start without sensors keeps chart empty', (tester) async {
      await pumpLiveScreen(tester);

      final startButton = find.byKey(const Key('live_brew'));
      await tester.ensureVisible(startButton);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        await tester.tap(startButton);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();

      expect(find.text('0 samples'), findsOneWidget);
      expect(find.text('Session: recording'), findsOneWidget);
    });

    testWidgets('shows try demo button only while idle', (tester) async {
      await pumpLiveScreen(tester);

      expect(find.byKey(const Key('live_try_demo')), findsOneWidget);
      expect(find.text('Try demo shot'), findsOneWidget);
    });

    testWidgets('try demo shot enables demo banner and recording', (
      tester,
    ) async {
      await pumpLiveScreen(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_try_demo')));
        await tester.pump();
      });

      expect(find.text('Demo shot — replayed sample data'), findsOneWidget);
      expect(find.byKey(const Key('live_try_demo')), findsNothing);
      expect(find.text('Session: recording'), findsOneWidget);
    });

    testWidgets('dismissing demo banner exits demo mode', (tester) async {
      await pumpLiveScreen(tester);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('live_try_demo')));
        await tester.pump();
      });

      expect(find.text('Demo shot — replayed sample data'), findsOneWidget);

      await tester.tap(find.byKey(const Key('demo_mode_dismiss')));
      await tester.pumpAndSettle();

      expect(find.text('Demo shot — replayed sample data'), findsNothing);
    });
  });
}

String _fixturePath(String relativePath) {
  final candidates = [
    '../../fixtures/$relativePath',
    '../../../fixtures/$relativePath',
    '../../../../fixtures/$relativePath',
  ];

  for (final candidate in candidates) {
    if (File(candidate).existsSync()) {
      return candidate;
    }
  }

  throw StateError('Fixture not found: $relativePath');
}