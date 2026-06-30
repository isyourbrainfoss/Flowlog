import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSensorsScreen(
    WidgetTester tester, {
    SensorHub? hub,
    ThemeData? theme,
  }) async {
    final sensorHub = hub ?? SensorHub();
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
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Pressensor PRS'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_scale_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Decent Scale'), findsOneWidget);
      expect(find.text('Disconnected'), findsNWidgets(2));
    });

    testWidgets('offers scan flow after add', (tester) async {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      await pumpSensorsScreen(tester, hub: hub);

      await tester.tap(find.byKey(const Key('add_pressensor_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Scan for Pressensor PRS?'), findsOneWidget);
      expect(find.byKey(const Key('scan_after_add_button')), findsOneWidget);

      await tester.tap(find.text('Skip'));
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
  });
}

