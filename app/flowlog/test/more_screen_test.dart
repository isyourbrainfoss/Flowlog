import 'package:flowlog/main.dart';
import 'package:flowlog/screens/more/sensors_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('More tab shows Sensors section', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Sensors'), findsOneWidget);
    expect(find.text('Paired pressure & scale devices'), findsOneWidget);
  });

  testWidgets('Sensors section navigates to sensors screen', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sensors'));
    await tester.pumpAndSettle();

    expect(find.text('Paired devices'), findsOneWidget);
    expect(find.text('Pressensor PRS'), findsOneWidget);
    expect(find.text('Decent Scale'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.byType(SensorsScreen), findsOneWidget);
  });
}