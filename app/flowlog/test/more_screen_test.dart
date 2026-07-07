import 'package:flowlog/main.dart';
import 'package:flowlog/screens/more/diagnostics.dart';
import 'package:flowlog/screens/more/export.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_helpers.dart';

Future<void> _openMoreTab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

Future<void> _scrollToMoreTile(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('More tab shows Sensors section', (tester) async {
    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    await _openMoreTab(tester);
    await _scrollToMoreTile(tester, find.byKey(const Key('more_sensors_tile')));

    expect(find.text('Sensors'), findsOneWidget);
    expect(find.text('Pair Pressensor and scale'), findsOneWidget);
  });

  testWidgets('Export section navigates to export screen', (tester) async {
    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export shots (CSV)'));
    await pumpForAsync(tester, frames: 5);

    expect(find.widgetWithText(AppBar, 'Export shots'), findsOneWidget);
    expect(find.byType(ExportScreen), findsOneWidget);
  });

  testWidgets('Sensors section navigates to sensors screen', (tester) async {
    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    await _openMoreTab(tester);
    await _scrollToMoreTile(tester, find.byKey(const Key('more_sensors_tile')));

    await tester.tap(find.byKey(const Key('more_sensors_tile')));
    await tester.pumpAndSettle();

    expect(find.text('No sensors paired'), findsOneWidget);
    expect(find.byKey(const Key('add_pressensor_button')), findsOneWidget);
    expect(find.byKey(const Key('add_scale_button')), findsOneWidget);
    expect(find.byType(SensorsScreen), findsOneWidget);
  });

  testWidgets('Diagnostics section navigates to diagnostics screen', (tester) async {
    await tester.pumpWidget(const FlowlogApp(autoReconnectSensors: false));
    await tester.pumpAndSettle();

    await _openMoreTab(tester);
    await _scrollToMoreTile(
      tester,
      find.byKey(const Key('more_diagnostics_tile')),
    );

    await tester.tap(find.byKey(const Key('more_diagnostics_tile')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Sensor diagnostics'), findsOneWidget);
    expect(find.byType(SensorDiagnosticsScreen), findsOneWidget);
    expect(find.text('Reconnect log'), findsOneWidget);
  });
}