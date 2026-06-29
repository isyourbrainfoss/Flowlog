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
      MaterialApp(
        theme: theme ?? FlowlogTheme.coffeeDark,
        home: SensorHubScope(
          hub: sensorHub,
          child: const Scaffold(
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

      expect(find.text('Pressensor PRS'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add_scale_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Decent Scale'), findsOneWidget);
      expect(find.text('Disconnected'), findsNWidgets(2));
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

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Connecting'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });
  });
}