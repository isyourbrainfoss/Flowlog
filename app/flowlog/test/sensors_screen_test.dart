import 'dart:async';

import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/sensors/ble_transport.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart'
    show ConnectionState, SensorAdapter, SensorSample;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

class _ReadyBleBackend extends BleConnectionBackend {
  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
  }) async =>
      const [];

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  Future<void> pumpSensorsScreen(
    WidgetTester tester, {
    SensorHub? hub,
    ThemeData? theme,
  }) async {
    final sensorHub = hub ?? SensorHub(bleBackend: _ReadyBleBackend());
    if (hub == null) {
      addTearDown(sensorHub.dispose);
    }

    await tester.pumpWidget(
      SensorHubScope(
        hub: sensorHub,
        child: MaterialApp(
          theme: theme ?? FlowlogTheme.coffeeDark,
          home: const Scaffold(
            body: SensorsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addSensorAndDismissScanNotFound(WidgetTester tester) async {
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pumpAndSettle();

    if (find.byKey(const Key('scan_not_found_dialog')).evaluate().isEmpty) {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('scan_not_found_dialog')), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('SensorsScreen', () {
    testWidgets('starts empty with add buttons', (tester) async {
      await pumpSensorsScreen(tester);

      expect(find.text('No sensors paired'), findsOneWidget);
      expect(find.byKey(const Key('add_pressensor_button')), findsOneWidget);
      expect(find.byKey(const Key('add_scale_button')), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('can add pressensor and scale', (tester) async {
      await pumpSensorsScreen(tester);

      await tester.tap(find.byKey(const Key('add_pressensor_button')));
      await tester.pumpAndSettle();
      await addSensorAndDismissScanNotFound(tester);

      expect(find.text('Pressensor PRS'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_scale_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pumpAndSettle();
      if (find.text('OK').evaluate().isNotEmpty) {
        await tester.tap(find.text('OK'));
      }
      await tester.pumpAndSettle();

      expect(find.text('Decent Scale'), findsOneWidget);
      expect(find.text('Disconnected'), findsNWidgets(2));
    });

    testWidgets('starts scan automatically after add', (tester) async {
      final hub = SensorHub(bleBackend: _ReadyBleBackend());
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      await tester.tap(find.byKey(const Key('add_pressensor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(hub.devices.first.bleRemoteId, isNull);
      expect(find.text('Pressensor PRS'), findsOneWidget);
    });

    testWidgets('uses Flowlog card styling', (tester) async {
      final hub = SensorHub()..addDevice(SensorKind.pressensor);
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      final cards = tester.widgetList<Card>(find.byType(Card));
      expect(cards.length, 1);

      final card = cards.first;
      expect(card.elevation, FlowlogColors.cardElevation);
      final shape = card.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(FlowlogColors.cardRadius),
      );
    });

    testWidgets('chip labels cover all connection states', (tester) async {
      await tester.binding.setSurfaceSize(const Size(480, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final hub = SensorHub(initialDevices: [
        PairedSensorEntry(
          id: 'a',
          name: 'Connected device',
          kind: SensorKind.pressensor,
          state: ConnectionState.connected,
        ),
        PairedSensorEntry(
          id: 'b',
          name: 'Disconnected device',
          kind: SensorKind.scale,
          state: ConnectionState.disconnected,
        ),
        PairedSensorEntry(
          id: 'c',
          name: 'Connecting device',
          kind: SensorKind.pressensor,
          state: ConnectionState.connecting,
        ),
        PairedSensorEntry(
          id: 'd',
          name: 'Error device',
          kind: SensorKind.scale,
          state: ConnectionState.error,
        ),
      ]);
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      final chips = tester
          .widgetList<ConnectionStateChip>(find.byType(ConnectionStateChip))
          .map((chip) => chip.state)
          .toList();

      expect(chips, contains(ConnectionState.connected));
      expect(chips, contains(ConnectionState.disconnected));
      expect(chips, contains(ConnectionState.connecting));
      expect(chips, contains(ConnectionState.error));
    });

    testWidgets('shows disconnect for connected device', (tester) async {
      final hub = SensorHub(initialDevices: [
        PairedSensorEntry(
          id: 'prs-connected',
          name: 'PRS39739',
          kind: SensorKind.pressensor,
          state: ConnectionState.connected,
          bleRemoteId: 'E5:98:75:7D:9B:3B',
        ),
      ]);
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      expect(find.byKey(const Key('disconnect_prs-connected')), findsOneWidget);
      expect(find.text('Connect'), findsNothing);
    });

    testWidgets('opens diagnostics screen from link', (tester) async {
      await pumpSensorsScreen(tester);

      await tester.tap(find.byKey(const Key('open_diagnostics_button')));
      await tester.pumpAndSettle();

      expect(find.byType(SensorDiagnosticsScreen), findsOneWidget);
      expect(find.text('No errors recorded'), findsOneWidget);
    });

    testWidgets('cancel scan stops without assigning', (tester) async {
      final hub = SensorHub(bleBackend: _HangingScanBackend());
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      await tester.tap(find.byKey(const Key('add_pressensor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('scan_progress_pressensor')), findsOneWidget);
      expect(find.byKey(const Key('scan_cancel_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('scan_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scan_progress_pressensor')), findsNothing);
      expect(hub.devices, isNotEmpty);
      expect(hub.devices.first.bleRemoteId, isNull);
      expect(find.textContaining('Connecting to'), findsNothing);
      expect(find.byKey(const Key('scan_not_found_dialog')), findsNothing);
    });

    testWidgets('connects after assigning a scanned device', (tester) async {
      final backend = _AssignAndConnectBackend(
        discovered: const [
          BleDiscoveredDevice(
            remoteId: 'AA:BB:CC:DD:EE:FF',
            name: 'PRS-CJ2',
            kind: SensorKind.pressensor,
            rssi: -50,
          ),
        ],
      );
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      await tester.tap(find.byKey(const Key('add_pressensor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(hub.devices.first.bleRemoteId, 'AA:BB:CC:DD:EE:FF');
      expect(backend.connectCalls, 1);
      expect(hub.devices.first.state, ConnectionState.connected);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.textContaining('Connecting to PRS-CJ2'), findsOneWidget);
    });

    testWidgets('connects the device chosen from multiple scan matches', (tester) async {
      final backend = _AssignAndConnectBackend(
        discovered: const [
          BleDiscoveredDevice(
            remoteId: 'AA:BB:CC:DD:EE:01',
            name: 'PRS-one',
            kind: SensorKind.pressensor,
            rssi: -40,
          ),
          BleDiscoveredDevice(
            remoteId: 'AA:BB:CC:DD:EE:02',
            name: 'PRS-two',
            kind: SensorKind.pressensor,
            rssi: -60,
          ),
        ],
      );
      final hub = SensorHub(bleBackend: backend);
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      await tester.tap(find.byKey(const Key('add_pressensor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Choose sensor'), findsOneWidget);
      await tester.tap(find.text('PRS-two'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(hub.devices.first.bleRemoteId, 'AA:BB:CC:DD:EE:02');
      expect(backend.connectCalls, 1);
      expect(hub.devices.first.state, ConnectionState.connected);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.textContaining('Connecting to PRS-two'), findsOneWidget);
    });
  });
}

class _HangingScanBackend implements BleConnectionBackend {
  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
  }) async {
    if (abort != null) {
      await abort;
    } else {
      await Completer<void>().future;
    }
    return const [];
  }

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) {
    throw UnimplementedError();
  }
}

class _AssignAndConnectBackend implements BleConnectionBackend {
  _AssignAndConnectBackend({required this.discovered});

  final List<BleDiscoveredDevice> discovered;
  int connectCalls = 0;

  @override
  Future<String?> ensureReady() async => null;

  @override
  Future<List<BleDiscoveredDevice>> scan(
    SensorKind kind, {
    Duration timeout = const Duration(seconds: 8),
    Future<void>? abort,
  }) async =>
      discovered;

  @override
  Future<SensorAdapter> createAdapter({
    required SensorKind kind,
    required String bleRemoteId,
  }) async {
    connectCalls += 1;
    return _AlwaysConnectAdapter();
  }
}

class _AlwaysConnectAdapter implements SensorAdapter {
  final _state = StreamController<ConnectionState>.broadcast();
  final _samples = StreamController<SensorSample>.broadcast();

  @override
  Stream<ConnectionState> get state => _state.stream;

  @override
  Stream<SensorSample> get samples => _samples.stream;

  @override
  Future<void> connect() async {
    _state.add(ConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    if (!_state.isClosed) {
      _state.add(ConnectionState.disconnected);
    }
  }
}