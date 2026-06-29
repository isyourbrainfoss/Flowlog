import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flowlog_sensors/flowlog_sensors.dart' show ConnectionState;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpSensorsScreen(
    WidgetTester tester, {
    List<PairedSensorDevice> devices = kMockPairedDevices,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? FlowlogTheme.coffeeDark,
        home: Scaffold(
          body: SensorsScreen(devices: devices),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SensorsScreen', () {
    testWidgets('shows placeholder paired device list', (tester) async {
      await pumpSensorsScreen(tester);

      expect(find.text('Paired devices'), findsOneWidget);
      expect(find.text('Pressensor PRS'), findsOneWidget);
      expect(find.text('Decent Scale'), findsOneWidget);
      expect(find.text('Pressure sensor'), findsOneWidget);
      expect(find.text('BLE scale'), findsOneWidget);
    });

    testWidgets('shows connection state chips for mock states', (tester) async {
      await pumpSensorsScreen(tester);

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.byType(ConnectionStateChip), findsNWidgets(2));
    });

    testWidgets('uses Flowlog card styling', (tester) async {
      await pumpSensorsScreen(tester);

      final cards = tester.widgetList<Card>(find.byType(Card));
      expect(cards.length, 2);

      for (final card in cards) {
        expect(card.elevation, FlowlogColors.cardElevation);
        final shape = card.shape as RoundedRectangleBorder;
        expect(
          shape.borderRadius,
          BorderRadius.circular(FlowlogColors.cardRadius),
        );
      }
    });

    testWidgets('chip labels cover all connection states', (tester) async {
      const devices = [
        PairedSensorDevice(
          name: 'A',
          kind: 'Test',
          connectionState: ConnectionState.connected,
        ),
        PairedSensorDevice(
          name: 'B',
          kind: 'Test',
          connectionState: ConnectionState.disconnected,
        ),
        PairedSensorDevice(
          name: 'C',
          kind: 'Test',
          connectionState: ConnectionState.connecting,
        ),
        PairedSensorDevice(
          name: 'D',
          kind: 'Test',
          connectionState: ConnectionState.error,
        ),
      ];

      await pumpSensorsScreen(tester, devices: devices);

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Connecting'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });
  });
}