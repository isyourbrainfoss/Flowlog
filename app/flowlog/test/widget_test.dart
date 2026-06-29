import 'package:flowlog/main.dart';
import 'package:flowlog/shell/flowlog_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flowlog shell shows Live tab by default', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsWidgets);
    expect(find.text('Live shot'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('Shell navigates to all four tabs', (tester) async {
    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    final destinations = [
      (Icons.history, 'Shot history'),
      (Icons.local_cafe_outlined, 'Beans & profiles'),
      (Icons.tune, 'Settings & sensors'),
      (Icons.play_circle_outline, 'Live shot'),
    ];

    for (final (icon, body) in destinations) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(find.text(body), findsOneWidget);
    }
  });

  testWidgets('NavigationRail is not extended below 600dp', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FlowlogShell()),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.minWidth, 72);
  });

  testWidgets('NavigationRail is extended at 600dp and above', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FlowlogShell()),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('Collapsed rail uses narrower width below 360dp', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: FlowlogShell()),
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(rail.minWidth, 56);
  });

  testWidgets('Named routes resolve to placeholder screens', (tester) async {
    const routeBodies = {
      '/live': 'Live shot',
      '/history': 'Shot history',
      '/library': 'Beans & profiles',
      '/more': 'Settings & sensors',
    };

    await tester.pumpWidget(const FlowlogApp());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final entry in routeBodies.entries) {
      navigator.pushNamed(entry.key);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
    }
  });
}