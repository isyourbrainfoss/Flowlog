import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/sensors/sensor_hub.dart';
import 'package:flowlog/theme/flowlog_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDiagnosticsScreen(
    WidgetTester tester, {
    required SensorHub hub,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowlogTheme.coffeeDark,
        home: SensorHubScope(
          hub: hub,
          child: const Scaffold(
            body: SensorDiagnosticsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SensorDiagnosticsScreen', () {
    testWidgets('shows empty states when no sensors or events', (tester) async {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      await pumpDiagnosticsScreen(tester, hub: hub);

      expect(find.byKey(const Key('last_error_message')), findsOneWidget);
      expect(find.text('No errors recorded'), findsOneWidget);
      expect(
        find.text('Pair a sensor to see its signal strength.'),
        findsOneWidget,
      );
      expect(
        find.text('No reconnect attempts recorded yet.'),
        findsOneWidget,
      );
    });

    testWidgets('shows pressensor battery and low warning', (tester) async {
      final hub = SensorHub()..addDevice(SensorKind.pressensor, name: 'PRS');
      addTearDown(hub.dispose);

      hub.updateBatteryPercent(hub.devices.first.id, 15);

      await pumpDiagnosticsScreen(tester, hub: hub);

      expect(find.textContaining('15% · Low battery'), findsOneWidget);
    });

    testWidgets('shows RSSI value and not-connected fallback', (tester) async {
      final hub = SensorHub()..addDevice(SensorKind.pressensor, name: 'PRS');
      addTearDown(hub.dispose);

      final deviceId = hub.devices.first.id;
      hub.updateRssi(deviceId, -58);

      await pumpDiagnosticsScreen(tester, hub: hub);

      expect(find.text('RSSI: -58 dBm · Strong'), findsOneWidget);

      hub.updateRssi(deviceId, null);
      await tester.pump();

      expect(find.text('RSSI: — dBm (not connected)'), findsOneWidget);
    });

    test('rssiDisplayText buckets quality and connection state', () {
      expect(rssiDisplayText(rssi: -55, isConnected: true), '-55 dBm · Strong');
      expect(rssiDisplayText(rssi: -66, isConnected: true), '-66 dBm · Good');
      expect(rssiDisplayText(rssi: -77, isConnected: true), '-77 dBm · Fair');
      expect(rssiDisplayText(rssi: -90, isConnected: false), '-90 dBm · Weak');
      expect(rssiDisplayText(rssi: null, isConnected: true), '— dBm (reading…)');
      expect(
        rssiDisplayText(rssi: null, isConnected: false),
        '— dBm (not connected)',
      );
    });

    testWidgets('shows last error and reconnect log entries', (tester) async {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      hub.setLastError('Device not found');
      hub.recordReconnect(
        deviceId: 'sensor-1',
        deviceName: 'Pressensor PRS',
        outcome: ReconnectOutcome.attempted,
        timestamp: DateTime(2026, 6, 29, 14, 30, 5),
      );
      hub.recordReconnect(
        deviceId: 'sensor-1',
        deviceName: 'Pressensor PRS',
        outcome: ReconnectOutcome.failed,
        message: 'Timeout',
        timestamp: DateTime(2026, 6, 29, 14, 30, 6),
      );

      await pumpDiagnosticsScreen(tester, hub: hub);

      expect(find.text('Device not found'), findsOneWidget);
      expect(find.byKey(const Key('reconnect_log_card')), findsOneWidget);
      expect(find.text('Attempted · 14:30:05'), findsOneWidget);
      expect(find.text('Failed · 14:30:06'), findsOneWidget);
      expect(find.text('Timeout'), findsOneWidget);
    });

    testWidgets('clear button empties reconnect log', (tester) async {
      final hub = SensorHub();
      addTearDown(hub.dispose);

      hub.recordReconnect(
        deviceId: 'sensor-1',
        deviceName: 'Scale',
        outcome: ReconnectOutcome.attempted,
      );

      await pumpDiagnosticsScreen(tester, hub: hub);

      expect(find.byKey(const Key('clear_reconnect_log_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('clear_reconnect_log_button')));
      await tester.pump();

      expect(
        find.text('No reconnect attempts recorded yet.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('clear_reconnect_log_button')), findsNothing);
    });
  });
}